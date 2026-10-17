# TokiGo — DEEPSEEK EXECUTION CONTEXT

## Project
TokiGo — Flutter travel application + NestJS backend.

## Current checkpoint (updated 2026-09-02)
Phases 1–17 are complete, PLUS the Wave workstreams W0–W3 (2026-09-02): light-only "Pure White Premium" UI with attached bottom nav (Home/Search/AI-centre/Groups/Explore) and unified fade-through motion; real providers on the backend (Nuitee hotels LIVE-verified, Duffel revalidation, MarketContext EG/EGP + FX + PricingEngine, cars rich mock, POST /offers/revalidate); search/home UI rebuild (SearchScaffold, picker sheets, rich states, DiscoveryProductCard, Continue-planning strip); booking funnel + mock payment abstraction (MockEgyptGateway, ledger, idempotency). Full record: `01_MASTER_MEMORY.md` §12.5–12.6. Next = **Phase 18 — PROJECT_MEMORY cloud sync + analytics foundation** — only when explicitly requested.

Key invariants for executors: LIGHT-ONLY theme (no dark code); AI centre button is a pushed route, NOT a shell branch (branch order Home=0/Search=1/Groups=2/Explore=3); CommandBar/FloatingNavigation/AiMorphControl are DELETED; search pages read router extras in didChangeDependencies; revalidation before payment is mandatory; provider secrets stay in backend/.env only.

## Stack
- Flutter / Dart
- Riverpod
- GoRouter
- NestJS backend
- TypeScript
- Repository → UseCase → Controller pattern

## AI pipeline
Flutter:
`AiPromptInput → AiController → AiAssistantService → backend → AiResponse → AiHomeMapper → HomeSectionWidget/HomeCard`

Backend:
`POST /ai/query → AiController → AiService → AI_PROVIDER → OpenAiAiProvider`

## Hard rules
- NO deleting files/directories.
- NO renaming files/directories unless explicitly instructed.
- NO destructive commands.
- NO new packages unless explicitly instructed.
- NO unrelated refactors.
- Preserve HomeCard/HomeSection engine.
- Preserve routing architecture.
- Never create or commit secrets/API keys.
- Work only on the requested phase.

## Validation
Flutter:
`flutter analyze`
`flutter test`

Backend:
run the repository's appropriate TypeScript validation (npx jest / tsc --noEmit).

## Reporting
At the end report:
- files created
- files modified
- exact behavior
- tests/analyze
- remaining warnings/errors
- stop at the requested phase

## Current execution boundary
Phases 1–17 + Waves W0–W3 are complete. Implement only **Phase 18 — PROJECT_MEMORY cloud sync + analytics foundation** when explicitly requested, then stop. Later phases 19+ remain listed but not started; see `08_NEXT_STEPS.md`. Keep the hard rules: no delete/rename, no secrets in code or memory, minimal scoped work.
