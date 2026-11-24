# Phase 3C — Payment / Booking Lifecycle Audit

**Date:** 2026-11-24  
**Status:** Audit only. No implementation, no migration, no Flutter change, no provider call.  
**Scope:** Egyptian payment gateway integration and the booking/payment lifecycle for Duffel Flights, Nuitee Flights and Nuitee Hotels.  
**Baseline:** branch `Main`, HEAD `c972da397673467000314201dd9ff2b5469fa053`.

---

## 0. Statement of no changes

This phase did not:

- create, edit or delete application source, tests, migrations or Flutter code;
- stage, commit or push anything;
- reset, clean, stash, checkout or restore the working tree;
- read or print `.env` files or credentials;
- call a live payment gateway, PSP, Duffel or Nuitee endpoint;
- change payment ordering or booking behaviour.

The only file added by this audit is this report:

`docs/phase-3c-payment-booking-lifecycle-audit.md`

The repository already contained extensive uncommitted user work before this audit. That work was preserved unchanged. The pre-existing `git diff --check` warning in `backend/src/modules/nuitee/nuitee.service.ts` was also left untouched.

---

## 1. Method and evidence

The audit used four kinds of evidence, kept separate throughout:

| Evidence class | What it means | Examples |
|---|---|---|
| **Documented** | Stated by the provider's official API documentation | Duffel instant orders require a `payments` value; Nuitee hotel `clientReference` is an idempotency key |
| **Implemented** | Present in this repository and exercised by code or tests | `MockEgyptGateway`; `POST /bookings`; Nuitee `ACC_CREDIT_CARD`; Flutter `_pay()` ordering |
| **Mocked** | Deliberately simulated, not real money or a real PSP | `MockEgyptGateway` in-memory intents; card prefix `4` means success |
| **Unverified** | Cannot be proven without a live merchant account or sandbox call | Real PSP behaviour; Nuitee credit-line approval; Duffel balance funding; FX settlement |

No live call was made. Provider behaviour below is therefore **documented or unverified**, never "verified live".

### Code and documents reviewed

- `backend/src/modules/payments/*`
- `backend/src/modules/bookings/*`
- `backend/src/modules/duffel/*`
- `backend/src/modules/nuitee/*`
- `backend/src/database/entities/payment-attempt.entity.ts`
- `backend/src/database/entities/booking.entity.ts`
- `backend/src/database/migrations/1731000000001-P4PaymentAttemptTable.ts`
- `backend/src/database/migrations/1731000000003-P4BookingPaymentColumns.ts`
- `backend/src/database/migrations/1731000000007-P4AttemptStatusStates.ts`
- `lib/features/booking/presentation/pages/checkout_page.dart`
- `lib/features/booking/application/services/checkout_payment_service.dart`
- `lib/features/booking/application/booking_controller.dart`
- `docs/p4-2-report-2026-11-09.md`
- `docs/p4-2r-report-2026-11-09.md`
- `docs/p4-2r2-report-2026-11-09.md`
- `docs/p3-d8-report-2026-11-08.md`
- Official Duffel API documentation for orders and order cancellations.
- Official Nuitee / LiteAPI documentation for hotel prebook/book/cancel/retrieve and flight prebook/book/track/cancel.

---

## 2. Baseline and repository state

| Item | Value |
|---|---|
| Branch | `Main` |
| HEAD | `c972da397673467000314201dd9ff2b5469fa053` |
| Upstream | `origin/Main` |
| Stash | none |
| Working tree | already dirty before the audit; many pre-existing modifications and untracked files |
| Pre-existing deleted file | `backend/scripts/prewarm-home.js` |
| Pre-existing untracked audit doc | `docs/p2d-p2e-report-2026-11-23.md` |
| Pre-existing `git diff --check` issue | `backend/src/modules/nuitee/nuitee.service.ts:895: new blank line at EOF.` |

`git diff --check` exits `2` because of that pre-existing blank line. It is not caused by this audit and was not modified.

The audit doc was added as a new untracked file after the baseline snapshot. No tracked source file was changed.

---

## 3. Executive summary

### 3.1 What is sound

The payment orchestration has several genuinely strong pieces:

- Durable payment attempts with user + idempotency-key uniqueness.
- A documented payment state machine with compare-and-set transitions.
- A double-entry-style customer/supplier ledger.
- Webhook HMAC verification, two replay stores (legacy + current), retryable-versus-terminal event outcomes, and an atomic effect transaction.
- Server-authoritative pricing: the client amount is a quote checked against `bookings.authoritativePrice`; the server value is what reaches the gateway.
- Booking provider calls are guarded by idempotency keys, durable provider-operation rows, and a `reconciliation_pending` state for ambiguous outcomes.
- Price-change acceptance is bound server-side to provider + offer + price + currency + terms version.

These controls are real and should be preserved.

### 3.2 What is not safe

The integration is **not a production payment system** yet. The central defect is architectural: **payment and booking are two independent workflows that are never linked at runtime**.

The Flutter client happens to call payment before booking, but the backend does not require it. `POST /bookings` accepts no payment proof and checks no payment state. `bookings.paymentAttemptId`, `bookings.paymentStatus` and `bookings.consumedAt` exist in the schema but are never written by application code. A payment can succeed without a booking, a booking can succeed without a payment, and a payment can be refunded after the booking is confirmed.

On top of that, the only Egyptian gateway registered is the in-memory mock, and it is registered unconditionally. In a production build with a strong `WEBHOOK_SIGNING_KEY`, the mock still starts and still treats a client-declared `CARD_SUCCESS` as a successful capture. If real Duffel/Nuitee credentials are present, that means **real provider bookings can be created without real money**.

### 3.3 Critical findings

