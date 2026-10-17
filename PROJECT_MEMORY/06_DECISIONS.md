# TokiGo — ARCHITECTURAL DECISIONS

## AI-specific models + mapper
Chosen instead of expanding HomeItem.
Reason: keep unstable AI contract separate from stable Home presentation models.

## Reuse HomeCardType/HomeSectionLayout
Chosen to keep vocabulary consistent and avoid duplicate enums.

## Mapper boundary
`AiHomeMapper` is the single bridge from AI response to Home sections.
This protects the HomeCard engine.

## Provider abstraction
Backend uses `AI_PROVIDER` so provider implementations can be swapped without changing controller/service/UI.

## OpenAI-compatible REST
Chosen for Phase 9 because no AI SDK was required and the same protocol can support compatible providers through base URL/model configuration.

## No secret in source
`AI_API_KEY` must be supplied by runtime environment. Never commit secrets.

## Phase isolation
Every phase must have explicit scope and validation.

## Decisions (2026-09-02 — Wave workstreams)

## Light-only design language ("Pure White Premium")
User explicitly removed dark mode entirely after briefly enabling it. Theme is light-only; do not add theme toggles or dark palettes without a new explicit request.

## Bottom navigation replaces floating nav + CommandBar
User chose an attached bottom bar (Home / Search / AI-centre / Groups / Explore). The AI is a raised centre button that pushes `/ai-chat` (a root route, NOT a StatefulShellRoute branch). Branch order: Home=0, Search=1, Groups=2, Explore=3 — keep in sync with `shell.dart` mappings; regression test exists (`bottom_nav_branch_mapping_test.dart`).

## Seamless headers, not a fixed shell header
The fixed top app header was removed. Every page owns a merged header that blends into its content (search pages use a scroll-linked collapsible SliverAppBar).

## Hero search card lives on the Search tab
Home shows a welcome line + discovery feed; "Where to next?" hero card moved to Search Hub by explicit user decision.

## Motion + buttons unified app-wide
One fade-through transition for all routes (`core/navigation/app_transitions.dart`); solid-minimal `AppButton` kit (primary/secondary/ghost/destructive, 3 sizes, haptic). Gradients are NOT part of the language (solid fills), except the AI violet reserved for AI surfaces.

## Typography + locale
Manrope (Latin) + Cairo (Arabic) variable fonts bundled in `assets/fonts`. `AppTypography.isArabicLocale` drives font swap; en/ar l10n via gen-l10n arb files.

## Provider layer per spec v2.0
- Nuitee = first hotel provider (LIVE-verified). ONE base URL api.liteapi.travel/v3.0 — sandbox is key-based (`sand_***`), no sandbox subdomain exists. Mapping: rates at `data[].roomTypes[].rates[]`, metadata snake_case, 10-scale rating halved for display.
- Duffel = first flight provider; revalidateOffer added; payments must NOT depend on Duffel Payments for Egypt (not supported) — spec O.2: external PSP + Duffel Balance.
- Cars vendor intentionally deferred; rich mock behind the real CarProvider contract.
- MarketContext EG/EGP/ar-EG; SA/AE prepared but disabled. Display currency separated from provider currency (spec point 5); PricingEngine deterministic with FX snapshot.
- All provider secrets backend-only (`.env`, git-ignored). Flutter never sees provider keys.

## Payment abstraction (mock-first)
MockEgyptGateway behind the PaymentGateway interface with real idempotency, signed webhooks, 3DS-pending semantics and an append-only ledger. A production PSP adapter replaces the mock without touching booking services. Revalidation before payment is mandatory (spec point 8) — Flutter booking review enforces it via `/offers/revalidate`.
