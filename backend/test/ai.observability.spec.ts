import { createServer, IncomingMessage, Server, ServerResponse } from 'node:http';
import { AddressInfo } from 'node:net';

import {
  describe,
  it,
  expect,
  beforeAll,
  afterAll,
  beforeEach,
  afterEach,
  jest,
} from '@jest/globals';
import { INestApplication, Logger, Module, ValidationPipe } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';

import { AiResponseDto } from '../src/common/dto/ai.dto';
import { AiModule } from '../src/modules/ai/ai.module';
import { AiService, formatAiAttempt } from '../src/modules/ai/ai.service';
import { AiProvider, AiProviderFailure } from '../src/modules/ai/ai.provider';

/**
 * AI observability.
 *
 * Every assertion reads the lines actually emitted through the framework
 * `Logger`, captured by spying on its prototype. The point of the suite is as
 * much what is *absent* from those lines as what is present: no prompt, no
 * response body, no header, no credential.
 *
 * The service binds a SINGLE provider (the mock/fallback layer was removed
 * with the R-4 workstream); each query therefore records exactly one attempt
 * line with no fallback vocabulary.
 */

/** A prompt and a payload seeded with material that must never be logged. */
const SECRET_PROMPT =
  'Find hotels. My card is 4111111111111111 and my key is sk-or-v1-super-secret';
const SECRET_BEARER = 'Bearer sk-or-v1-super-secret';

const OK_DTO: AiResponseDto = {
  text: 'a confidential itinerary the user should not see in logs',
  sections: [],
  metadata: { queryId: 'q-1', version: 1 },
};

class StubProvider implements AiProvider {
  constructor(
    readonly providerId: string,
    private readonly behaviour: () => Promise<AiResponseDto>,
    private readonly delayMs = 0,
  ) {}

  readonly providerName = 'Stub';

  async generate(): Promise<AiResponseDto> {
    if (this.delayMs > 0) {
      await new Promise((resolve) => setTimeout(resolve, this.delayMs));
    }
    return this.behaviour();
  }
}

const succeeds = (dto: AiResponseDto) => () => Promise.resolve(dto);
const failsWith = (error: unknown) => () => Promise.reject(error);

const serverFailure = () =>
  new AiProviderFailure('AI provider request failed (HTTP 503).', {
    category: 'upstream_5xx',
    upstreamStatus: 503,
  });

/** Captures everything written at log and warn level. */
class LogCapture {
  readonly log: string[] = [];
  readonly warn: string[] = [];

  install(): void {
    jest.spyOn(Logger.prototype, 'log').mockImplementation((message: unknown) => {
      this.log.push(String(message));
    });
    jest.spyOn(Logger.prototype, 'warn').mockImplementation((message: unknown) => {
      this.warn.push(String(message));
    });
  }

  get all(): string[] {
    return [...this.log, ...this.warn];
  }

  get joined(): string {
    return this.all.join('\n');
  }
}

/** Parses `key=value` pairs out of one emitted line. */
function fields(line: string): Record<string, string> {
  const result: Record<string, string> = {};
  for (const token of line.replace(/^ai\.query /, '').split(' ')) {
    const [key, value] = token.split('=');
    if (key !== undefined && value !== undefined) {
      result[key] = value;
    }
  }
  return result;
}