| ID | Severity | Finding | Evidence | Impact |
|---|---|---|---|---|
| **C1** | Critical | The only Egyptian gateway is `MockEgyptGateway`, registered unconditionally for `EG`. | `payment.router.ts` constructs `[mockEgyptGateway]`; `payments.module.ts` always provides it; there is no `NODE_ENV` or "real PSP configured" gate. | Production can accept fake card success and create real supplier bookings. |
| **C2** | Critical | `POST /bookings` does not require or verify payment. | `CreateBookingDto` has only `bookingId`, `idempotencyKey`, `travelers`; `BookingsService.create` never reads a payment attempt. | Any authenticated user can confirm a prepared booking without paying. |
| **C3** | Critical | Payment and booking are not linked at runtime. | `bookings.paymentAttemptId`, `paymentStatus`, `consumedAt` are created by migration but never written outside tests; `bookings.service.ts` explicitly states it handles no payment. | No proof of payment, no consumption, no double-spend protection, no audit trail from booking to money. |
| **C4** | High | Duffel instant orders are created with `payments: []`. | `duffel-booking.provider.ts` calls `createOrder(..., [])`; `duffel.service.ts` sends `type: 'instant'` with that empty array. Duffel's documented instant-order contract requires an appropriate `payments` value. | Duffel orders can fail, or rely on undocumented account behaviour. The adapter test pins the empty array as expected. |
| **H1** | High | No automatic refund or void when payment succeeds but booking fails, is declined after a price change, or remains ambiguous. | `CheckoutPage._pay()` pays first, then calls `confirm()`; `BookingsService.create` has no payment/refund branch. | Customer funds can be captured with no booking and no automatic compensation. |
| **H2** | High | The payment idempotency key is not bound to the price version. | Key is `pay-${bookingId}-${method}`; `resolveExistingAttempt` validates the gateway intent against the *original attempt amount*, not the current authoritative price. | After an accepted price increase, retrying with the same key can reuse the old lower charge and then book at the higher price. |
| **H3** | High | Refund is available to any authenticated owner, not an admin or policy service. | `POST /payments/refund` is JWT-only; `refundPayment` checks ownership but not booking status. | A customer can refund after a confirmed booking, leaving a fulfilled trip unpaid. |
| **H4** | High | Nuitee hotel and flight bookings use `ACC_CREDIT_CARD` with `usePaymentSdk: false`. | Hotel: `nuitee.service.ts` sends `usePaymentSdk: false` and `payment.method: 'ACC_CREDIT_CARD'`. Flight: adapter sends `payment: { method: 'ACC_CREDIT_CARD' }`. | Documented production prerequisite: Nuitee must enable payment bypass and grant a credit line / whitelabel-CMI arrangement. If not approved, production bookings fail or are contractually invalid. |
| **H5** | Medium-High | Provider cancellation is disabled for all three flows even though the providers document cancellation. | All three adapters set `cancel: false`; `cancelBooking` returns "not supported". | No cancellation/refund path after booking; customers cannot recover money through the product. |

---

## 4. Current architecture

### 4.1 Module map

| Area | Main files | Responsibility |
|---|---|---|
| Payment gateway abstraction | `payment.gateway.ts` | `createPaymentIntent`, `confirmPayment`, `refundPayment`, `retrievePayment`, `verifyWebhook` |
| Gateway routing | `payment.router.ts` | Market → gateway; currently only `MockEgyptGateway` for `EG` |
| Mock PSP | `mock.egypt.gateway.ts` | In-memory intents, HMAC webhooks, simulated 3DS, simulated refunds |
| Payment orchestration | `payment.service.ts` | Intent, confirm, refund, webhook, ledger, ownership |
| Attempt state | `payment-attempt.state.ts` | Status vocabulary and allowed transitions |
| Attempt persistence | `payment-attempt.service.ts` | Durable claim, compare-and-set transitions |
| Ledger | `ledger.service.ts` | Customer/supplier capture/refund entries |
| Booking orchestration | `bookings.service.ts` | Prepare, revalidate, create, reconcile, cancel |
| Booking provider adapters | `bookings/adapters/*` | Duffel, Nuitee hotel, Nuitee flight |
| Flutter checkout | `checkout_page.dart`, `checkout_payment_service.dart` | Client-side ordering: revalidate → pay → confirm booking |

### 4.2 Payment gateway contract

The interface is deliberately narrow:

```ts
interface PaymentGateway {
  readonly gatewayId: string;
  readonly supportsMarket: string[];
  createPaymentIntent(input): Promise<PaymentIntent>;
  confirmPayment(input): Promise<PaymentIntent>;
  refundPayment(input): Promise<PaymentIntent>;
  retrievePayment(paymentId): Promise<PaymentIntent | null>;
  verifyWebhook(payload): boolean;
}
```

There is **no** `authorize`, `capture`, `void`, `cancel`, or `partialCapture` primitive. The model is sale-first: money is captured by `confirmPayment`, and the only reversal is `refundPayment`.

That is a fundamental constraint on the recommended sequences in §10. Either the gateway contract is extended, or the business accepts charge-first + compensate.

### 4.3 Payment attempt lifecycle

`payment-attempt.state.ts` defines:

- Active: `created`, `processing`, `requires_action`, `pending`, `unknown`
- Terminal: `declined`, `failed`, `refunded`, `partially_refunded`, `cancelled`, `consumed`, `voided`, `succeeded`

Reality check:

| State | Reachable at runtime? | Notes |
|---|---|---|
| `created` | Yes | Attempt claim |
| `processing` | Yes | Before gateway create/confirm/refund |
| `requires_action` | Yes | Intent created, customer must confirm |
| `pending` | Yes | Mock 3DS |
| `succeeded` | Yes | Mock card/wallet success or webhook settlement |
| `declined` | Yes | Mock `CARD_DECLINED` |
| `failed` | Yes | Definitive gateway failure |
| `unknown` | Yes | Ambiguous gateway failure |
| `refunded` | Yes | Refund path |
| `partially_refunded` | Yes | Partial refund path |
| `consumed` | **No** | No code consumes an attempt from the booking side |
| `voided` | **No** | No void primitive or caller |
| `cancelled` | **No** | No caller |

The state model therefore overstates the implemented lifecycle. `consumed` is the state that would prove "this payment paid this booking", and nothing reaches it.

### 4.4 Booking lifecycle

Relevant booking states observed in `bookings.service.ts`:

`prepared` → `revalidated` → `confirming` → `confirmed`  
plus `failed`, `expired`, `cancelled`, `reconciliation_pending`.

The service does not have `payment_pending`, `paid`, or `booking_pending`. It also does not read `paymentAttemptId`, `paymentStatus`, or `consumedAt`.

### 4.5 Actual runtime sequence

The Flutter checkout does this, in this order:

```text
_pay()
  │
  ├─ 1. POST /bookings/revalidate
  │      └─ provider revalidation; may return priceChanged
  │
  ├─ 2. POST /payments/intent
  │      ├─ amount = authoritativePrice + addOnsTotal
  │      ├─ market = "EG"
  │      └─ idempotencyKey = "intent-pay-{bookingId}-{method}"
  │
  ├─ 3. POST /payments/confirm
  │      ├─ methodReference derived from the card number prefix
  │      └─ idempotencyKey = "confirm-pay-{bookingId}-{method}"
  │
  └─ 4. POST /bookings
         ├─ idempotencyKey = booking-level key
         └─ no paymentAttemptId, no payment status, no proof
```

