# Card System Audit — B&GO / TokiGo

**Date:** 2026-08-26
**Scope:** Home / Search / Hotels / Flights / Cars / Experiences / Deals / Packages cards
**Mode:** Read-only audit; no code changed during the audit itself. The Phase-24
card redesign (same day) is included as "current state".

## 1. Current State

Two parallel card families exist after the Phase-24 redesign:

- **Home cards** (`lib/features/home/presentation/widgets/`): 8 typed cards
  dispatched by `HomeCard` over `HomeCardType` (hotel, flight, car, package,
  destination, deal, experience, story) + shared primitives (`card_image`,
  `card_price`, `card_badge`, `card_rating`, `section_container_card`) — all
  fed by `HomeItem`.
- **Search-result cards** (`lib/features/search/presentation/widgets/`):
  `flight_result_card`, `hotel_result_card`, `car_result_card` fed by
  `BaseOffer` subclasses.
- Post-redesign state: gradient-scrim-over-image pattern on Hotel/Package/Car,
  corner pills for badge/rating, `fallbackIcon` degraded images on every
  image card, unified `CardPrice` (with scrim-legible color override), compact
  pill-style FlightCard for horizontal containers.

## 2. Inventory

| Card | File | Image | Price | Rating | Badge | Tap/Nav | Notes |
|---|---|---|---|---|---|---|---|
| HotelCard | hotel_card.dart | ✅ scrim | ✅ white | ✅ pill TR | ✅ TL | ❌ none | height 240 |
| FlightCard | flight_card.dart | avatar only | ✅ | ❌ | ❌ | ❌ none | compact 200px pill |
| CarCard | car_card.dart | ✅ scrim | ✅ | ❌ | ❌ | ❌ none | spec chips from metadata |
| PackageCard | package_card.dart | ✅ scrim | ✅ | ✅ pill | ✅ | ❌ none | sibling of HotelCard |
| DestinationCard | destination_card.dart | image-only | ❌ | ❌ | ❌ | ❌ none | |
| DealCard | deal_card.dart | ✅ top | ✅ below | ❌ | ❌ | ❌ none | minimal |
| ExperienceCard / StoryCard | own files | image-only | ❌ | ❌ | ❌ | ❌ none | minimal |
| FlightResultCard | search/widgets | ✅ | ✅ CardPrice | ❌ | ❌ | via page wrapper | |
| HotelResultCard | search/widgets | ✅ | ✅ | ❌ | ❌ | **unused** ⚠️ | see §4 |
| CarResultCard | search/widgets | ✅ | ✅ | ❌ | ❌ | via page wrapper | |

Models: `HomeItem` + `HomeCardType`(8) + `HomeSectionLayout`(4);
`BaseOffer.imageUrl: String?` present → search-result images safe without model
changes. Design tokens: `AppRadius` (xs–pill), `AppSpacing` (xxs–xxxl),
`AppColors.brand`.

## 3. UI/UX Issues

1. **No navigation on any Home card** — zero tap handlers; cards are dead ends.
2. **Wishlist is fake** — only a decorative `favorite_border` icon inside the
   search page's private `_HotelCard`; no state or persistence anywhere.
3. Rating-pill implemented with slight differences across 3 places.
4. No responsive behavior in any card widget (no LayoutBuilder/AdaptiveLayout).
5. Deal/Destination/Experience/Story are image-only — no text, no affordance.
6. Pre-existing overflow bug in the old `hotel_card.dart` Column was logged in
   `PROJECT_MEMORY/07_KNOWN_ISSUES.md`; superseded by the redesign but should
   be re-verified against demo data.

## 4. Code Duplication

- **The hotel search page uses a private `_HotelCard`** (own image stack,
  rating pill, bookmark) instead of the shared `HotelResultCard` → the shared
  widget is effectively dead code today.
- Rating pill ×3 (HotelCard, PackageCard, search `_HotelCard`).
- Gradient-scrim pattern ×4 (Hotel, Package, Car, old search `_HotelCard`).
- Price typography was duplicated (raw `Text`) in search cards before being
  unified through `CardPrice`.
- Per-page skeleton loaders (`_FlightCardSkeleton`, `_CarCardSkeleton`, …)
  instead of one shared shimmer skeleton family.

## 5. What Can Be Reused

**Production usage of the shared primitives (verified against call sites):**

- Actually consumed by feature cards today: only **`CardImage`** (+fallbackIcon),
  **`CardPrice`** (+color override), and **`CardBadge`**.
- Defined in the `core/widgets/cards` barrel but **NOT wired into any production
  card** (dead/awaiting-wiring today, tested only): `CardRating`,
  `CardAvailability`, `CardCancellation`, `CardFeatureList`, `CardLocation`,
  `CardPrimaryAction`, `CardPriceBlock` (already has strikethrough/discount),
  `CardFavorite`, and `BaseCard` (the full container with press/disabled/loading
  states). These are strong building blocks for the consolidation phase.
- `SectionContainerCard` is defined and referenced only in a doc-comment of
  `FlightCard` — it is not instantiated anywhere (Home renders sections via
  `HomeSectionWidget` instead).

So the genuinely reusable surface is `CardImage`, `CardPrice`, `CardBadge`,
the `HomeCard` dispatch pattern, and the `AppRadius/AppSpacing/AppColors`
tokens — roughly 80% of a professional system once the unwired primitives and
triplicates are consolidated.

## 6. Gaps vs a Professional Travel-Card System

- Tap/navigation contract (→ detail/booking routes).
- Real favorites service and heart toggle with persistence.
- Price formatting via `intl` (locale-aware currency symbols).
- Discount/strikethrough pricing display.
- Shared shimmer skeleton family for loading states.
- RTL mirroring checks per card variant.
- Responsive breakpoints per card layout.
- Deep-link/analytics hooks per tap.

## 7. Phased Execution Plan (approved direction)

1. **24A — Consolidation:** hotel search page adopts the shared
   `HotelResultCard` (port its richer features into it); extract shared
   `RatingPill` and scrim-footer primitives; remove triplicates.
2. **24B — Interaction contract:** optional `onTap`/`actionLabel` plumbing
   through `HomeCard` → detail route stubs; wire "View All".
3. **24C — Favorites:** FavoritesService + heart toggle on Hotel/Package
   cards with local persistence.
4. **24D — Polish:** `intl` price formatting, shared skeleton family,
   responsive breakpoints, RTL audit.
5. **24E — QA:** golden tests per card, accessibility re-audit.
