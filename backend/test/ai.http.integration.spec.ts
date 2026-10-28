import { createServer, IncomingMessage, Server, ServerResponse } from 'node:http';
import { AddressInfo } from 'node:net';

import { describe, it, expect, beforeAll, afterAll, beforeEach } from '@jest/globals';
import { Module, ValidationPipe } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { INestApplication } from '@nestjs/common';

import { AiModule } from '../src/modules/ai/ai.module';
import { AiResponseDto } from '../src/common/dto/ai.dto';

/**
 * Phase 10B-A — real HTTP integration for the backend half of the AI path:
 *
 *   HTTP POST /ai/query
 *     -> AiController (real)
 *     -> ValidationPipe (real, same options as src/main.ts)
 *     -> AiService (real)
 *     -> OpenAiAiProvider (real, NOT MockAiProvider)
 *     -> real HTTP fetch
 *     -> local node:http mock speaking the OpenAI chat-completions protocol
 *     -> normalizeAiResponse
 *     -> AiResponseDto
 *
 * Two real TCP servers are involved and both hops cross the network stack.
 * No provider substitution, no DI replacement: the container binds the real
 * `OpenAiAiProvider`, and only `AI_BASE_URL` points at the local mock — exactly
 * the seam the provider already exposes in production.
 *
 * `AppModule` is deliberately not used: it boots `TypeOrmModule` against
 * Postgres, which is not required for the AI path. `AiModule` imports no
 * database module, so it is composed here with `ConfigModule` alone.
 *
 * Runs with no internet, no OpenAI/OpenRouter, and no real credentials:
 * `ignoreEnvFile` + `ignoreEnvVars` keep the real `backend/.env` and the shell
 * environment out of the test entirely.
 */

/** Obvious non-secret used only to assert header propagation. */
const TEST_API_KEY = 'test-key-not-a-secret';
const TEST_MODEL = 'mock-model';

/** One captured inbound request to the OpenAI mock. */
interface CapturedRequest {
  method: string | undefined;
  url: string | undefined;
  authorization: string | undefined;
  contentType: string | undefined;
  body: string;
}

type MockResponder = (req: IncomingMessage, res: ServerResponse) => void;

/** Builds the exact envelope `OpenAiAiProvider` reads: choices[0].message.content. */
function openAiEnvelope(content: string): string {
  return JSON.stringify({
    id: 'chatcmpl-mock',
    object: 'chat.completion',
    model: TEST_MODEL,
    choices: [{ index: 0, message: { role: 'assistant', content }, finish_reason: 'stop' }],
  });
}

function respondJson(res: ServerResponse, status: number, payload: string): void {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(payload);
}

@Module({
  imports: [AiModule],
})
class AiOnlyTestModule {}

