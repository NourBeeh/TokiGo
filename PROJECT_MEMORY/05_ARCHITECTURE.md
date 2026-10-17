# TokiGo — ARCHITECTURE

## Flutter
- feature-first organization
- Riverpod state management
- GoRouter navigation
- Repository → UseCase → Controller
- reusable core theme/tokens/widgets ("Pure White Premium" — LIGHT-ONLY by user decision, 2026-09-02; dark theme removed)
- Home card engine is a stable presentation consumer

## Navigation architecture (updated 2026-09-02)
- Attached bottom bar over `StatefulShellRoute.indexedStack` — branches: Home=0, Search=1, Groups=2, Explore=3; AI centre button pushes `/ai-chat` (root route, NOT a branch).
- Seamless merged headers per page (search pages: scroll-linked collapsible SliverAppBar via `SearchScaffold`); no fixed shell header.
- Unified fade-through transitions (`core/navigation/app_transitions.dart`).
- FloatingNavigation/CommandBar/AiMorphControl were deleted (Wave 0) — do not reintroduce.

## AI boundaries
```text
features/ai/presentation
        ↓
features/ai/application
        ↓
core/ai service abstraction
        ↓
backend API
        ↓
backend AI provider abstraction
        ↓
OpenAI-compatible provider
```

## Backend
NestJS module under:
`backend/src/modules/ai/`

Core concepts:
- DTO validation
- controller
- orchestration service
- provider abstraction
- provider binding in module
- normalized response

## Contract principle
AI-specific transport/domain models remain separate from Home presentation models.
`AiHomeMapper` is the explicit bridge.

## Navigation principle
AI mode overlays the routed surface (future).
Normal mode uses the attached bottom navigation (Wave 0).
Avoid introducing a second navigation system.
