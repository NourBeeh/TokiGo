# Phase 3C — Consolidated Payment / Booking Lifecycle Implementation Report

**Date:** 2026-11-24  
**Baseline:** branch `Main`, HEAD `c972da397673467000314201dd9ff2b5469fa053`  
**Final state:** same branch and HEAD; working tree still dirty with the pre-existing user work plus the task-owned changes listed in §8  
**Prior audit:** `docs/phase-3c-payment-booking-lifecycle-audit.md`  
**Scope:** Phase 3C.1 payment-security containment verification, Flutter unknown-outcome handling, official Duffel/Nuitee contract alignment, and provider-specific booking/payment lifecycle guards. The Egyptian PSP integration remains explicitly out of scope.

---

## 0. Safety statement

This phase did **not**:

- run `git reset`, `git clean`, `git stash`, `git checkout`, or `git restore`;
- stage, commit, or push anything;
- delete or overwrite any pre-existing user change;
- read, print, or modify any `.env` file;
- use a real payment card, a real PSP, or production credentials;
- call a live Duffel, Nuitee, or payment-provider endpoint;
- perform a production booking, charge, refund, or cancellation;
- integrate an Egyptian PSP or enable production finance.

No provider/sandbox credentials were inspected. Consequently, **no sandbox operation was executed and there are no redacted sandbox responses in this report**. The stop condition “missing/unverified sandbox credentials” was honored rather than bypassed.

Evidence in this report is classified as:

| Class | Meaning |
|---|---|
| **Documented** | Stated by the provider's official API documentation, with the URL cited |
| **Implemented** | Present in this repository and compiled |
| **Unit/mock tested** | Exercised by Jest with fake transports — no network |
| **Provider sandbox verified** | Executed against an official provider sandbox with approved sandbox credentials — **none in this phase** |
| **Live verified** | Executed against production with real money — **none, and out of scope** |

---

## 1. Executive summary

### 1.1 Implemented and verified at code level

- The Phase 3C.1 payment-security migration `1731000000013-PaymentSecurityContainment` exists and defines the durable payment↔booking security columns. Its PostgreSQL execution is **not verified** because no test database is available (§3).
- Flutter now has a dedicated terminal state for `booking_outcome_unknown`: it is mapped separately from duplicate, failed, and price-changed responses, blocks retry/revalidation, and disables the pay action (§4).
- The Duffel adapter no longer sends `payments: []`; it sends Duffel's official `balance` instrument with the server-authoritative amount/currency and refuses to call Duffel when those values are missing (§5.4, §6.3).
- Duffel, Nuitee Hotels, and Nuitee Flights remain separate provider implementations with separate request contracts and separate confirmation semantics. No provider's identifiers, status vocabulary, or payment model leaks into another (§6.3, §6.5).
- Provider booking attempts are bound to the TokiGo booking, accepted amount, currency, price version, and payment attempt via documented provider idempotency/metadata fields (§6.1, §6.2).
- A booking can only become `confirmed` when the provider itself establishes confirmation **and** the provider-reported amount/currency matches the accepted commercial state. Otherwise the booking becomes `reconciliation_pending` with evidence, and retries remain blocked (§6.2).
- Ambiguous outcomes never trigger an automatic charge, refund, or second booking. They remain blocked for admin-only reconciliation (§6.4).
- Nuitee duplicate codes `4005` (hotel `clientReference`) and `45035` (flight `prebookId`) are classified as ambiguous, not as definitive rejections (§6.4).

### 1.2 Executed checks

| Check | Result |
|---|---|
| Production TypeScript compile | exit `0` |
| Test TypeScript compile | exit `0` |
| Focused Jest (14 suites) | 14 passed, 185 tests passed, exit `0` |
| Full Jest | 77 passed + 5 skipped suites (82); 890 passed + 115 skipped tests (1005); exit `0` |
| Explicit DB-gated suites | 3 suites skipped, 111 tests skipped, exit `0` |
| Flutter tests / `flutter analyze` | **not run** — Device Guard blocks `dart.exe` |
| PostgreSQL migration application | **not run** — no `P4_TEST_DB_URL`/database tooling |
| Provider sandbox calls | **not run** — credentials unverified; `.env` not inspected |
| `git diff --check` | exit `2`; only the pre-existing `nuitee.service.ts` EOF blank line |

### 1.3 Headline blockers

1. **No isolated PostgreSQL database** — Phase A database verification remains unproven.
2. **Flutter execution blocked by organization Device Guard** — the new Flutter code and tests are statically reviewed only.
3. **Provider sandbox credential availability unverified** — no sandbox booking/payment was attempted.
4. **Nuitee account prerequisites unverified** — `ACC_CREDIT_CARD` with `usePaymentSdk: false` requires Nuitee approval; whether this account has it is unknown.
5. **Duffel balance funding unverified** — `balance` is documented as unlimited in Duffel test mode, but the account's sandbox configuration was not tested.
6. **Reconciliation is still manual and admin-only** — no scheduled provider-status worker was added (out of scope for this phase).

