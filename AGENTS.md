# TokiGo — Project Rules

Permanent rules for any agent or developer working in this repository.
Session history and transient notes do NOT belong here — use Hermes sessions/memory.

## Architecture

- Feature-first architecture (`lib/features/<feature>/` with domain/application/presentation layers).
- Riverpod (state management) + GoRouter (navigation).
- Layering: Repository → UseCase → Controller.
- Backend: NestJS + TypeORM + PostgreSQL (`backend/`), OpenRouter AI provider, Memory Spine.
- Light-only Premium UI; Arabic/English with RTL support.

## Validation (run before declaring work done)

- Flutter: `dart analyze lib test` then `flutter test`.
- Backend: `npx tsc --noEmit` then Jest suite.

## Safety

- Never delete files or directories, ask me first and approval.
- No destructive git commands (`rm -rf`, `git reset`, `git clean`, `git stash`, `rebase`).
- No package installation without explicit approval.
- No commit/push unless explicitly requested.

## Phases

- Work in small phases; preserve all completed phases.
- Do not start another phase before completing and validating the current one.
- Do not modify Home Ranking unless the phase explicitly requires it.

## Phase 2C — Explicit AI Conversation Memory

- Explicit memories are **AI-context-only**: they must never enter
  `DerivedPreferenceProfile` or Home Ranking in 2C.
- Home Ranking stays based on the Phase 2B `DerivedPreferenceProfile`.
- The 2C explicit-memory vocabulary is ONLY:
  - `preferred_destination` — `{ destination <= 80 }`
  - `preferred_budget` — `{ min, max }`
  - `preferred_travel_style` — `{ styles <= 60 }`
- `preferred_hotel_style` is deferred to a later phase with a real consumer.
- Explicit Memory → Home Ranking integration is deferred to a future dedicated
  phase with regression testing.

## Architecture Constraints

- No ML / Vector DB / embeddings in the current architecture.