The backend enforces steps 1–3 individually, but **step 4 does not depend on step 3**. The ordering exists only in the client.

If the client is modified, replayed, or another API consumer calls `POST /bookings` directly, the payment step is skipped entirely.

---

## 5. Egyptian payment gateway audit

### 5.1 What is implemented

`MockEgyptGateway` is a deterministic simulator:

- `gatewayId = 'mock-egypt-gateway'`
- `supportsMarket = ['EG']`
- Intents live in an in-memory `Map`.
- `CARD_SUCCESS` and `WALLET` → `SUCCEEDED`.
- `CARD_3DS` → `PENDING`; `settlePending()` simulates bank completion.
- `CARD_DECLINED` → `FAILED`.
- Refund only from `SUCCEEDED`, capped at the captured amount.
- HMAC-SHA256 webhook verification over `id:paymentId`.
- `WEBHOOK_SIGNING_KEY` is mandatory; production rejects known weak values and keys shorter than 16 bytes.

Those are good mock semantics. They are still mock semantics.

### 5.2 What is not implemented

- No real Egyptian PSP adapter (no Paymob, Fawry, Accept, Geidea, Amazon Payment Services, Stripe Egypt, etc.).
- No merchant account, terminal ID, API key, HMAC secret, or settlement configuration.
- No real card tokenization; the client never sends a PAN to the backend, but the backend also never receives a PSP token.
- No real 3DS redirect/return flow. `CARD_3DS` is a boolean simulation completed by a test hook.
- No real webhook source. The only webhooks are self-signed test payloads.
- No currency/FX handling. The mock accepts any ISO code; a real Egyptian PSP may settle only in EGP.
- No PSP-side idempotency recovery by key; the mock dedupes in memory only.
- No production deployment gate. `PaymentRouter` always registers the mock.
- Partial refunds are recorded in the attempt/ledger, but the mock intent becomes fully `REFUNDED` on the first partial refund, so a second partial refund is rejected.

### 5.3 Critical deployment risk

`MockEgyptGateway` is not hidden behind a feature flag, a `NODE_ENV !== 'production'` condition, or a "real PSP present" check. The only production guard is the webhook signing key check. A production deployment with a strong `WEBHOOK_SIGNING_KEY` will start successfully and expose:

- `POST /payments/intent` → creates a fake intent.
- `POST /payments/confirm` with `methodReference: 'CARD_SUCCESS'` → marks it paid.
- `POST /bookings` → creates a real Duffel/Nuitee booking using real provider credentials.

The confirm DTO explicitly allows `CARD_SUCCESS` from the client. In the mock this is a test affordance; in production it is a self-declared payment.

**This is the highest-severity finding in the audit.** It must be closed before any production deployment, independently of the other recommendations.

### 5.4 Recommended gateway posture

Minimum production gate:

1. A real PSP adapter implements `PaymentGateway`.
2. `PaymentRouter` selects the real adapter for `EG` when configured, and fails closed (returns `null`, checkout disabled) otherwise.
3. `MockEgyptGateway` is only registered in test/development, or behind an explicit `PAYMENTS_MOCK_ENABLED=true` that is forbidden in production.
4. `CARD_SUCCESS` is never accepted as a client-supplied method in production. The client supplies a PSP token/redirect result; the backend verifies it with the PSP.
5. `WEBHOOK_SIGNING_KEY` remains mandatory and strong.
6. A startup health check refuses to boot production checkout if the PSP is unreachable or misconfigured.

---

## 6. Provider audits

### 6.1 Duffel Flights

#### Documented provider behaviour

- Duffel `orders.create` supports `type: 'instant'`.
- An instant order requires an appropriate `payments` value. Duffel documents payment instruments such as balance and card. An empty `payments` array is not a valid instant-order payment instruction.
- Duffel documents a hold / pay-later order mode that omits immediate payment and requires payment before ticketing. The exact enum/field must be confirmed against the pinned API version; this audit did not exercise it.
- Order creation accepts `metadata`, which is the practical reconciliation handle.
- No order-create idempotency-key parameter was found in the documented contract. Duffel order lookup can filter by `booking_reference` and passenger name.
- Duffel supports order cancellation and refund through its order-cancellation flow, subject to fare rules.

#### Implemented behaviour

| Item | Implementation |
|---|---|
| Order type | `type: 'instant'` |
| Payments | `payments: []` (hardcoded in the adapter) |
| Metadata | none |
| Idempotency | none at Duffel order level; the booking service has its own key and provider-operation ledger |
| Passenger mapping | Strong: resolves offer passenger IDs by type/ordinal, validates identity documents, infant links |
| Revalidation | Yes; captures live price/currency/passenger IDs into the snapshot |
| Cancellation | `bookingCapability.cancel = false`; `cancelBooking()` returns "Duffel cancellation is not supported" |
| Reconciliation | Admin-only booking reconcile with manually supplied evidence; no Duffel order lookup |

#### Gaps and risks

1. **Empty payments contradicts the instant-order contract.** This is the most concrete functional blocker. Either the adapter must send a real payment instrument, or the order must switch to hold/pay-later.
2. **No metadata.** If the order response is lost, reconciliation has no TokiGo booking/payment identifier on the Duffel side.
3. **No cancellation/refund.** Duffel supports it; the adapter does not.
4. **No order lookup on ambiguous outcome.** The adapter correctly classifies provider-call failure as `ambiguous` and the booking service blocks retries. But the only recovery is an admin manually supplying evidence; there is no `GET /orders/{id}` or search by metadata.
5. **No idempotency key.** Duffel's order create may be safely retried only with provider-side reconciliation. A blind retry can double-book.

#### Recommended Duffel payment sequence

**Preferred model: Duffel balance (or a funded Duffel payment instrument) + Egyptian PSP charge to the customer.**

1. Prepare booking; persist authoritative price/currency and offer snapshot.
2. Revalidate immediately before payment; assign a `priceVersion` to the accepted price + terms.
3. Authorize the customer through the Egyptian PSP for the exact authoritative amount (if the PSP supports authorize/capture; otherwise charge).
4. Create the Duffel instant order with:
   - `type: 'instant'`;
   - `payments: [{ type: 'balance', amount, currency }]` (or the configured Duffel instrument);
   - `metadata: { tokigo_booking_id, payment_attempt_id, price_version }`.