---

## 2. Baseline and final repository state

| Item | Value |
|---|---|
| Branch | `Main` |
| HEAD at start | `c972da397673467000314201dd9ff2b5469fa053` |
| HEAD at end | `c972da397673467000314201dd9ff2b5469fa053` (unchanged) |
| Stash | none created or used |
| Working tree at end | dirty, 276 `git status --porcelain` entries |
| Tracked diff at end | 199 files changed, 12,745 insertions, 10,272 deletions |
| Pre-existing state | the tree was already extensively dirty before Phase 3C; that work was preserved |

The tracked diff count includes the large body of pre-existing user work that was already present at baseline. The task-owned file set is listed separately in §8. No tracked file was reverted to HEAD to “clean up” the diff.

`git diff --check` was run at the end of the phase:

```text
EXIT=2
backend/src/modules/nuitee/nuitee.service.ts:901: new blank line at EOF.
```

The same blank line was already documented as pre-existing in the prior audit (`nuitee.service.ts:895` at that time). The line number moved because task-owned edits added lines above it in the same file. It was deliberately left untouched. `git diff --check` does not inspect untracked files, so new files are not covered by this check.

---

## 3. Phase A — payment-security migration verification

### 3.1 Migration present

- File: `backend/src/database/migrations/1731000000013-PaymentSecurityContainment.ts`
- Class: `PaymentSecurityContainment1731000000013`
- Migration directory contains **14** migration files.
- `up()` adds:
  - `bookings."priceVersion" varchar(255)`;
  - `payment_attempts."priceVersion" varchar(255)`;
  - `payment_attempts."verifiedAt" timestamptz`;
  - index `idx_payment_attempts_booking_price_version` on `payment_attempts ("bookingId", "priceVersion")`.
- `down()` removes the index, the two attempt columns, and the booking column.
- The migration deliberately performs **no backfill**: pre-existing attempts have no server-observed payment evidence, so they remain unverified and cannot authorize a booking or refund.
- The migration was verified by reading it and by the successful TypeScript compiles. It was **not** applied to a PostgreSQL instance.

### 3.2 Execution attempt and exact result

Environment checks (no secret values printed):

```text
P4_TEST_DB_URL=absent
DATABASE_URL=absent
```

No `psql`, `docker`, `pg_ctl`, or local PostgreSQL service was available.

```text
npx.cmd jest --runInBand --silent test/p4.persistence.spec.ts test/p4.schema.spec.ts test/payments.orchestration.spec.ts
```

Result:

```text
Test Suites: 3 skipped, 0 of 3 total
Tests:       111 skipped, 111 total
Time:        6.965 s
EXIT=0
```

The suites use a DB-gated `describe`/`describe.skip` pattern. Exit code `0` only means the skipped suites did not fail — it is **not** evidence that the migration works on PostgreSQL.

### 3.3 Phase A conclusion

| Question | Answer |
|---|---|
| Migration file exists with the required columns/index? | **Yes (static verification)** |
| Migration applies cleanly to an isolated DB? | **Unverified** |
| `p4.persistence.spec.ts` passes against PostgreSQL? | **Not executed** |
| `p4.schema.spec.ts` sees 14 migrations? | **Not executed** |
| `payments.orchestration.spec.ts` passes against PostgreSQL? | **Not executed** |

**Blocker:** no `P4_TEST_DB_URL` and no database tooling. This phase must be re-run on an isolated database before any claim of database-level completion.

---

## 4. Phase B — Flutter `booking_outcome_unknown` handling

### 4.1 Backend contract consumed

The backend returns HTTP `409` with a structured body equivalent to:

```json
{
  "code": "booking_outcome_unknown",
  "message": "...",
  "details": {
    "status": "reconciliation_pending",
    "requiresReconciliation": true,
    "retryable": false,
    "operationStatus": "unknown"
  }
}
```

### 4.2 Error mapping

`lib/features/booking/domain/booking_error.dart`:

- adds `BookingErrorCode.bookingOutcomeUnknown`;
- recognises the structured reconciliation flags **before** the generic `409 → duplicateRequest` fallback;
- matches `code: booking_outcome_unknown`, `status: reconciliation_pending`, `requiresReconciliation: true`, or `operationStatus: unknown` with `retryable: false`;
- preserves the backend message and `details`;
- leaves ordinary `409 duplicate_request`, `price_changed`, provider failures, and other statuses on their existing paths.

This ordering is the key safety property: an unknown outcome can never collapse into the duplicate-request flow, and a duplicate can never be promoted to an unknown outcome.

