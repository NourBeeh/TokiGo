# Button press-feedback inventory — Pressable adoption

Scope: tappable controls across every page of the app.
Two press-feedback mechanisms, both in `lib/core/widgets/pressable.dart`:

- `Pressable` — owns the tap (`GestureDetector` + `onTap`). For bare children
  (cards, avatars, stacks) with no Material/Ink ancestor of their own.
- `Pressable.wrap` — observes the pointer only (`Listener`), never enters the
  gesture arena, so the child keeps its own tap handling. For Material buttons,
  `InkWell`, `IconButton` and other controls that already own their gesture.

Both give the same feedback: a subtle scale + opacity on press, matching
`HomeNavButtons`. No ink ripples anywhere (the theme sets
`NoSplash.splashFactory`).

## Already migrated to `Pressable` / `Pressable.wrap`

- `lib/core/ui/app_button.dart` — `AppButton` (own scale + shade + haptic).
- `lib/core/widgets/app_icon_action.dart` — `AppIconAction` (bare + disc).
- `lib/core/widgets/cards/base_card.dart` — `BaseCard` (scale + shadow drop).
- `lib/core/widgets/cards/card_primary_action.dart`, `card_favorite.dart`.
- `lib/app/widgets/home_nav_buttons.dart` — `_NavTile` (scale + colour ramp).
- `lib/app/widgets/app_bottom_nav.dart` — bottom nav items.
- `lib/features/home/presentation/pages/home_page.dart` — avatar + top action.
- `lib/features/home/presentation/widgets/home_section.dart` — "View all".
- `lib/features/profile/presentation/pages/profile_page.dart` — menu rows,
  camera edit, danger row, settings + edit icon buttons, Google sign-in.
- `lib/features/search/presentation/widgets/offer_details/offer_details_cta_bar.dart`
  — `_CtaButton`.

## Converted in this pass

**Shared search controls** (`search_scaffold.dart`) — every vertical inherits:
- `SearchFieldInput`, `SearchSegmentedControl`, `SearchStepperInput`
  (`_StepperButton`), `SearchChoiceChip`.

**Search pages & widgets**
- `search_hub_page.dart` — hero search field, hero quick links, service tiles.
- `hotel_search_page.dart` — sort sheet rows, edit-search summary bar,
  filter chip row, "Discover more" button.
- `flight_search_page.dart` — "Add leg", remove-leg icon, swap button.
- `destination_picker_sheet.dart` — clear-search icon, picker tiles.
- `search_view_toggle.dart` — list/map toggle.
- `search_states_view.dart` — `_SortChip`, `_FilterButton`.

**Profile, auth & onboarding**
- `profile_page.dart` — settings icon, edit icon, Google sign-in.
- `edit_profile_page.dart` — avatar picker, save button, date field.
- `settings_page.dart` — option rows, language/theme pickers.
- `auth_page.dart` — Google sign-in.
- `onboarding_page.dart` — skip and log-in ghost actions.

**Bag & booking funnel**
- `bag_page.dart` — trip card.
- `trip_details_page.dart` — cancel dialog actions.
- `checkout_page.dart` — payment method rows.
- `passenger_details_page.dart` — remove-traveller icon.
- `booking_confirmation_page.dart` — copy-reference control.

**Home**
- `trip_builder_page.dart` — cancel, remove-item, add-product button.
- `city_page.dart` — CTA button, photo-credit link.
- `explore_cities_page.dart` — clear-search icon.
- `flight_recommendation_list.dart` — "View all".

**Groups, AI & admin**
- `groups_page.dart` — create-group card, group card.
- `ai_memory_page.dart` — sign in, retry, dismiss, edit/delete, clear-all,
  dialog actions, save.
- `ai_chat_page.dart` — retry.
- `ai_prompt_input.dart` — send button.
- `ai_response_content.dart` — retry.
- `chat_search_widgets.dart` — dismiss.
- `admin_content_tab.dart` — section header, move up/down, delete.

## Notes

- `Pressable.wrap` is deliberately gesture-arena-free: wrapping a Material
  button (or an `IconButton` with its own `onTap`) must never swallow the tap.
  Its `enabled` flag is set false for a disabled child so it does not react to
  taps it will not handle.
- Controls needing their own colour state feedback (`HomeNavButtons`,
  `AppIconAction`, `BaseCard`, `CardFavorite`) keep their bespoke handlers.
- `flutter analyze lib` reports **0 errors**; the remaining warnings are
  pre-existing and unrelated to this change.