5. On Duffel success:
   - capture the PSP authorization (if two-step), or keep the sale;
   - persist the Duffel order id and booking reference;
   - atomically mark the payment attempt `consumed` and the booking `confirmed`.
6. On definitive Duffel failure:
   - void the authorization, or refund the sale;
   - mark the booking `failed` and the attempt `refunded`/`voided`.
7. On ambiguous Duffel failure:
   - do **not** retry order creation;
   - reconcile with Duffel by order id (if known), `metadata.tokigo_booking_id`, `booking_reference`, or passenger name;
   - then capture or refund.
8. Cancellation: use Duffel's order-cancellation quote/confirm flow; refund the customer according to the fare rules and record the supplier refund in the ledger.

**Alternative model: Duffel hold / pay-later.**

If the pinned Duffel API supports a hold order that omits `payments` at creation:

1. Create the hold.
2. Collect and authorize the customer payment.
3. Pay/ticket the hold before its deadline.
4. Capture the customer payment only after ticketing succeeds.
5. If ticketing fails, void/refund.

This is safer for the customer but adds a ticketing deadline and a second provider step. It must be verified against the exact Duffel API version before being adopted.

**Do not** keep `payments: []` as the production path. At best it is undocumented account-specific behaviour; at worst every Duffel booking fails.

---

### 6.2 Nuitee Flights

#### Documented provider behaviour

- `POST /flights/prebook` creates a prebook; `POST /flights/bookings` books it.
- Booking is idempotent by `prebookId`.
- `payment.method: 'ACC_CREDIT_CARD'` charges the agency/account card. TokiGo is merchant of record for the customer charge.
- `usePaymentSdk: false` requires Nuitee to enable payment bypass (sandbox/whitelabel) and either a credit line or a whitelabel/CMI arrangement. This is a contractual/account prerequisite, not a code toggle.
- `GET /flights/bookings/{bookingId}` retrieves/tracks a booking.
- Cancellation quote and cancellation endpoints exist, subject to fare rules.

#### Implemented behaviour

| Item | Implementation |
|---|---|
| Prebook | Yes, in revalidation; persists `prebookId` in the snapshot |
| Book | `POST /flights/bookings` with `prebookId` and `payment: { method: 'ACC_CREDIT_CARD' }` |
| `usePaymentSdk` | `false` |
| Idempotency | Provider is idempotent by `prebookId`; booking service still blocks retries on ambiguous outcomes |
| Track | `trackFlightBooking()` exists (`GET /flights/bookings/{bookingId}`) but is not used by reconciliation |
| Cancellation | `bookingCapability.cancel = false`; returns "Nuitee flight cancellation not supported" |
| Created booking amount | Returns `amount: 0`, `currency: 'USD'` |
| Payment/booking link | None |

#### Gaps and risks

1. **Production prerequisite is unverified.** `usePaymentSdk: false` + `ACC_CREDIT_CARD` is documented as requiring payment bypass and a credit line/CMI arrangement. Nothing in the repository proves TokiGo has that approval. This must be confirmed with Nuitee before production.
2. **Cancellation is supported by Nuitee but disabled in code.** No customer refund path.
3. **Track is unused.** After an ambiguous booking call, the code cannot use the provider's own booking status to resolve the outcome.
4. **Amount/currency is hardcoded to `0 USD`.** Any reconciliation or ledger that trusts the created-booking payload will be wrong. The booking's own `authoritativePrice` is the real price, but the adapter response is misleading.
5. **Ambiguous booking blocks retry even though `prebookId` is idempotent.** The provider guarantee is not exploited. A safe reconciliation could retry with the same `prebookId` or query the booking first; the current code only marks `reconciliation_pending`.
6. **No customer payment integration with the Nuitee charge.** Nuitee charges TokiGo's account card; the customer charge is a separate PSP flow with no linkage or compensation.

#### Recommended Nuitee flight payment sequence

1. Prebook with the real passenger party; persist `prebookId`, live price/currency, fare conditions and `priceVersion`.
2. Authorize (or charge) the customer through the Egyptian PSP for the authoritative amount.
3. Book with:
   - `prebookId` (the provider idempotency key);
   - `payment: { method: 'ACC_CREDIT_CARD' }`;
   - any available client reference/metadata field for TokiGo booking + payment attempt.
4. On success:
   - persist Nuitee `bookingId`, `bookingRef`, ticket numbers if returned;
   - verify ticketing status via `GET /flights/bookings/{bookingId}` before marking the booking `confirmed`;
   - capture the PSP authorization; consume the payment attempt atomically.
5. On definitive failure:
   - void/refund the customer payment;
   - mark the booking failed.
6. On ambiguous failure:
   - query `GET /flights/bookings/{bookingId}` if an id is known;
   - otherwise reconcile by `prebookId` / booking reference through Nuitee support or a documented lookup;
   - do not submit a second booking until the first is proven absent.
7. Cancellation:
   - request a cancellation quote;
   - cancel with Nuitee;
   - refund the customer according to the fare rules;
   - record the supplier refund and any penalty in the ledger.

If Nuitee cannot approve `usePaymentSdk: false` + credit line, the fallback is `usePaymentSdk: true` (customer pays Nuitee directly) or a different merchant-of-record model. That decision must be made before production.

---

### 6.3 Nuitee Hotels

#### Documented provider behaviour

- `POST /rates/prebook` creates a prebook.
- `POST /rates/book` books with `prebookId`, holder, guests and `payment.method`.
- `ACC_CREDIT_CARD` charges the agency/account card; TokiGo is merchant of record for the customer charge.
- `POST /rates/book` supports `clientReference` as an idempotency key and `customTags` for internal references.
- `GET /bookings/{bookingId}` retrieves a booking.
- `PUT /bookings/{bookingId}` cancels a booking, subject to the rate's cancellation policy.
- Hotel rates carry cancellation policies and refundability tags.

#### Implemented behaviour

| Item | Implementation |
|---|---|
| Prebook | Yes, in revalidation; persists `prebookId`, room count, cancellation data |
| Book | `POST /rates/book` with `prebookId`, holder, guests, `payment: { method: 'ACC_CREDIT_CARD' }` |
| `usePaymentSdk` | `false` |
| `clientReference` | **Not passed**, even though the service supports it |
| `customTags` | Not passed |
| Retrieval | Not used |
| Cancellation | `bookingCapability.cancel = false`; returns "Nuitee hotel cancellation not supported" |
| Payment/booking link | None |