### 4.3 Controller behaviour

`lib/features/booking/application/booking_controller.dart`:

- `confirm()` returns immediately when the phase is `reconciliationPending` — no second provider booking, no state overwrite;
- `revalidate()` returns immediately in that phase — for hotels a revalidation can create a provider hold, so it is not reissued;
- a `bookingOutcomeUnknown` error sets `BookingPhase.reconciliationPending`, keeps the existing record, keeps the exact idempotency key, and stores the backend message;
- confirmed, definitive-failure, duplicate, and price-change flows are unchanged because only the new code selects the new phase.

### 4.4 UI behaviour

| Surface | Behaviour |
|---|---|
| Booking review page | Shows the pending-verification banner (`bookingOutcomePendingTitle` / `bookingOutcomePendingBody`). The primary action for `reconciliationPending` is leaving the funnel, not retrying. |
| Checkout page | `_pay()` redirects to `/booking/review` if the state is already pending; the pay button is disabled while pending. |
| Navigation away/back | The controller state remains `reconciliationPending`, so `confirm()` and `revalidate()` stay no-ops. Reopening the surface cannot re-issue the provider booking. |
| My Trips | The pending booking is not presented as confirmed; the localisation text explicitly says it appears in My Trips only after confirmation. |

### 4.5 Localisation

Keys `bookingOutcomePendingTitle` and `bookingOutcomePendingBody` were added to:

- `lib/l10n/app_en.arb`
- `lib/l10n/app_ar.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_ar.dart`

The generated Dart localisation files were edited manually because `flutter gen-l10n` could not run. They must be regenerated once Flutter tooling is available, to confirm the generated output matches the `.arb` sources exactly.

### 4.6 Flutter tests

New file: `test/booking_outcome_unknown_test.dart` — 10 tests covering:

- canonical body → `bookingOutcomeUnknown`;
- structured flags without the code;
- ordinary duplicate `409` stays `duplicateRequest`;
- `price_changed` keeps the price-change flow;
- message/details preservation;
- repository transport mapping;
- controller no-retry behaviour.

**Execution blocker:** every Flutter/Dart command fails before running:

```text
'C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe' was blocked by your organization's Device Guard policy.
Exit code: 1
```

`flutter --version`, `dart --version`, `flutter test`, `flutter analyze`, and `flutter gen-l10n` therefore could not run. The Dart changes were reviewed statically only. This is **not** the same as a passing Flutter test run.

---

## 5. Phase C — official provider contracts and defect removal

### 5.1 Duffel Flights — documented contract

Sources:

- `https://duffel.com/docs/api/v2/orders`
- `https://duffel.com/docs/api/payments/create-payment`
- `https://duffel.com/docs/guides/getting-an-accurate-price-before-booking`

Documented facts applied:

- Instant order creation requires a `payments` instruction; an empty array is not a valid payment instruction.
- `balance` is an official payment instrument, unlimited in Duffel test mode.
- `payment_status.awaiting_payment` and `payment_status.paid_at` are the payment-state evidence; an order that is merely created/awaiting payment is not confirmed.
- `cancelled_at` is definitive failure evidence.
- The Order resource has **no** generic `status` property; the adapter must not invent one.
- Order `metadata` accepts up to 50 key/value string pairs.
- A failed HTTP request does not prove the order was not created; the adapter therefore classifies thrown provider calls as ambiguous.

### 5.2 Nuitee Hotels — documented contract

Source: `https://docs.liteapi.travel/reference/post_rates-book`

Documented facts applied:

- `clientReference` is the documented idempotency key; a duplicate submission returns provider code `4005`.
- `customTags` allows at most 5 tags; keys match `^[A-Z0-9_-]+$`; values are at most 255 characters.
- `payment.method: 'ACC_CREDIT_CARD'` with the existing sandbox configuration simulates the booking without a real charge.
- Booking statuses used for confirmation: `CONFIRMED` is confirmation; `CANCELED`/`CANCELLED` and related failed statuses are definitive failure; `CREATED`/`PENDING`/unknown stay pending.
- `GET /bookings/{bookingId}` is the retrieval path (not added to the automatic flow in this phase).
- The hotel confirmation code may be absent at booking time; the adapter falls back to the provider booking id, never to an invented code.

### 5.3 Nuitee Flights — documented contract

Source: `https://docs.liteapi.travel/reference/post_flights-bookings`

Documented facts applied:

