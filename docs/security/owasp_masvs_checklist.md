# P4 — OWASP MASVS Audit Framework (9A)

Status: STRUCTURE CREATED (audit execution deferred until 9A).

## MASVS Categories mapped to TokiGo

### 1. Architecture & Design (MASVS-ARCH)
- [ ] Provider abstraction boundary verified (`BookingProviderRegistry` / `ProviderRegistryImpl`).
- [ ] No direct client→supplier calls (client uses backend `/search/*` and `/bookings/*` only).
- [ ] Market context (`MarketContextService`) does NOT select provider (separate routing layer).

### 2. Data Storage (MASVS-STORAGE)
- [ ] Hive boxes (`wishlist`, `settings`, `trip`) never store secrets.
- [ ] JWT access token stored in secure storage (`flutter_secure_storage`) — verified.
- [ ] No `.env` or provider keys in Flutter source.

### 3. Cryptography (MASVS-CRYPTO)
- [ ] `crypto` package used only for idempotency key generation, never for keys.
- [ ] Provider API keys (`NUITEE_API_KEY`, `DUFFEL_ACCESS_TOKEN`) never transmitted to client.

### 4. Authentication & Authorization (MASVS-AUTH)
- [ ] JWT guard (`JwtAuthGuard`) on all `/bookings/*` endpoints.
- [ ] User derived from token (`req.user`), never from unverified client input.

### 5. Network Communication (MASVS-NETWORK)
- [ ] `https://api.liteapi.travel/v3.0` and `https://book.liteapi.travel/v3.0` used (TLS enforced).
- [ ] `public` endpoints (`/search/*`) have no auth; `bookings/*` guarded.

### 6. Platform Interaction (MASVS-PLATFORM)
- [ ] Android `adb reverse tcp:3000 tcp:3000` only for dev; production uses live public URL.
- [ ] No background AI execution; event-driven only.

### 7. Code Quality & Security (MASVS-RESILIENCE)
- [ ] `dart fix --apply` applied; no unawaited futures in `ApiResult.when`; no raw colors.
- [ ] Design gates (`test/core/theme/design_gates_test.dart`) enforced.
- [ ] `integration_test/app_test.dart` exists (`P3` complete).

### 8. Provider-Specific Checks
- [ ] Nuitee adapter (`nuitee-booking.provider`) revalidates before commit (`revalidateBooking`).
- [ ] Nuitee flight adapter (`nuitee-flight-booking.provider`) registered and sandbox-only.
- [ ] Duffel adapter (`duffel-booking.provider`) kept intact (not deleted).
- [ ] No real API key in Flutter/repo (`.env` gitignored); `MASTER_PLAN.md` confirms.

Status: STRUCTURE READY. Execution of full audit (test + fix cycle) deferred to phase 9A.