#### Gaps and risks

1. **No `clientReference`.** The provider's idempotency key is unused. A retry after an ambiguous response can create a duplicate hotel booking.
2. **No `customTags`.** Reconciliation has no internal booking/payment identifier on the Nuitee side.
3. **No retrieval.** `GET /bookings/{bookingId}` is available but not used to resolve ambiguous outcomes.
4. **No cancellation.** Nuitee supports cancellation; the adapter does not. Customers cannot cancel or recover funds through the product.
5. **Merchant-of-record risk.** `ACC_CREDIT_CARD` charges TokiGo's account card. If the customer payment fails, is refunded, or is charged back, TokiGo carries the supplier charge. There is no compensation or credit-control flow.
6. **Cancellation policy is displayed but not enforced in the payment/refund lifecycle.** The mapper extracts refundability and policy windows; the booking/payment flow does not use them.

#### Recommended Nuitee hotel payment sequence

1. Prebook with the real guest/holder data; persist `prebookId`, live price/currency, cancellation policy and `priceVersion`.
2. Authorize (or charge) the customer through the Egyptian PSP for the authoritative amount.
3. Book with:
   - `prebookId`;
   - `clientReference = tokigoBookingId` (or `tokigoBookingId:priceVersion`);
   - `customTags: [{ name: 'tokigo_booking_id', value: bookingId }, ...]` as supported;
   - `payment: { method: 'ACC_CREDIT_CARD' }`.
4. On success:
   - persist Nuitee `bookingId`, confirmation code, status;
   - capture the PSP authorization; consume the payment attempt atomically;
   - mark the booking confirmed.
5. On definitive failure:
   - void/refund the customer payment;
   - mark the booking failed.
6. On ambiguous failure:
   - query `GET /bookings/{bookingId}` if known;
   - otherwise search/reconcile by `clientReference`;
   - do not rebook until the first booking is proven absent.
7. Cancellation:
   - retrieve the booking and its cancellation policy;
   - cancel via `PUT /bookings/{bookingId}`;
   - refund the customer according to the policy, retaining penalties;
   - record supplier and customer ledger entries.

If Nuitee cannot support `usePaymentSdk: false` + `ACC_CREDIT_CARD` for the account, the fallback is `usePaymentSdk: true` (customer pays Nuitee directly) or a different merchant-of-record model.

---

## 7. Cross-cutting lifecycle risks

### 7.1 No proof of payment on booking confirmation

`POST /bookings` is JWT-guarded and ownership-scoped, but it accepts only:

```ts
{ bookingId, idempotencyKey, travelers? }
```

It does not accept or verify a `paymentAttemptId`, amount, currency, or payment status. The service comment is explicit: "No payment, no provider credentials, no secret are handled here."

Consequences:

- A prepared booking can be confirmed without any payment.
- A payment can be made for booking A and booking B can be confirmed.
- A payment can be refunded and the booking remains confirmed.
- There is no durable `bookings.paymentAttemptId` / `consumedAt` record to audit.

### 7.2 No compensation when the post-payment step fails

The client order is payment first, booking second. The backend booking step can still fail after payment for reasons that are not the customer's fault:

- price changed between payment and booking confirmation;
- provider availability disappeared;
- provider call failed definitively;
- provider call outcome is ambiguous;
- booking expired.

In all those cases the payment attempt can remain `succeeded` with no automatic refund. The customer must discover the refund endpoint, and there is no Flutter refund UI. `POST /payments/refund` is JWT-only and not policy-gated.

### 7.3 Price-version/idempotency mismatch

The Flutter payment key is:

```text
pay-{bookingId}-{method}
```

It does not include the price, currency, or terms version. `PaymentAttemptService.claim` deduplicates on `(userId, idempotencyKey)`. On reuse, `resolveExistingAttempt` checks the gateway intent against the **stored attempt amount**, not the booking's current `authoritativePrice`.

Therefore:

1. Customer starts payment at 100.
2. Payment succeeds, but booking confirmation detects a price move to 120 and stops.
3. Customer accepts 120.
4. Checkout retries payment with the same key.
5. Backend returns the original 100 attempt; the gateway idempotency returns the original 100 success.
6. Booking confirmation now succeeds at 120 because the 120 acceptance is recorded.
7. Customer paid 100 for a 120 booking.

This is a real underpayment path. The same pattern can occur if the intent was created at 100 but not confirmed, then the price moved to 120 before the retry.

### 7.4 Expiry is stored but not enforced

`bookings.expiresAt` is persisted and refreshed on revalidation. It is not checked before:

- creating a payment intent;
- confirming a payment;
- confirming a booking;
- consuming a payment.

A payment can be created or confirmed for an expired booking. `createPayment` blocks `confirmed`, `confirming`, and `reconciliation_pending`, but not `expired` or `cancelled`.

### 7.5 Refund authorization

`POST /payments/refund` is JWT-guarded. `refundPayment` verifies that the attempt belongs to the caller and that `bookingId` matches the attempt's booking. It does **not** verify:

- that the booking is cancelled or failed;
- that the caller is an admin or support agent;
- that a refund policy allows the refund;
- that the booking is not already fulfilled.

A customer can refund a confirmed booking. There is no admin role on the endpoint.

Refund amount is capped per request at the original captured amount, but there is no cumulative refunded-total check. A real PSP would reject an over-refund, but the orchestrator should track the remaining refundable balance itself.

### 7.6 Reconciliation is manual and incomplete

The booking reconcile endpoint is admin-only and requires manually supplied evidence. There is no scheduled worker that:

- retries `retryable` webhook events;
- resolves `unknown` payment attempts;
- resolves `reconciliation_pending` bookings;
- refunds succeeded payments without confirmed bookings;
- expires stale attempts;
- checks provider booking status.

The webhook handler itself is robust, but it depends on an external delivery and an in-memory mock gateway that loses intents on restart.

### 7.7 Currency and FX

The mock gateway accepts any ISO currency. Duffel and Nuitee prices may be USD, EUR, or another provider currency. An Egyptian PSP may settle only in EGP or may apply its own FX spread. There is no:

- FX quote/lock;
- EGP conversion record;
- settlement reconciliation between PSP amount and provider amount;
- handling of PSP fees or FX differences in the ledger.