- Booking is idempotent by `prebookId`.
- A concurrent duplicate returns HTTP `409` with provider code `45035`.
- The documented success shape is `data: [{ booking: FlightBooking, message }]`; the adapter parses `data[0].booking` and tolerates a legacy flat `data` object.
- Statuses: `CREATED` and `PENDING_CONFIRMATION` are not tickets; `CONFIRMED` establishes the booking and tickets; `CANCELLED` and `CANCELLED_WITH_CHARGES` are definitive failure.
- `customTags` are supported and are sent.
- `GET /flights/bookings/{bookingId}` is authoritative for later reconciliation (method exists; not wired into an automatic worker in this phase).
- The booking price is read from the journey price when published; the adapter never fabricates `0 USD`.

### 5.4 Removed Duffel defect

**Before:** `duffel-booking.provider.ts` called `createOrder(..., [])`, and the adapter test pinned `payments: []`.

**After:**

- `createBooking` resolves the server-authoritative `amount` and ISO-4217 `currency`;
- if either is missing/invalid, it fails **before** any Duffel call;
- otherwise it sends exactly one official `balance` payment:

```ts
payments: [{ type: 'balance', amount: <authoritative amount string>, currency: <ISO currency> }]
```

- the amount string uses the provider's exact final-revalidation text when it denotes the same amount; otherwise the authoritative number is serialized without rounding;
- order metadata is built from the shared `bookingProviderTags()` helper;
- confirmation is derived from `cancelled_at` / `payment_status.awaiting_payment` / `payment_status.paid_at`;
- any thrown Duffel call is returned as `failureKind: 'ambiguous'`.

No card number, CVV, or customer payment credential is ever sent to Duffel.

### 5.5 Sandbox credential status

- `backend/.env` was deliberately **not** read, printed, or modified.
- No environment variable was used to infer provider account approval.
- No `POST /orders`, `POST /rates/book`, `POST /flights/bookings`, or any other provider request was made.
- Therefore: **Duffel sandbox balance availability, Nuitee `ACC_CREDIT_CARD` approval, and Nuitee credit-line/CMI status remain unverified.**

Per the stop condition, the phase did not attempt a sandbox booking merely to discover whether credentials worked.

---

## 6. Phase D — provider-specific booking/payment lifecycle

### 6.1 Shared contract and binding

`backend/src/common/providers/booking-provider.interface.ts` now carries:

```ts
interface CreateBookingInput {
  offerId: string;
  offerSnapshot?: Record<string, any>;
  travelers?: any[];
  bookingId?: string;
  amount?: number;
  currency?: string;
  amountText?: string;
  priceVersion?: string;
  paymentAttemptId?: string;
}

type ProviderConfirmationState = 'confirmed' | 'pending' | 'failed' | 'unknown';

interface CreatedBooking {
  reference: string;
  providerBookingId?: string;
  status?: string;
  amount?: number;
  currency?: string;
  raw?: Record<string, any>;
  confirmationState?: ProviderConfirmationState;
}
```

`backend/src/common/providers/booking-confirmation.ts` centralises:

- `confirmationStateOfStatus()`:
  - confirmed: `CONFIRMED`, `TICKETED`, `BOOKED`;
  - failed: `CANCELED`, `CANCELLED`, `CANCELLED_WITH_CHARGES`, `FAILED`, `REJECTED`;
  - pending: `CREATED`, `PENDING`, `PENDING_CONFIRMATION`, `REQUESTED`, `PROCESSING`, `IN_PROGRESS`;
  - everything else: `unknown`.
- `bookingProviderTags()`: deterministic, non-PII tags `BOOKING_ID`, `PRICE_VERSION`, `PAYMENT_ATTEMPT`, `AMOUNT`, `CURRENCY`; at most five; values ≤255; keys valid for both Nuitee `customTags` and Duffel metadata.

### 6.2 `BookingsService.create` confirmation gate

The service now passes to the provider:

- `bookingId` — the TokiGo booking id;
- `amount` — the live authoritative price;
- `currency` — the live authoritative currency;
- `amountText` — the provider's exact final price text when available;
- `priceVersion` — the accepted commercial version;
- `paymentAttemptId` — the linked payment attempt when present.

After the provider call, the service:

1. Normalises confirmation via `createdData.confirmationState ?? confirmationStateOfStatus(createdData.status)`.
2. Compares provider-reported amount/currency to the booking's authoritative amount/currency with tolerance `0.01`.
3. **Confirmed path:** only when the provider state is `confirmed` **and** amount/currency match. It records the provider evidence and calls `finalizeConfirmed()`, which re-verifies payment evidence immediately before writing `confirmed`.
4. **Provider-failed path:** records the provider reference/id/status, marks the booking `failed`, releases the idempotency key, and returns `provider_error`.
5. **Pending/unknown/mismatch path:** persists the provider evidence, marks the booking `reconciliation_pending`, keeps the idempotency key blocked, audits the event, and throws `booking_outcome_unknown` with:
   - `status: 'reconciliation_pending'`;
   - `requiresReconciliation: true`;
   - `retryable: false`;
   - `operationStatus: 'unknown'`.

