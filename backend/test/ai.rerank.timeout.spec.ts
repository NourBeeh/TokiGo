import { describe, it, expect, jest } from '@jest/globals';

import { withTimeout } from '../src/modules/ai/ai.rerank.controller';

/**
 * P4-1 hygiene — the `withTimeout` timer must not outlive the race.
 *
 * P4-0 proved with `--detectOpenHandles` that every open handle originated
 * from the `setTimeout` in `withTimeout` (ai.rerank.controller.ts:156): the
 * timer was never cleared, so a slow AI call kept a `Timeout` handle pending
 * for the whole window. These tests pin the cleanup behaviour using fake
 * timers, where a leaked timer is observable as `jest.getTimerCount() > 0`.
 */
describe('AI rerank withTimeout — timer cleanup', () => {
  it('clears the timer when the wrapped operation resolves', async () => {
    jest.useFakeTimers();
    try {
      await withTimeout(Promise.resolve('ok'), 10_000);
      expect(jest.getTimerCount()).toBe(0);
    } finally {
      jest.useRealTimers();
    }
  });

  it('clears the timer when the wrapped operation rejects', async () => {
    jest.useFakeTimers();
    try {
      await expect(
        withTimeout(Promise.reject(new Error('boom')), 10_000),
      ).rejects.toThrow('boom');
      expect(jest.getTimerCount()).toBe(0);
    } finally {
      jest.useRealTimers();
    }
  });

  it('still rejects on timeout and leaves no timer handle behind', async () => {
    jest.useFakeTimers();
    try {
      const pending = withTimeout(new Promise<never>(() => {}), 10_000);
      const assertion = expect(pending).rejects.toThrow('rerank timeout');
      jest.advanceTimersByTime(10_000);
      await assertion;
      expect(jest.getTimerCount()).toBe(0);
    } finally {
      jest.useRealTimers();
    }
  });
});