This is unverified and must be resolved with the chosen PSP before production.

### 7.8 Mock gateway state is in-memory

`MockEgyptGateway` stores intents and idempotency results in `Map`s. On process restart:

- `retrievePayment()` returns `null`;
- `resolveExistingAttempt()` returns `UNAVAILABLE`;
- webhooks become `retryable` with `payment_not_found` forever;
- a succeeded payment cannot be re-read.

A real PSP adapter must use the PSP as the source of truth and support retrieval by payment id and idempotency key.

### 7.9 Crash windows in money-moving calls

Three recovery gaps exist even with a real PSP:

- **Intent created, attempt not updated.** `createPayment` transitions the attempt to `processing`, calls the gateway, then writes `gatewayRef` and `requires_action`. If the process dies between the gateway call and the write, the attempt has no `gatewayRef`. A retry returns `PENDING` and never re-calls the gateway, even though the gateway's idempotency key could return the original intent.
- **Payment confirmed, attempt not updated.** `confirmPayment` transitions to `processing`, calls the gateway, then writes `succeeded` and the ledger. If the process dies between the gateway success and the DB write, the attempt stays `processing`. A retry cannot transition `processing → processing`, so it returns `PENDING`; there is no worker to retrieve the gateway state.
- **Refund executed, attempt not updated.** `refundPayment` transitions to `processing`, calls the gateway, then writes `refunded`/`partially_refunded` and the ledger. The same crash window can leave a completed refund recorded as `processing`.

These windows can strand a real capture or refund. A real PSP webhook may eventually resolve them, but that is not guaranteed, and the mock has no webhook for direct card success or refund.

### 7.10 Add-ons and the server-authoritative amount

The checkout computes:

```dart
total = liveRecord.authoritativePrice + addOnsTotal
```

The backend compares the client quote to `bookings.authoritativePrice` only and rejects a mismatch. Today `checkoutAddOnsProvider` is always empty because the add-ons page deliberately offers no fabricated extras. If add-ons are reintroduced, every payment with a non-zero add-on total will be rejected as a pricing mismatch. This is currently latent, not active.

### 7.11 Mock card routing

Flutter maps a card number starting with `4` to `method: 'card'` (which becomes `CARD_SUCCESS`), and every other card to `card_3ds`. This is a demo convention, not a real card-brand or 3DS decision. It is acceptable only while the mock gateway is explicitly non-production.

---

## 8. Severity-ranked risk register

| Rank | ID | Severity | Risk | Recommended disposition |
|---:|---|---|---|---|
| 1 | C1 | Critical | Mock gateway active in production can create real bookings without real money | Block production until a real PSP adapter and a fail-closed router exist |
| 2 | C2 | Critical | `POST /bookings` accepts unpaid bookings | Require and verify a consumed payment attempt in the same transaction |
| 3 | C3 | Critical | No runtime payment↔booking link | Write `paymentAttemptId`, `paymentStatus`, `consumedAt`; enforce uniqueness |
| 4 | C4 | High | Duffel instant order sends `payments: []` | Send a funded Duffel instrument or switch to hold/pay-later |
| 5 | H1 | High | Captured funds stranded when booking fails | Automatic void/refund + reconciliation worker |
| 6 | H2 | High | Price-increase retry can underpay | Bind idempotency key and attempt to a price version; reject stale reuse |
| 7 | H3 | High | Customer can refund a fulfilled booking | Admin/policy-gated refunds; booking-state checks |
| 8 | H4 | High | Nuitee `ACC_CREDIT_CARD` production prerequisite unverified | Confirm bypass + credit line/CMI with Nuitee; otherwise change model |
| 9 | H5 | Medium-High | Provider cancellation disabled | Implement provider cancellation + customer refund |
| 10 | M1 | Medium | Booking expiry not enforced before payment/confirm | Check `expiresAt` at every money/booking transition |
| 11 | M2 | Medium | Mock intents lost on restart | Real PSP persistence; retrieval by id/key |
| 12 | M3 | Medium | Crash windows strand `processing` attempts | Recovery worker + idempotent re-create/retrieve |
| 13 | M4 | Medium | Nuitee flight created booking returns `0 USD` | Return real amount/currency or omit the field |
| 14 | M5 | Medium | No `clientReference`/`metadata` on Nuitee hotel/Duffel | Add provider-side reconciliation handles |
| 15 | M6 | Medium | Reconciliation is manual and has no worker | Scheduled reconciliation/outbox |
| 16 | M7 | Medium | Mock card-prefix routing | Remove from production path with the mock |
| 17 | L1 | Low | Add-ons would be rejected by server pricing | Include add-ons in the authoritative price or reject at the UI |
| 18 | L2 | Low | `consumed`/`voided`/`cancelled` unreachable | Either implement or narrow the state model |

---

## 9. Documented vs implemented vs mocked vs unverified

| Capability | Documented | Implemented | Mocked | Unverified |
|---|---|---|---|---|
| Egyptian PSP charge | Depends on chosen PSP | No real PSP | `MockEgyptGateway` | Merchant account, 3DS, settlement, FX |
| Payment intent | Generic | Yes | In-memory | Real PSP intent lifecycle |
| Payment confirm | Generic | Yes | `CARD_SUCCESS`/`CARD_3DS`/`CARD_DECLINED` | Real token/3DS verification |
| Refund | Generic | Yes, JWT-only | In-memory | PSP refund timing/fees |
| Webhook verification | HMAC | Yes, HMAC-SHA256 | Self-signed test payloads | Real PSP signature scheme |
| Payment↔booking linkage | Required for a safe system | **No** | n/a | n/a |
| Booking proof of payment | Required for a safe system | **No** | n/a | n/a |
| Payment consumption | Entity/migration only | **No** | n/a | n/a |
| Duffel instant order payment | Required | **No** (`payments: []`) | n/a | Duffel account behaviour |
| Duffel hold/pay-later | Documented | **No** | n/a | Exact API version/fields |
| Duffel metadata | Supported | **No** | n/a | n/a |
| Duffel cancellation/refund | Supported | **No** | n/a | Fare-specific behaviour |
| Nuitee hotel book | Supported | Yes | No | Account approval |
| Nuitee hotel `clientReference` | Supported | **No** | n/a | n/a |
| Nuitee hotel cancel/retrieve | Supported | **No** | n/a | Rate-specific policy |
| Nuitee flight prebook/book | Supported | Yes | No | Account approval |
| Nuitee flight `prebookId` idempotency | Supported | Provider call only; retry blocked | n/a | Ambiguous-outcome lookup |
| Nuitee flight track | Supported | Method exists, unused | n/a | Ticketing status semantics |
| Nuitee flight cancel/refund | Supported | **No** | n/a | Fare-specific behaviour |
| `ACC_CREDIT_CARD` merchant-of-record | Supported with prerequisites | Yes | No | Credit line / bypass approval |
| Provider reconciliation | Provider APIs exist | Admin-only manual | n/a | Real lookup behaviour |
| Expiry enforcement | Business requirement | **No** | n/a | n/a |
| Automatic compensation | Business requirement | **No** | n/a | n/a |
| Scheduled reconciliation | Business requirement | **No** | n/a | n/a |