The provider evidence stored includes the provider reference, provider booking id, provider status, confirmation state, amount, currency, error/reason, and timestamps. This gives the admin reconciliation path what it needs without inventing a confirmation.

### 6.3 Provider-specific sequences as implemented

#### Duffel Flights

| Step | Implemented behaviour |
|---|---|
| Revalidate | Existing Duffel revalidation; captures live price, currency, terms, and offer passenger ids |
| Prepare binding | `bookingId`, live amount/currency, `priceVersion`, `paymentAttemptId` passed to the adapter |
| Pre-call validation | Refuses empty traveller list, missing offer passenger ids, incomplete passenger data, missing authoritative amount/currency |
| Provider call | `POST` order (via `DuffelService.createOrder`) as instant order with `payments: [{type:'balance', ...}]` and metadata |
| Confirmation | `payment_status.paid_at` present and `awaiting_payment` false → confirmed; `cancelled_at` → failed; awaiting/pending/no payment evidence → pending/unknown |
| Amount check | Provider `total_amount`/`total_currency` compared to accepted amount/currency |
| Ambiguity | Thrown provider call → ambiguous; no retry opened |
| Ticketing claim | None beyond Duffel's paid-order confirmation semantics |

#### Nuitee Hotels

| Step | Implemented behaviour |
|---|---|
| Revalidate/prebook | Existing hotel prebook; snapshot keeps `prebookId`, room count, cancellation/price context |
| Binding | `clientReference = bookingId`; `customTags` from the shared helper |
| Provider call | `POST /rates/book` with holder, guests, `prebookId`, `payment: { method: 'ACC_CREDIT_CARD' }` |
| Confirmation | Only explicit `CONFIRMED` status confirms; `CANCELED`/failed statuses fail; `CREATED`/`PENDING`/unknown stay pending |
| Amount check | Provider `total`/`currency` compared to accepted values |
| Duplicate | Provider code `4005` classified ambiguous even on HTTP 400 |
| Reference | Confirmation code or booking id; never an invented code |
| Cancellation | Still unsupported in this phase |

#### Nuitee Flights

| Step | Implemented behaviour |
|---|---|
| Revalidate/prebook | Confirm-time revalidation creates one prebook with the real party; book does not prebook again |
| Binding | `customTags` from the shared helper; provider idempotency is `prebookId` |
| Provider call | `POST /flights/bookings` with `prebookId`, `payment: { method: 'ACC_CREDIT_CARD' }`, `customTags` |
| Response parsing | `data[0].booking`; legacy flat `data` tolerated |
| Confirmation | Only `CONFIRMED` (tickets issued) confirms; `CREATED`/`PENDING_CONFIRMATION` pending; `CANCELLED`/`CANCELLED_WITH_CHARGES` failed |
| Amount check | Journey price/currency when published; never fabricated |
| Duplicate | Provider code `45035` classified ambiguous even on HTTP 409 |
| Reference | `bookingRef` or `bookingId`; never the `prebookId` |
| Cancellation | Still unsupported in this phase |

### 6.4 Ambiguous outcome and duplicate handling

`backend/src/common/providers/booking-failure.ts`:

- defaults to **ambiguous**;
- only a well-formed `4xx` (excluding `408`, `409`, `425`, `429`) is definitive;
- provider codes `4005` and `45035` are ambiguous regardless of status;
- missing status, `5xx`, and transport errors are ambiguous;
- `NUITEE_API_KEY missing` is definitive because no request was sent.

The booking service only reopens a booking on a **definitive** provider failure or a provider-confirmed `failed` status. Unknown outcomes remain blocked. There is no automatic refund, capture, or second booking after ambiguity.

### 6.5 Explicit non-goals and unchanged behaviour

- Egyptian PSP integration was not added.
- No production payment gateway was enabled.
- Provider cancellation remains unsupported for all three providers.
- No scheduled reconciliation/worker was added; reconciliation remains admin-only and manual.
- No automatic provider-status polling was added.
- No claim is made that a booking is ticketed unless the provider's status establishes it (`CONFIRMED` for Nuitee flights; `paid_at` paid order for Duffel).
- Flutter's existing confirmed, definitive-failure, duplicate, and price-change flows were preserved.

---

## 7. Build and test evidence

All backend commands were run from `C:\dev\TokiGo\backend`.

