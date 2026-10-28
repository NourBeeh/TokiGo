import { describe, it, expect } from '@jest/globals';
import { extractJsonContent, tryParseJson, normalizeAiResponse, asRecord, asString, asNumber } from '../src/modules/ai/openai.ai.provider';

describe('AI Contract: extractJsonContent', () => {
  it('extracts JSON from fenced code block with ```json', () => {
    const content = 'Here is the answer```json {"text": "test", "sections": []}```';
    const result = extractJsonContent(content);
    expect(result).toBe('{"text": "test", "sections": []}');
  });

  it('extracts JSON from fenced code block without json keyword', () => {
    const content = 'Answer: ```{ "text": "test" }```';
    const result = extractJsonContent(content);
    expect(result).toContain('"text"');
  });

  it('uses balanced braces when no fences present', () => {
    const content = 'Some text { "text": "test" } more text';
    const result = extractJsonContent(content);
    expect(result).toContain('"text"');
  });

  it('returns trimmed content when no JSON found', () => {
    const content = 'Just some random text without JSON';
    const result = extractJsonContent(content);
    expect(result).toBe('Just some random text without JSON');
  });
});

describe('AI Contract: tryParseJson', () => {
  it('parses valid JSON', () => {
    const result = tryParseJson('{"key": "value"}');
    expect(result).toEqual({ key: 'value' });
  });

  it('returns null for invalid JSON', () => {
    const result = tryParseJson('not json');
    expect(result).toBeNull();
  });

  it('returns null for empty string', () => {
    const result = tryParseJson('');
    expect(result).toBeNull();
  });
});

describe('AI Contract: normalizeAiResponse', () => {
  it('returns safe fallback when parsing fails', () => {
    const result = normalizeAiResponse('This is not JSON at all');
    expect(result.sections).toEqual([]);
    expect(result.text).toContain('I received a response from the AI assistant, but I couldn\'t parse the suggestions at this time. Please try again.')
    expect(result.metadata.parseFallback).toBe(true);
  });

  it('returns normalized response for valid JSON', () => {
    const validInput = '{"text": "Hello", "sections": []}';
    const result = normalizeAiResponse(validInput);
    expect(result.text).toBe('Hello');
    expect(result.sections).toEqual([]);
    expect(result.metadata.parseFallback).toBeUndefined();
  });

  it('handles missing text with fallback string', () => {
    const input = '{"sections": []}';
    const result = normalizeAiResponse(input);
    expect(result.text).toBe('I received a response from the AI assistant.');
  });

  it('preserves sections when present', () => {
    const input = '{"text": "Hello", "sections": [{ "title": "Test", "layout": "vertical", "items": [] }]}';
    const result = normalizeAiResponse(input);
    expect(result.sections.length).toBe(1);
    expect(result.sections[0].title).toBe('Test');
  });
});

describe('AI Contract: utility functions', () => {
  it('asRecord returns null for non-object', () => {
    expect(asRecord(null)).toBeNull();
    expect(asRecord(undefined)).toBeNull();
    expect(asRecord('string')).toBeNull();
    expect(asRecord(42)).toBeNull();
    expect(asRecord([1, 2, 3])).toBeNull();
  });

  it('asRecord returns object for valid input', () => {
    expect(asRecord({ a: 1 })).toEqual({ a: 1 });
  });

  it('asString returns undefined for non-string', () => {
    expect(asString(null)).toBeUndefined();
    expect(asString(42)).toBeUndefined();
    expect(asString({})).toBeUndefined();
    expect(asString('hello')).toBe('hello');
  });

  it('asNumber returns undefined for non-finite number', () => {
    expect(asNumber(undefined)).toBeUndefined();
    expect(asNumber('na')).toBeUndefined();
    expect(asNumber(42)).toBe(42);
    expect(asNumber(3.14)).toBe(3.14);
  });
});
