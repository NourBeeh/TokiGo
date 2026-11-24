/**
 * Runtime environment classification.
 *
 * The payment containment boundary is `NODE_ENV=production`. Tests run with
 * `NODE_ENV=test` and/or Jest's `JEST_WORKER_ID`; the explicit Jest check keeps
 * the mock gateway constructible in a test process even when a spec temporarily
 * flips `NODE_ENV` to exercise a production guard.
 */
export function isProductionRuntime(): boolean {
  return (
    process.env.NODE_ENV === 'production' && !process.env.JEST_WORKER_ID
  );
}

export function isTestRuntime(): boolean {
  return process.env.NODE_ENV === 'test' || !!process.env.JEST_WORKER_ID;
}