| # | Command | Scope | Result | Exit |
|---|---|---|---|---|
| 1 | `npx.cmd tsc -p tsconfig.json --noEmit` | production compile | no output | `0` |
| 2 | `npx.cmd tsc -p tsconfig.spec.json --noEmit` | test compile | no output | `0` |
| 3 | `npx.cmd jest --runInBand --silent test/duffel-booking.adapter.spec.ts test/duffel-passenger-composition.spec.ts test/duffel-passenger-ids.spec.ts test/provider.isolation.spec.ts test/bookings.spec.ts test/bookings.ambiguous-outcome.spec.ts test/bookings.payment-evidence.spec.ts test/bookings.price-change.spec.ts test/bookings.safety.spec.ts test/nuitee.adapter.dedup.spec.ts test/nuitee-flight-prebook.audit.spec.ts test/nuitee-flight-review-flow.spec.ts test/nuitee-flight-book.contract.spec.ts test/offers.revalidate.nuitee-flight.spec.ts` | focused regression | 14 suites passed; 185 tests passed | `0` |
| 4 | `npx.cmd jest --runInBand --silent` | full backend suite | 77 passed + 5 skipped suites (82); 890 passed + 115 skipped tests (1005) | `0` |
| 5 | `npx.cmd jest --runInBand --silent test/p4.persistence.spec.ts test/p4.schema.spec.ts test/payments.orchestration.spec.ts` | DB-gated migration/payment suites | 3 suites skipped; 111 tests skipped | `0` |
| 6 | `flutter --version` / `dart --version` | Flutter toolchain | Device Guard block | `1` |
| 7 | `git diff --check` (repo root) | whitespace hygiene | one pre-existing EOF error | `2` |

The 5 skipped suites in the full run are:

1. `p4.dev-sync.spec.ts` — requires `P4_TEST_DB_URL`;
2. `p4.persistence.spec.ts` — requires `P4_TEST_DB_URL`;
3. `p4.schema.spec.ts` — requires `P4_TEST_DB_URL`;
4. `payments.orchestration.spec.ts` — requires `P4_TEST_DB_URL`;
5. `nuitee.live-smoke.spec.ts` — requires `NUITEE_LIVE_SMOKE=1`.

They are reported as skips, not silently omitted. No live smoke was attempted.

### 7.1 What the backend tests prove

- Duffel request shaping: official payment instrument, metadata, passenger ids, confirmation derivation.
- Nuitee hotel/flight request shaping: `clientReference`, `customTags`, documented response parsing, status normalization.
- Provider isolation: no Duffel field/identifier leaks into Nuitee requests and vice versa.
- Booking-service confirmation gate: pending/unknown/mismatched provider results become `reconciliation_pending`; provider `failed` becomes `failed`; only provider-confirmed matching results confirm.
- Binding: booking id, amount, currency, price version, payment attempt id reach the adapter.
- Duplicate classification: `4005`/`45035` ambiguous; ordinary 4xx definitive.
- Existing price-change, payment-evidence, safety, and ambiguous-outcome suites remain green.

### 7.2 What the tests do **not** prove

- That migration `1731000000013` applies and satisfies `p4.schema.spec.ts` on PostgreSQL.
- That Flutter code compiles or the new widget/controller tests pass.
- That Duffel accepts the `balance` instrument on this account.
- That Nuitee accepts `ACC_CREDIT_CARD` with `usePaymentSdk: false` for this account.
- That a real provider booking reaches `CONFIRMED`, that tickets are issued, or that money moves.
- That cancellation, refund, FX, or settlement work with real providers.

---

## 8. Changed files (task-owned)

### 8.1 Backend source

| File | Change |
|---|---|
| `backend/src/common/providers/booking-provider.interface.ts` | Added binding fields, `ProviderConfirmationState`, `CreatedBooking.confirmationState`, revalidation amount text |
| `backend/src/common/providers/booking-confirmation.ts` | **New** — status normalization and provider tags |
| `backend/src/common/providers/booking-failure.ts` | Duplicate-code/transport classification (new in this work) |
| `backend/src/modules/bookings/bookings.service.ts` | Provider binding, confirmation gate, amount/currency check, reconciliation evidence, re-verified payment evidence before confirmation |
| `backend/src/modules/bookings/adapters/duffel-booking.provider.ts` | Removed empty payments; `balance` instrument, metadata, fail-closed amount/currency validation, confirmation state, ambiguous throws |
| `backend/src/modules/bookings/adapters/nuitee-booking.provider.ts` | `clientReference`, `customTags`, status-based confirmation, real amount/currency |
| `backend/src/modules/bookings/adapters/nuitee-flight-booking.provider.ts` | `customTags`, `data[0].booking`, real price, no fabricated 0 USD, status-based confirmation |
| `backend/src/modules/nuitee/nuitee.service.ts` | Forward `clientReference`/`customTags` |
| `backend/src/modules/nuitee/nuitee.flight.service.ts` | Forward `customTags`; parse documented response and journey price |
| `backend/src/modules/nuitee/nuitee.client.ts` | Include provider error code in transport error text |
| `backend/src/database/migrations/1731000000013-PaymentSecurityContainment.ts` | **New** — payment-security containment columns/index |