describe('Phase 10B-A: POST /ai/query over real HTTP through OpenAiAiProvider', () => {
  let mockServer: Server;
  let mockPort: number;
  let app: INestApplication;
  let appUrl: string;

  let captured: CapturedRequest[] = [];
  let responder: MockResponder;

  beforeAll(async () => {
    // 1. Start the OpenAI-compatible mock first so its port can be injected.
    mockServer = createServer((req, res) => {
      let body = '';
      req.setEncoding('utf8');
      req.on('data', (chunk: string) => {
        body += chunk;
      });
      req.on('end', () => {
        captured.push({
          method: req.method,
          url: req.url,
          authorization: req.headers.authorization,
          contentType: req.headers['content-type'],
          body,
        });
        responder(req, res);
      });
    });
    await new Promise<void>((resolve) => {
      mockServer.listen(0, '127.0.0.1', () => resolve());
    });
    mockPort = (mockServer.address() as AddressInfo).port;

    // 2. Boot the real AI module against the mock, isolated from .env / shell.
    @Module({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          ignoreEnvVars: true,
          load: [
            () => ({
              AI_API_KEY: TEST_API_KEY,
              AI_BASE_URL: `http://127.0.0.1:${mockPort}/v1`,
              AI_MODEL: TEST_MODEL,
            }),
          ],
        }),
        AiOnlyTestModule,
      ],
    })
    class TestRootModule {}

    app = await NestFactory.create(TestRootModule, { logger: false });
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.listen(0, '127.0.0.1');
    appUrl = await app.getUrl();
  });

  afterAll(async () => {
    await app?.close();
    await new Promise<void>((resolve) => {
      mockServer.close(() => resolve());
    });
  });

  beforeEach(() => {
    captured = [];
    responder = (_req, res) => respondJson(res, 200, openAiEnvelope('{"text":"ok","sections":[]}'));
  });

  async function query(
    prompt: unknown,
    context?: Record<string, unknown>,
  ): Promise<{ status: number; raw: string }> {
    const res = await fetch(`${appUrl}/ai/query`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt, ...(context ? { context } : {}) }),
    });
    return { status: res.status, raw: await res.text() };
  }

  describe('the request really crosses OpenAiAiProvider and the network', () => {
    it('reaches the mock with the OpenAI chat-completions contract', async () => {
      const { status } = await query('find hotels in Paris');

      expect(status).toBe(201);
      expect(captured).toHaveLength(1);

      const sent = captured[0];
      expect(sent.method).toBe('POST');
      // Proves AI_BASE_URL was honoured verbatim and the provider appended the
      // chat-completions path itself.
      expect(sent.url).toBe('/v1/chat/completions');
      expect(sent.contentType).toContain('application/json');

      const body = JSON.parse(sent.body) as {
        model?: string;
        max_tokens?: number;
        messages?: Array<{ role?: string; content?: string }>;
      };
      // AI_MODEL is forwarded unchanged — no hardcoded model substitution.
      expect(body.model).toBe(TEST_MODEL);
      expect(body.messages).toHaveLength(2);
      expect(body.messages?.[0]?.role).toBe('system');
      expect(body.messages?.[0]?.content).toContain('"layout":"horizontal"');
      expect(body.messages?.[0]?.content).not.toContain(
        'horizontal | horizontalPeek',
      );
      expect(body.messages?.[1]?.role).toBe('user');
      expect(body.messages?.[1]?.content).toBe('find hotels in Paris');
    });

    it('forwards a bounded per-query output token limit', async () => {
      const { status } = await query('Build Explore sections', {
        route: 'explore',
        metadata: { maxOutputTokens: 350 },
      });

      expect(status).toBe(201);
      expect(JSON.parse(captured[0].body).max_tokens).toBe(350);
    });

    it('ignores an out-of-range output token limit', async () => {
      const { status } = await query('Build Explore sections', {
        route: 'explore',
        metadata: { maxOutputTokens: 100_000 },
      });

      expect(status).toBe(201);
      expect(JSON.parse(captured[0].body).max_tokens).toBeUndefined();
    });

    it('sends the configured key as a Bearer credential', async () => {
      await query('find hotels');

      expect(captured[0].authorization).toBe(`Bearer ${TEST_API_KEY}`);
    });

    it('rejects an invalid payload before the provider is called', async () => {
      const { status } = await query('');

      expect(status).toBe(400);
      // The ValidationPipe short-circuits: no upstream call was made at all.
      expect(captured).toHaveLength(0);
    });
  });

  describe('scenario: 200 with a valid OpenAI-compatible completion', () => {
    it('normalizes the completion into an AiResponseDto', async () => {
      const aiJson = JSON.stringify({
        text: 'Here are two hotels.',
        sections: [
          {
            id: 'hotels',
            title: 'Recommended Hotels',
            subtitle: 'Best match',
            layout: 'horizontalPeek',
            order: 1,
            items: [
              {
                id: 'h1',
                type: 'hotel',
                title: 'Grand Palm',
                price: 320,
                currency: 'USD',
                rating: 4.6,
                reviewCount: 214,
                tags: ['4-star'],
                data: { city: 'Paris' },
                actions: [{ type: 'book', label: 'Book', payload: { offerId: 'h1' } }],
              },
            ],
          },
        ],
      });
      responder = (_req, res) => respondJson(res, 200, openAiEnvelope(aiJson));

      const { status, raw } = await query('find hotels');
      const dto = JSON.parse(raw) as AiResponseDto;

      expect(status).toBe(201);
      expect(dto.text).toBe('Here are two hotels.');
      expect(dto.sections).toHaveLength(1);

      const section = dto.sections[0];
      expect(section.id).toBe('hotels');
      expect(section.title).toBe('Recommended Hotels');
      expect(section.layout).toBe('horizontalPeek');
      expect(section.order).toBe(1);
      expect(section.items).toHaveLength(1);

      const item = section.items[0];
      expect(item.id).toBe('h1');
      expect(item.type).toBe('hotel');
      expect(item.title).toBe('Grand Palm');
      expect(item.price).toBe(320);
      expect(item.rating).toBe(4.6);
      expect(item.tags).toEqual(['4-star']);
      expect(item.data).toEqual({ city: 'Paris' });
      expect(item.actions?.[0]?.type).toBe('book');

      // Normalization stamped its own metadata; provider identity never leaks.
      expect(dto.metadata?.version).toBe(1);
      expect(typeof dto.metadata?.queryId).toBe('string');
      expect(raw).not.toContain('openai');
      expect(raw).not.toContain('OpenAiAiProvider');
    });

    it('accepts a fenced completion and still yields a DTO', async () => {
      responder = (_req, res) =>
        respondJson(
          res,
          200,
          openAiEnvelope('```json\n{"text":"fenced","sections":[]}\n```'),
        );

      const { status, raw } = await query('find hotels');
      const dto = JSON.parse(raw) as AiResponseDto;

      expect(status).toBe(201);
      expect(dto.text).toBe('fenced');
      expect(dto.sections).toEqual([]);
    });
  });

  describe('scenario: upstream HTTP 500', () => {
    it('surfaces a 503 without leaking the key or the upstream body', async () => {
      responder = (_req, res) =>
        respondJson(res, 500, JSON.stringify({ error: 'upstream exploded', trace: 'secret-internal' }));

      const { status, raw } = await query('find hotels');

      expect(captured).toHaveLength(1);
      expect(status).toBe(503);
      expect(raw).not.toContain(TEST_API_KEY);
      expect(raw).not.toContain('Bearer');
      expect(raw).not.toContain('secret-internal');
      expect(raw).not.toContain('upstream exploded');
      // The provider reports the upstream status only, not its payload.
      expect(raw).toContain('500');
    });
  });

  describe('scenario: empty upstream body', () => {
    it('rejects an empty completion as unavailable', async () => {
      responder = (_req, res) => {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(openAiEnvelope(''));
      };

      const { status, raw } = await query('find hotels');

      expect(captured).toHaveLength(1);
      expect(status).toBe(503);
      expect(raw).toContain('empty completion');
      expect(raw).not.toContain(TEST_API_KEY);
    });

    it('rejects a completion whose content is missing entirely', async () => {
      responder = (_req, res) =>
        respondJson(res, 200, JSON.stringify({ choices: [{ message: {} }] }));

      const { status, raw } = await query('find hotels');

      expect(status).toBe(503);
      expect(raw).not.toContain(TEST_API_KEY);
    });

    it('rejects a completion with no choices array', async () => {
      responder = (_req, res) => respondJson(res, 200, JSON.stringify({}));

      const { status } = await query('find hotels');

      expect(status).toBe(503);
    });
  });

  describe('scenario: malformed JSON inside the completion', () => {
    it('falls back to a safe DTO instead of failing the request', async () => {
      responder = (_req, res) =>
        respondJson(res, 200, openAiEnvelope('this is not JSON at all'));

      const { status, raw } = await query('find hotels');
      const dto = JSON.parse(raw) as AiResponseDto;

      expect(captured).toHaveLength(1);
      expect(status).toBe(201);
      expect(dto.sections).toEqual([]);
      expect(dto.metadata?.parseFallback).toBe(true);
      expect(dto.text).toContain("couldn't parse");
      expect(raw).not.toContain(TEST_API_KEY);
      // The unparsable model output is never echoed back verbatim.
      expect(raw).not.toContain('this is not JSON at all');
    });

    it('drops malformed sections and items rather than propagating them', async () => {
      const aiJson = JSON.stringify({
        text: 'partial',
        sections: [
          { layout: 'grid', items: [] }, // no title -> dropped
          {
            title: 'Kept',
            layout: 'not-a-layout', // unknown -> vertical
            items: [
              { id: 'ok', type: 'flight', title: 'QR' },
              { id: 'bad', type: 'submarine', title: 'X' }, // unknown type -> dropped
              { type: 'hotel', title: 'no id' }, // missing id -> dropped
              'garbage',
            ],
          },
        ],
      });
      responder = (_req, res) => respondJson(res, 200, openAiEnvelope(aiJson));

      const { status, raw } = await query('find hotels');
      const dto = JSON.parse(raw) as AiResponseDto;

      expect(status).toBe(201);
      expect(dto.sections).toHaveLength(1);
      expect(dto.sections[0].title).toBe('Kept');
      expect(dto.sections[0].layout).toBe('vertical');
      expect(dto.sections[0].items).toHaveLength(1);
      expect(dto.sections[0].items[0].id).toBe('ok');
    });
  });

  describe('scenario: valid completion missing optional fields', () => {
    it('emits only the fields the model supplied', async () => {
      const aiJson = JSON.stringify({
        text: 'minimal',
        sections: [
          {
            title: 'Bare',
            items: [{ id: 'm1', type: 'deal', title: 'Deal' }],
          },
        ],
      });
      responder = (_req, res) => respondJson(res, 200, openAiEnvelope(aiJson));

      const { status, raw } = await query('find deals');
      const dto = JSON.parse(raw) as AiResponseDto;

      expect(status).toBe(201);
      expect(dto.sections).toHaveLength(1);

      const section = dto.sections[0];
      // Layout defaults; absent optionals stay absent instead of becoming null.
      expect(section.layout).toBe('vertical');
      expect(section.id).toBeUndefined();
      expect(section.subtitle).toBeUndefined();
      expect(section.order).toBeUndefined();

      const item = section.items[0];
      expect(item.id).toBe('m1');
      expect(item.type).toBe('deal');
      expect(item.title).toBe('Deal');
      expect(item.price).toBeUndefined();
      expect(item.currency).toBeUndefined();
      expect(item.rating).toBeUndefined();
      expect(item.actions).toBeUndefined();
      expect(item.tags).toBeUndefined();
    });

    it('supplies fallback text when the model omits it', async () => {
      responder = (_req, res) => respondJson(res, 200, openAiEnvelope('{"sections":[]}'));

      const { status, raw } = await query('find deals');
      const dto = JSON.parse(raw) as AiResponseDto;

      expect(status).toBe(201);
      expect(typeof dto.text).toBe('string');
      expect(dto.text).not.toBe('');
    });
  });

  describe('key confinement', () => {
    it('never echoes the credential on any outcome', async () => {
      const outcomes: MockResponder[] = [
        (_q, res) => respondJson(res, 200, openAiEnvelope('{"text":"a","sections":[]}')),
        (_q, res) => respondJson(res, 500, '{"error":"boom"}'),
        (_q, res) => respondJson(res, 200, openAiEnvelope('not json')),
        (_q, res) => respondJson(res, 200, '{}'),
        (_q, res) => respondJson(res, 401, `{"error":"bad key ${TEST_API_KEY}"}`),
      ];

      for (const outcome of outcomes) {
        responder = outcome;
        const { raw } = await query('find hotels');
        expect(raw).not.toContain(TEST_API_KEY);
        expect(raw).not.toContain('Bearer');
      }
    });
  });
});