---

## 10. Recommended target design and provider sequences

This section is a recommendation, not an implementation. It is deliberately provider-specific and keeps the existing strengths (durable attempts, idempotency, webhook replay protection, server-authoritative pricing).

### 10.0 Provider sequence summary

| Provider | Supplier charge model | Customer charge | Provider call | On success | On failure |
|---|---|---|---|---|---|
| Duffel Flights | Duffel balance or funded Duffel instrument | Egyptian PSP authorize/capture (or sale) | Instant order with real `payments` + `metadata` | Capture PSP, consume attempt, persist order id | Void/refund; reconcile by order lookup/metadata; never blind-retry |
| Nuitee Flights | Agency card `ACC_CREDIT_CARD` | Egyptian PSP authorize/capture (or sale) | Book by `prebookId` | Track ticket, capture PSP, consume attempt | Void/refund; track by `bookingId`; do not rebook until proven absent |
| Nuitee Hotels | Agency card `ACC_CREDIT_CARD` | Egyptian PSP authorize/capture (or sale) | Book with `clientReference` + `customTags` | Capture PSP, consume attempt, persist booking id | Void/refund; retrieve by id/`clientReference`; do not rebook until proven absent |

If the chosen PSP has no authorize/capture, every row becomes sale-first + refund compensation, with the reconciliation worker in §10.7 as a hard requirement.

### 10.1 Common payment/booking saga

Introduce one backend-owned orchestration path that owns both sides. The client should not be the only thing enforcing order.

Suggested booking states:

```text
prepared
  → revalidated
  → payment_pending
  → paid
  → confirming
  → confirmed
  → failed | reconciliation_pending | cancelled | expired
```

Suggested attempt states:

```text
created → requires_action → processing → succeeded → consumed
                              ├→ declined (terminal)
                              ├→ failed (terminal)
                              └→ unknown → reconciliation
succeeded → refunded | partially_refunded | voided
```

Atomic consumption (the missing link):

```text
BEGIN;
  UPDATE payment_attempts
     SET status = 'consumed', "consumedAt" = now()
   WHERE id = :attemptId
     AND "userId" = :userId
     AND "bookingId" = :bookingId
     AND status = 'succeeded'
     AND amount = :authoritativePrice
     AND currency = :authoritativeCurrency
     AND "consumedAt" IS NULL;

  UPDATE bookings
     SET "paymentAttemptId" = :attemptId,
         "paymentStatus" = 'paid',
         status = 'confirming'
   WHERE id = :bookingId
     AND "userId" = :userId
     AND "paymentAttemptId" IS NULL
     AND status IN ('prepared', 'revalidated');
COMMIT;
```

Both updates must be conditional and transactional. The existing unique partial index on `bookings.paymentAttemptId` is the backstop against two bookings consuming one payment.

Then call the provider. On success, mark `confirmed`. On definitive failure, refund/void and mark `failed`. On ambiguous failure, mark `reconciliation_pending` and let a worker resolve it.

### 10.2 Price-version binding

Add a `priceVersion` (or an equivalent immutable fingerprint) to the booking:

```text
priceVersion = hash(providerId, offerId, price, currency, termsVersion, acceptedAt)
```

Store it on the payment attempt and include it in the payment idempotency key:

```text
intent-pay-{bookingId}-{priceVersion}-{method}
confirm-pay-{bookingId}-{priceVersion}-{method}
```

On reuse, compare the attempt's `priceVersion` to the booking's current `priceVersion`. If they differ, reject with `price_changed`; require a new payment or an explicit top-up. Never reuse an old lower amount for a newly accepted higher price.

### 10.3 Duffel sequence

1. Prepare + revalidate; lock `priceVersion`.
2. Authorize the customer through the Egyptian PSP.
3. Create the Duffel instant order with a real `payments` instrument and `metadata`.
4. Capture the PSP authorization after Duffel success.
5. Persist the Duffel order id/reference; consume the payment attempt.
6. On failure, void/refund; on ambiguity, reconcile by Duffel order lookup/metadata.
7. Use Duffel order cancellations for post-booking cancellation/refund.

If Duffel hold/pay-later is available and verified, prefer: hold → collect customer payment → ticket → capture. This avoids capturing the customer before the supplier confirms.

### 10.4 Nuitee flight sequence

1. Prebook; lock `priceVersion` and persist `prebookId`.
2. Authorize the customer through the Egyptian PSP.
3. Book with `prebookId` + `ACC_CREDIT_CARD`; add any available client reference.
4. Verify ticketing via `GET /flights/bookings/{bookingId}`.
5. Capture and consume the payment attempt.
6. On failure, void/refund; on ambiguity, track the booking before any retry.
7. Implement cancellation quote/cancel and customer refunds.

Confirm Nuitee's `usePaymentSdk: false` + credit-line/CMI approval before production. If it is not available, switch to `usePaymentSdk: true` or change the merchant-of-record model.

### 10.5 Nuitee hotel sequence

1. Prebook; lock `priceVersion` and persist `prebookId` + cancellation policy.
2. Authorize the customer through the Egyptian PSP.
3. Book with `prebookId`, `clientReference = bookingId`, `customTags`, and `ACC_CREDIT_CARD`.
4. Capture and consume the payment attempt; persist the Nuitee booking id/confirmation.
5. On failure, void/refund; on ambiguity, retrieve by booking id or `clientReference`.
6. Implement cancellation via `PUT /bookings/{bookingId}` and refund by policy.

### 10.6 Gateway adapter requirements

Before production, the PSP adapter should support:

- `authorize`, `capture`, `void`, `refund` (including partial), `retrieve`;
- idempotency keys on every money-moving call;
- 3DS2/SCA and tokenization;
- webhook signature verification and replay protection;
- retrieval by PSP payment id and by merchant idempotency key;
- EGP and provider-currency handling, or a documented FX/settlement model;
- a startup/health check that fails closed when misconfigured.