### 8.2 Backend tests

| File | Change |
|---|---|
| `backend/test/bookings.ambiguous-outcome.spec.ts` | Confirmation gate, binding, provider-failure, currency/amount mismatch, duplicate classification |
| `backend/test/bookings.safety.spec.ts` | Nuitee hotel binding and non-confirming `PENDING` |
| `backend/test/nuitee-flight-book.contract.spec.ts` | **New** — documented flight booking contract, response parsing, duplicate code |
| `backend/test/nuitee-flight-prebook.audit.spec.ts` | Flight binding, non-confirming `CREATED`, no invented amount |
| `backend/test/nuitee-flight-review-flow.spec.ts` | Real-party prebook lifecycle adjusted to provider-confirmed semantics and custom tags |
| `backend/test/nuitee.adapter.dedup.spec.ts` | Hotel `clientReference`/`customTags` transport contract |
| `backend/test/provider.isolation.spec.ts` | Authoritative payment inputs added to Duffel isolation cases |
| `backend/test/duffel-booking.adapter.spec.ts` | Duffel payment/metadata/confirmation expectations |
| `backend/test/offers.revalidate.nuitee-flight.spec.ts` | Still green with the new contract |

### 8.3 Flutter

| File | Change |
|---|---|
| `lib/features/booking/domain/booking_error.dart` | `bookingOutcomeUnknown` mapping and structured reconciliation detection |
| `lib/features/booking/application/booking_state.dart` | `BookingPhase.reconciliationPending` |
| `lib/features/booking/application/booking_controller.dart` | Terminal no-retry/no-revalidate guards; pending state on unknown outcome |
| `lib/features/booking/presentation/pages/checkout_page.dart` | Pending redirect, disabled pay action |
| `lib/features/search/presentation/pages/booking_review_page.dart` | Pending-verification banner and safe exit action |
| `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` | Pending-verification strings |
| `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ar.dart` | Manual additions (must be regenerated) |
| `test/booking_outcome_unknown_test.dart` | **New** — 10 tests (not executed) |

### 8.4 Phase 3C.1 work verified but pre-existing

The working tree already contained the Phase 3C.1 containment implementation before this phase. It was verified and extended, not replaced. Key files include:

- `backend/src/database/migrations/1731000000013-PaymentSecurityContainment.ts`
- `backend/src/modules/bookings/booking.entity.ts`
- `backend/src/database/entities/payment-attempt.entity.ts`
- `backend/src/modules/bookings/booking.exception.ts`
- `backend/src/modules/bookings/bookings.controller.ts`
- `backend/src/modules/bookings/bookings.module.ts`
- `backend/src/modules/admin/admin.service.ts`
- payment containment/state/guard files under `backend/src/modules/payments/`
- `backend/test/bookings.payment-evidence.spec.ts`
- Flutter booking/payment files listed in §8.3 (some also carried earlier work)

### 8.5 Files deliberately not touched

All other modified/untracked files in the 276-entry working tree are pre-existing user work. They were neither reverted nor cleaned. The existing deleted `backend/scripts/prewarm-home.js` remains as found.

---

## 9. Mock vs sandbox vs live evidence

| Capability | Documented | Implemented | Unit/mock tested | Provider sandbox | Live |
|---|---|---|---|---|---|
| Duffel instant order payment | Yes | Yes | Yes (fake Duffel service) | **No** | **No** |
| Duffel metadata binding | Yes | Yes | Yes | **No** | **No** |
| Duffel paid/awaiting confirmation semantics | Yes | Yes | Yes | **No** | **No** |
| Nuitee hotel `clientReference` idempotency | Yes | Yes | Yes (fake fetch) | **No** | **No** |
| Nuitee hotel `customTags` | Yes | Yes | Yes | **No** | **No** |
| Nuitee hotel `ACC_CREDIT_CARD` booking | Yes | Yes | Request shape only | **No** | **No** |
| Nuitee flight `prebookId` idempotency | Yes | Yes | Yes | **No** | **No** |
| Nuitee flight `data[0].booking` parsing | Yes | Yes | Yes | **No** | **No** |
| Nuitee flight duplicate `45035` | Yes | Yes | Yes | **No** | **No** |
| Provider confirmation decodes status | Yes | Yes | Yes | **No** | **No** |
| Amount/currency mismatch containment | Business rule | Yes | Yes | **No** | **No** |
| Unknown-outcome no-retry | Business rule | Yes | Yes | n/a | n/a |
| Egyptian PSP charge | Deferred | Mock only (pre-existing) | Pre-existing mock tests | **No** | **No** |

### 9.1 Actual sandbox operations