describe('AI observability', () => {
  let capture: LogCapture;

  beforeEach(() => {
    capture = new LogCapture();
    capture.install();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('scenario 1 — success', () => {
    it('records provider, outcome and latency', async () => {
      const primary = new StubProvider('openai-compatible', succeeds(OK_DTO));

      await new AiService(primary, null).query('find hotels');

      expect(capture.log).toHaveLength(1);
      expect(capture.warn).toHaveLength(0);

      const line = capture.log[0];
      expect(line.startsWith('ai.query ')).toBe(true);

      const f = fields(line);
      expect(f.provider).toBe('openai-compatible');
      expect(f.outcome).toBe('success');
      expect(f.latencyMs).toMatch(/^\d+$/);
      // No failure vocabulary on a success.
      expect(f.category).toBeUndefined();
    });

    it('emits exactly one line per query', async () => {
      const primary = new StubProvider('openai-compatible', succeeds(OK_DTO));
      const service = new AiService(primary, null);

      await service.query('one');
      await service.query('two');
      await service.query('three');

      expect(capture.all).toHaveLength(3);
    });
  });

  describe('scenario 2 — failure', () => {
    it('records the error category and upstream status at warn level', async () => {
      const primary = new StubProvider('openai-compatible', failsWith(serverFailure()));

      await expect(new AiService(primary, null).query('find hotels')).rejects.toBeInstanceOf(
        AiProviderFailure,
      );

      expect(capture.log).toHaveLength(0);
      expect(capture.warn).toHaveLength(1);

      const f = fields(capture.warn[0]);
      expect(f.provider).toBe('openai-compatible');
      expect(f.outcome).toBe('failure');
      expect(f.category).toBe('upstream_5xx');
      expect(f.upstreamStatus).toBe('503');
      expect(f.latencyMs).toMatch(/^\d+$/);
    });

    it('categorises each provider failure kind distinctly', async () => {
      const cases: Array<[AiProviderFailure, string]> = [
        [
          new AiProviderFailure('x', { category: 'not_configured' }),
          'not_configured',
        ],
        [new AiProviderFailure('x', { category: 'network' }), 'network'],
        [new AiProviderFailure('x', { category: 'timeout' }), 'timeout'],
        [
          new AiProviderFailure('x', { category: 'upstream_4xx', upstreamStatus: 401 }),
          'upstream_4xx',
        ],
        [
          new AiProviderFailure('x', { category: 'empty_completion', upstreamStatus: 200 }),
          'empty_completion',
        ],
      ];

      for (const [error, expected] of cases) {
        capture = new LogCapture();
        capture.install();
        const primary = new StubProvider('openai-compatible', failsWith(error));

        await expect(new AiService(primary, null).query('p')).rejects.toBeDefined();

        expect(fields(capture.warn[0]).category).toBe(expected);
      }
    });

    it('reports an unexpected defect as category=unexpected', async () => {
      const primary = new StubProvider(
        'openai-compatible',
        failsWith(new TypeError('cannot read properties of undefined')),
      );

      await expect(new AiService(primary, null).query('p')).rejects.toBeInstanceOf(TypeError);

      const f = fields(capture.warn[0]);
      expect(f.category).toBe('unexpected');
      expect(f.upstreamStatus).toBeUndefined();
      // The thrown message is classified, never quoted.
      expect(capture.joined).not.toContain('cannot read properties');
    });
  });

  describe('scenario 4 — latency recorded', () => {
    it('reports a latency at least as large as the provider delay', async () => {
      const primary = new StubProvider('openai-compatible', succeeds(OK_DTO), 60);

      await new AiService(primary, null).query('find hotels');

      const latency = Number(fields(capture.log[0]).latencyMs);
      expect(Number.isInteger(latency)).toBe(true);
      expect(latency).toBeGreaterThanOrEqual(55);
      expect(latency).toBeLessThan(5_000);
    });

    it('records a latency even on failure', async () => {
      const primary = new StubProvider('openai-compatible', failsWith(serverFailure()), 30);

      await expect(new AiService(primary, null).query('p')).rejects.toBeDefined();

      expect(Number(fields(capture.warn[0]).latencyMs)).toBeGreaterThanOrEqual(25);
    });
  });

  describe('scenario 5 — prompts, bodies and secrets are never logged', () => {
    it('omits the prompt and every secret inside it', async () => {
      const primary = new StubProvider('openai-compatible', succeeds(OK_DTO));

      await new AiService(primary, null).query(SECRET_PROMPT);

      expect(capture.all).toHaveLength(1);
      expect(capture.joined).not.toContain(SECRET_PROMPT);
      expect(capture.joined).not.toContain('sk-or-v1-super-secret');
      expect(capture.joined).not.toContain('4111111111111111');
      expect(capture.joined).not.toContain('Find hotels');
    });

    it('omits the response body', async () => {
      const primary = new StubProvider('openai-compatible', succeeds(OK_DTO));

      await new AiService(primary, null).query('find hotels');

      expect(capture.joined).not.toContain('confidential itinerary');
      expect(capture.joined).not.toContain('q-1');
      expect(capture.joined).not.toContain('sections');
      expect(capture.joined).not.toContain('{');
    });

    it('omits credential material carried on a failure', async () => {
      const primary = new StubProvider(
        'openai-compatible',
        failsWith(
          new AiProviderFailure(
            `upstream rejected ${SECRET_BEARER} for https://openrouter.ai/api/v1`,
            { category: 'upstream_4xx', upstreamStatus: 401 },
          ),
        ),
      );

      await expect(new AiService(primary, null).query(SECRET_PROMPT)).rejects.toBeDefined();

      expect(capture.joined).not.toContain('Bearer');
      expect(capture.joined).not.toContain('sk-or-v1-super-secret');
      expect(capture.joined).not.toContain('openrouter.ai');
      expect(capture.joined).not.toContain('upstream rejected');
      // Only the classification survives.
      expect(fields(capture.warn[0]).category).toBe('upstream_4xx');
    });

    it('emits only the whitelisted keys and nothing else', async () => {
      const primary = new StubProvider('openai-compatible', failsWith(serverFailure()));

      // Single provider: the failure propagates to the caller.
      await expect(new AiService(primary, null).query(SECRET_PROMPT)).rejects.toBeInstanceOf(
        AiProviderFailure,
      );

      const allowed = new Set([
        'provider',
        'outcome',
        'latencyMs',
        'category',
        'upstreamStatus',
      ]);
      for (const line of capture.all) {
        expect(line.startsWith('ai.query ')).toBe(true);
        for (const key of Object.keys(fields(line))) {
          expect(allowed.has(key)).toBe(true);
        }
        // A single line of scalars: no payload could hide in it.
        expect(line).not.toContain('\n');
        expect(line.length).toBeLessThan(160);
      }
    });

    it('formatAiAttempt is a pure whitelist renderer', () => {
      const line = formatAiAttempt({
        provider: 'openai-compatible',
        outcome: 'failure',
        latencyMs: 42,
        category: 'upstream_5xx',
        upstreamStatus: 503,
      });

      expect(line).toBe(
        'ai.query provider=openai-compatible outcome=failure ' +
          'latencyMs=42 category=upstream_5xx upstreamStatus=503',
      );
    });
  });
});

describe('observability over real HTTP', () => {
  let mockServer: Server;
  let mockPort: number;
  let app: INestApplication;
  let appUrl: string;
  let responder: (req: IncomingMessage, res: ServerResponse) => void;
  let capture: LogCapture;

  beforeAll(async () => {
    mockServer = createServer((req, res) => {
      req.resume();
      req.on('end', () => responder(req, res));
    });
    await new Promise<void>((resolve) => {
      mockServer.listen(0, '127.0.0.1', () => resolve());
    });
    mockPort = (mockServer.address() as AddressInfo).port;

    @Module({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          ignoreEnvVars: true,
          load: [
            () => ({
              AI_API_KEY: 'test-key-not-a-secret',
              AI_BASE_URL: `http://127.0.0.1:${mockPort}/v1`,
              AI_MODEL: 'mock-model',
            }),
          ],
        }),
        AiModule,
      ],
    })
    class ObservabilityRootModule {}

    app = await NestFactory.create(ObservabilityRootModule, { logger: false });
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
    capture = new LogCapture();
    capture.install();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  async function query(prompt: string): Promise<number> {
    const res = await fetch(`${appUrl}/ai/query`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt }),
    });
    await res.text();
    return res.status;
  }

  it('logs a real success without the prompt or the completion', async () => {
    responder = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          choices: [
            {
              message: {
                role: 'assistant',
                content: '{"text":"secret itinerary text","sections":[]}',
              },
            },
          ],
        }),
      );
    };

    expect(await query(SECRET_PROMPT)).toBe(201);

    expect(capture.log).toHaveLength(1);
    const f = fields(capture.log[0]);
    expect(f.provider).toBe('openai-compatible');
    expect(f.outcome).toBe('success');
    expect(Number(f.latencyMs)).toBeGreaterThanOrEqual(0);

    expect(capture.joined).not.toContain('sk-or-v1-super-secret');
    expect(capture.joined).not.toContain('secret itinerary text');
    expect(capture.joined).not.toContain('test-key-not-a-secret');
    expect(capture.joined).not.toContain('127.0.0.1');
  });

  it('logs a real 5xx as upstream_5xx with a single failure line (no fallback)', async () => {
    responder = (_req, res) => {
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end('{"error":"upstream down"}');
    };

    // Single provider: the upstream failure surfaces to the caller as 503.
    expect(await query(SECRET_PROMPT)).toBe(503);

    expect(capture.warn).toHaveLength(1);
    expect(capture.log).toHaveLength(0);

    const line = fields(capture.warn[0]);
    expect(line.category).toBe('upstream_5xx');
    expect(line.upstreamStatus).toBe('502');
    expect(line.outcome).toBe('failure');

    expect(capture.joined).not.toContain('upstream down');
    expect(capture.joined).not.toContain('sk-or-v1-super-secret');
  });

  it('logs a real 4xx as upstream_4xx with no fallback attempt', async () => {
    responder = (_req, res) => {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end('{"error":"invalid key"}');
    };

    expect(await query(SECRET_PROMPT)).toBe(503);

    expect(capture.all).toHaveLength(1);
    const f = fields(capture.warn[0]);
    expect(f.category).toBe('upstream_4xx');
    expect(f.upstreamStatus).toBe('401');
    expect(capture.joined).not.toContain('invalid key');
  });

  it('logs nothing when validation rejects the request before any provider', async () => {
    responder = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{}');
    };

    expect(await query('')).toBe(400);

    // No provider was attempted, so there is no attempt to record.
    expect(capture.all).toHaveLength(0);
  });
});