If the chosen PSP cannot authorize/capture, the business must explicitly accept sale-first + refund compensation, with a reconciliation worker and a refund SLA.

### 10.7 Reconciliation worker

Add a scheduled/outbox worker that:

- resolves `unknown` payment attempts by `retrievePayment`;
- resolves `processing` attempts older than a threshold;
- resolves `reconciliation_pending` bookings by provider lookup;
- refunds succeeded payments that have no confirmed booking after a grace period;
- expires stale bookings and refunds any captured payment;
- retries `retryable` webhook events;
- records every resolution in the ledger and audit trail.

Without this worker, every ambiguous outcome becomes a manual support ticket.

---

## 11. Test evidence

Tests were run against the existing code without modifying source. No live provider or gateway call was made.

### 11.1 Payment/booking safety batch

Command (from `backend/`):

```text
npx.cmd jest --runInBand test/payments.orchestration.spec.ts test/payments.state-machine.spec.ts test/payments.booking-outcome.spec.ts test/payments.guards.spec.ts test/bookings.ambiguous-outcome.spec.ts test/bookings.safety.spec.ts test/duffel-booking.adapter.spec.ts test/nuitee-flight-prebook.audit.spec.ts test/p0.webhook.signing.spec.ts
```

Result:

```text
Test Suites: 1 skipped, 8 passed, 8 of 9 total
Tests:       8 skipped, 86 passed, 94 total
EXIT_CODE=0
```

The skipped suite is `payments.orchestration.spec.ts`; it requires `P4_TEST_DB_URL` and uses `describe.skip` when it is unset.

### 11.2 Provider/price-change batch

Command (from `backend/`):

```text
npx.cmd jest --runInBand test/payments.duffel.dto.spec.ts test/nuitee.adapter.dedup.spec.ts test/nuitee-flight-review-flow.spec.ts test/bookings.spec.ts test/bookings.price-change.spec.ts test/offers.revalidate.nuitee-flight.spec.ts test/offers.revalidate.duffel-flight.spec.ts
```

Result:

```text
Test Suites: 7 passed, 7 total
Tests:       94 passed, 94 total
EXIT_CODE=0
```

### 11.3 What the tests do and do not prove

They prove:

- the payment state machine's transition rules;
- ownership and idempotency guards;
- booking ambiguous-outcome safety;
- price-change detection and acceptance;
- Duffel/Nuitee adapter request shaping;
- webhook signature/replay behaviour;
- the existing Flutter/backend contract in the tested paths.

They do **not** prove:

- a real PSP charge, 3DS, settlement, refund, or webhook;
- Duffel order creation with a real payment instrument;
- Nuitee account approval for `ACC_CREDIT_CARD` / `usePaymentSdk: false`;
- provider cancellation/refund;
- production reconciliation;
- FX/settlement correctness.

`duffel-booking.adapter.spec.ts` currently expects `payments` to equal `[]`. That test pins the implementation, not the documented Duffel requirement. It should be revisited with the implementation, not treated as evidence that the empty array is valid.

---

## 12. Open questions and unverified items

These require a merchant account, provider approval, or a live sandbox before they can be answered:

1. Which Egyptian PSP is the intended production provider, and does it support authorize/capture/void, 3DS2, tokenization, partial refunds and EGP settlement?
2. Does the chosen PSP support the provider currencies (USD/EUR) or require FX conversion? Who bears the FX risk?
3. Does TokiGo have Nuitee approval for `usePaymentSdk: false` plus a credit line or whitelabel/CMI arrangement?
4. Does the Duffel account have a funded balance or a valid stored payment instrument for instant orders?
5. Which Duffel API version is pinned, and does it support hold/pay-later in the form described?
6. Can Nuitee flights be looked up by `prebookId` after an ambiguous book call, or only by `bookingId`?
7. What are the real cancellation/refund timelines and fees for each provider?
8. What is the business policy for refunds after a confirmed booking, and who is authorized to issue them?
9. What is the acceptable grace period before a succeeded payment without a booking is auto-refunded?
10. Is there a production deployment control outside this repository that disables the mock gateway? None was found in the code.

---

## 13. Recommendation and approval gate

### 13.1 Recommendation

Do not treat the current checkout as production-ready for real money.

The minimum safe sequence is:

1. **Close C1 first.** A real Egyptian PSP adapter must replace the mock for `EG`, and the router must fail closed when it is not configured.
2. **Close C2/C3 next.** `POST /bookings` must require a succeeded, unconsumed payment attempt that matches the booking's user, amount, currency and price version; consumption must be atomic with the booking transition.
3. **Fix C4.** Duffel must send a real payment instrument, or move to a verified hold/pay-later flow.
4. **Add compensation.** Any captured payment whose booking fails, expires, or remains ambiguous must be voided/refunded by a worker, not by the customer.
5. **Bind price version.** Reject stale idempotency reuse after a price change.
6. **Gate refunds.** Make refunds admin/policy-driven, not a customer self-service endpoint.
7. **Implement provider cancellation/refund** for Duffel, Nuitee flight and Nuitee hotel.
8. **Verify Nuitee and Duffel account prerequisites** before enabling production traffic.
9. **Add reconciliation and expiry enforcement.**
10. **Re-run the full test suite** after implementation, including the DB-backed orchestration suite with `P4_TEST_DB_URL`.

### 13.2 Approval gate

This phase stops here. No code, migration, configuration or Flutter change has been made.

Awaiting explicit approval before:

- selecting/implementing a PSP adapter;
- changing the booking/payment contract;
- adding payment consumption or reconciliation;
- changing provider payment/cancellation behaviour;
- adding migrations or tests.

---

## 14. Final Git verification

| Check | Result |
|---|---|
| Branch / HEAD | `Main` / `c972da397673467000314201dd9ff2b5469fa053` |
| Source files modified by this audit | none |
| Files added by this audit | `docs/phase-3c-payment-booking-lifecycle-audit.md` |
| `git diff --check` | exit `2`, pre-existing `backend/src/modules/nuitee/nuitee.service.ts:895: new blank line at EOF.` |
| Staging / commits / pushes | none |
| Live provider or gateway calls | none |
| `.env` or credentials read/printed | none |

The pre-existing dirty tree and the pre-existing whitespace warning remain exactly as found.