**None.** No Duffel order, Nuitee hotel booking, Nuitee flight booking, payment intent, charge, refund, or cancellation was executed against any provider sandbox in this phase.

### 9.2 Redacted sandbox responses

**None to report**, because no sandbox call was made.

### 9.3 Why no sandbox call was made

The task's stated stop condition is to stop and report when sandbox credentials or permissions are missing/unverified. The repository's `.env` was not inspected by design, so the presence, scope, and approval status of Duffel/Nuitee sandbox credentials could not be established without violating the no-`.env` constraint. Inventing or borrowing credentials was not acceptable. The provider lifecycle was therefore implemented and contract-tested with fakes, and real sandbox execution remains a separate, explicitly authorized step.

---

## 10. Blockers and stop-condition record

| # | Blocker | Impact | Status |
|---|---|---|---|
| 1 | `P4_TEST_DB_URL`/`DATABASE_URL` absent; no PostgreSQL tooling | Phase A migration and DB suites unverified | **Open** |
| 2 | Device Guard blocks `dart.exe` | Flutter tests/analyze/gen-l10n unverified | **Open — organization policy** |
| 3 | Sandbox credentials not inspected | No provider sandbox booking/payment | **Open — stop condition honored** |
| 4 | Nuitee `ACC_CREDIT_CARD`/`usePaymentSdk:false` approval unknown | Production Nuitee viability unknown | **Open** |
| 5 | Duffel balance funding/test-mode configuration unknown | Duffel instant-order viability unverified | **Open** |
| 6 | Cancellation/refund still unsupported | No customer recovery path | **Open — out of scope** |
| 7 | Reconciliation remains manual/admin-only | Ambiguous bookings require support action | **Open — out of scope** |
| 8 | Generated l10n files edited manually | Possible drift until `flutter gen-l10n` runs | **Open** |

Stop conditions honored:

- no Egyptian PSP integration;
- no production finance enablement;
- no real card data;
- no production booking/charge;
- no claim that unverified sandbox/live flows are complete.

---

## 11. Final confirmations

1. **No production financial operation occurred.** No real card, PSP, charge, authorization, capture, refund, or provider production call was made.
2. **No user change was overwritten.** The pre-existing dirty working tree was preserved; only the task-owned files in §8 were edited/created.
3. **No destructive git operation occurred.** No reset, clean, stash, checkout, restore, stage, commit, or push.
4. **No `.env` was read, printed, or modified.**
5. **The repository HEAD is unchanged** at `c972da397673467000314201dd9ff2b5469fa053`.
6. **The pre-existing `nuitee.service.ts` EOF whitespace issue remains** and was not “fixed” as part of this task.
7. **Flutter and PostgreSQL claims are explicitly limited** to static/compile evidence; they are not presented as executed tests.

---

## 12. Recommended next steps (in order)

1. **Run Phase A on an isolated PostgreSQL database:** set `P4_TEST_DB_URL` for that database only, run `p4.persistence.spec.ts`, `p4.schema.spec.ts`, and `payments.orchestration.spec.ts`, and record the applied migration list and results.
2. **Run Flutter validation on a machine/account not blocked by Device Guard:** `flutter pub get`, `flutter gen-l10n`, `flutter analyze`, and `flutter test` (including `test/booking_outcome_unknown_test.dart`).
3. **Perform an explicitly authorized sandbox validation** with already-configured official sandbox credentials:
   - one Duffel test-mode order using `balance`, verifying `paid_at` and metadata;
   - one Nuitee hotel sandbox booking with `clientReference`/`customTags`, verifying duplicate `4005` behaviour;
   - one Nuitee flight sandbox booking with `prebookId`, verifying `data[0].booking` and duplicate `45035` behaviour.
   Redact credentials, tokens, PNRs, and personal data before recording responses.
4. **Confirm commercial prerequisites with the providers:** Nuitee `usePaymentSdk:false` + `ACC_CREDIT_CARD` credit-line/CMI approval; Duffel balance funding and the pinned API version.
5. **Only then** consider the deferred Egyptian PSP integration, automatic compensation, provider cancellation, and a scheduled reconciliation worker.

---

## 13. Verdict

Phase 3C is **code-complete for the requested provider-booking and unknown-outcome safety scope**, with all backend compiles and Jest suites passing. It is **not fully verified** because:

- the PostgreSQL migration and DB suites could not run;
- Flutter tests/analyze could not run;
- no provider sandbox operation was authorized or possible.

The implemented safety posture is conservative: provider truth decides confirmation; mismatched amounts/currencies and unconfirmed statuses stay `reconciliation_pending`; ambiguous results never reopen retries; and the Flutter funnel has no path to re-book or re-charge an unknown outcome. Those properties are unit-tested at the backend boundary and statically reviewed on the client, but they are not yet proven against a real provider sandbox or PostgreSQL.
