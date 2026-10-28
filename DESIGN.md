---
name: TokiGo
colors:
  background: '#FFFFFF'
  surface: '#FFFFFF'
  surface-secondary: '#FAFAFA'
  surface-tertiary: '#F5F5F5'
  ink: '#111111'
  text-primary: '#1A1A1A'
  text-secondary: '#6E6E6E'
  text-tertiary: '#9B9B9B'
  brand-red: '#FF2D2D'
  danger: '#E11D48'
  success: '#16A34A'
  warning: '#D97706'
  info: '#0284C7'
  mood-shopping: '#A75F32'
  mood-beach: '#168392'
  mood-snow: '#527B9B'
  mood-nature: '#60866B'
  mood-city: '#67559A'
typography:
  display:
    fontFamily: Manrope
    fontSize: 36px
    fontWeight: '800'
    lineHeight: 1.10
    letterSpacing: -0.6px
  headline:
    fontFamily: Manrope
    fontSize: 28px
    fontWeight: '800'
    lineHeight: 1.15
    letterSpacing: -0.5px
  title:
    fontFamily: Manrope
    fontSize: 25px
    fontWeight: '700'
    lineHeight: 1.20
    letterSpacing: -0.3px
  title-medium:
    fontFamily: Manrope
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 1.25
    letterSpacing: -0.2px
  body-large:
    fontFamily: Manrope
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 1.40
  body:
    fontFamily: Manrope
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 1.45
  caption:
    fontFamily: Manrope
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 1.30
  label:
    fontFamily: Manrope
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 1.20
  price-hero:
    fontFamily: Manrope
    fontSize: 40px
    fontWeight: '800'
    lineHeight: 1.05
    letterSpacing: -1px
rounded:
  xs: 6px
  sm: 10px
  md: 14px
  lg: 18px
  xl: 24px
  pill: 999px
spacing:
  unit: 4px
  xxs: 2px
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  xxl: 32px
  xxxl: 48px
  minimum-tap-target: 48px
---

# Design System: TokiGo

## 1. Visual Theme & Atmosphere

TokiGo is a light-only, image-led travel experience with a quiet premium
character. A pure white canvas, crisp black typography, and restrained grey
surfaces keep the interface calm and legible while destination photography
provides most of its color, atmosphere, and emotional pull. The result should
feel closer to a well-edited travel journal than a crowded booking portal:
confident editorial headings, uncluttered sections, and clear actions.

The system is deliberately near-monochrome. Black and ink carry primary
actions, navigation glyphs, ratings, and AI affordances; soft hairlines and a
two-layer shadow halo separate white surfaces without tinting the page.
Semantic colors communicate status, the red wordmark is reserved for the
brand mark, and mood hues are scoped to the mood selector rather than used as
general decoration. There is no dark theme.

## 2. Color Palette & Roles

### Primary Foundation

- **Paper White — `#FFFFFF`:** app background, cards, sheets, and primary
  surfaces. White is the default at every layer; use spacing and fine edges,
  not large tinted panels, to establish hierarchy.
- **Quiet Well — `#FAFAFA`:** inset controls, subtle selected areas, and
  secondary surfaces.
- **Soft Grey — `#F5F5F5`:** image placeholders, skeletons, disabled fills,
  and low-priority containers.
- **Hairline — `#1A1A1A` at 6% opacity:** subtle card outlines and dividers.
- **Strong Hairline — `#1A1A1A` at 12% opacity:** denser separators and
  selected/focused boundaries.

### Accent & Interactive

- **Action Ink — `#111111`:** primary buttons, active controls, brand action
  color, and AI controls. Pressed actions deepen to **Black — `#000000`**.
- **Charcoal — `#141414`:** pinned CTA bars and dark action surfaces; pair
  with white primary content and muted secondary copy.
- **Wordmark Red — `#FF2D2D`:** only the “Go” part of the TokiGo wordmark.
  Do not use it as a general CTA or page accent.
- **Mood accents —** Shopping `#A75F32`, Beach `#168392`, Snow `#527B9B`,
  Nature `#60866B`, and City `#67559A`. Keep these local to mood identity
  and mood-specific content; global service navigation remains monochrome.

### Typography & Text Hierarchy

- **Primary Ink — `#1A1A1A`:** titles, body copy, and primary values.
- **Secondary Grey — `#6E6E6E`:** explanatory text, subtitles, and hints.
- **Tertiary Grey — `#9B9B9B`:** low-emphasis labels, placeholders, and
  disabled text; avoid relying on it for essential body copy.
- **On Media — `#FFFFFF`:** copy over photographs, supported by a dark
  scrim for reliable contrast.
- **Muted On Dark — `#BFB5AC`:** secondary content in pinned charcoal CTA bars.

### Functional States

- **Success Green — `#16A34A`:** positive state and confirmations. Use the
  darker **`#15803D`** when white text sits on green; use **`#166534`** for
  text on the pale success container `#E5F6EC`.
- **Warning Amber — `#D97706`:** warning indicators. Use **`#92400E`** for
  text on the pale warning container `#FCF1E3`, or **`#B45309`** for warning
  text on white.
- **Danger Rose — `#E11D48`:** destructive states and favorite hearts; its
  container is `#FCEAEF`.
- **Information Blue — `#0284C7`:** informational status; its container is
  `#E3F2FB`.

## 3. Typography Rules

### Hierarchy & Weights

The bundled variable **Manrope** family carries Latin text. **Cairo** is its
Arabic counterpart; switch to Cairo for Arabic locale and remove Latin
letter-spacing in Arabic. Use the bundled fonts rather than substituting a
generic system face. Keep display copy editorial and bold, while body text is
open, readable, and moderately sized.

| Role | Size | Weight | Line height | Tracking |
|---|---:|---:|---:|---:|
| Display | 36px | 800 | 1.10 | -0.6px |
| Headline | 28px | 800 | 1.15 | -0.5px |
| Title | 25px | 700 | 1.20 | -0.3px |
| Medium title | 22px | 700 | 1.25 | -0.2px |
| Large body | 17px | 400 | 1.40 | normal |
| Body | 15px | 400 | 1.45 | normal |
| Caption | 13px | 400 | 1.30 | normal |
| Label | 11px | 600 | 1.20 | 0.3px |
| Price hero | 40px | 800 | 1.05 | -1px |

The supported weights are 400, 500, 600, 700, and 800. Use semibold for
emphasized body text and compact card metadata; reserve extra-bold for display
and headline roles. Prices may use the oversized price-hero role when they are
the primary decision point.

### Spacing Principles

Spacing follows a compact 4px-derived rhythm: 2, 4, 8, 12, 16, 24, 32, and
48px. Standard screen edges use 16px horizontal padding; give major sections
24–32px of separation and keep related labels and values closer together.
Interactive targets should be at least 48px wherever practical.

## 4. Component Stylings

### Buttons

Primary actions use solid action ink with white text, rounded 14px corners,
and a minimum height of 52px. Pressed states deepen toward black. Secondary
actions use a white surface with an understated outline and ink text; text-only
actions stay visually quiet. Keep service icons monochrome. Use a charcoal
bottom CTA bar for pinned price or booking actions, with a white inverted
button when an additional high-priority control is needed.

### Cards & Travel Containers

Cards are white and usually use an 18px radius, a subtle 1px hairline, and a
soft two-stop ink halo rather than a heavy shadow or tinted fill. The elevation
system increases from a tight contact shadow to a diffuse ambient shadow;
higher levels stay soft rather than looking like hard black outlines.

Travel cards are photo-forward. Destination discovery cards use a full-bleed
image, cover cropping, and a bottom scrim that carries a short city title and
optional country or provider-reported stay count. Do not add decorative
ratings, prices, or favorite actions when the underlying content cannot
support them. Hotel cards use a 4:3 photo with a white information sheet
overlapping the image by 48px; the sheet holds the property name, rating and
review count, and an end-aligned price. Keep image placeholders neutral and
avoid inventing details in loading states.

### Navigation

The Home header pairs the TokiGo wordmark with compact notification and profile
actions. Service shortcuts form a simple horizontal row of white rounded
tiles with black glyphs and clear labels. Mood navigation may use its scoped
hue, but flight, hotel, car, package, and Explore chrome remain monochrome.
Use visible back controls on pushed pages and preserve platform-native system
Back behavior; do not add custom edge-swipe dismissal.

### Inputs & Forms

The Home AI search field is a slim, white, rounded rectangle with a fine
hairline, understated halo, a one-line localized hint, and leading/trailing
actions. Keep the hint readable rather than fading it into the background;
the field may shrink its hint responsively to remain on one line. Use a
neutral inset grey for standard form fields, with an ink focus border. Arabic
fields and layouts must mirror correctly for RTL.

### Destination and Stay Cards

Use image overlays to keep destination titles legible without adding heavy
chrome. Hotel information should sit on a distinct white overlapping sheet;
ratings are neutral ink rather than gold, and favorite hearts use the semantic
rose token only when saving is a real supported action. On photography, use
white foreground text and a dark scrim, not unbacked white text over arbitrary
images.

## 5. Layout Principles

### Grid & Structure

The product is mobile-first, composed from vertically stacked sections,
horizontal discovery rails, and flexible search forms. Use constraints and
available width rather than fixed page widths. The shared logical-width
breakpoints are **480px** (compact boundary), **840px** (medium boundary), and
**1200px** (expanded layouts). Keep long-form content comfortable on wide
screens instead of stretching it edge-to-edge.

### Whitespace Strategy

Use a 16px standard page inset and the shared spacing rhythm. Let whitespace
separate editorial sections, while keeping card metadata compact. A 24px
vertical screen rhythm is a good default; use 32–48px only to distinguish
major content groups or hero transitions. Separate white surfaces with
hairlines and soft halos.

### Alignment & Visual Balance

Favor strong left-aligned editorial headings, with card content aligned to
its imagery and price values aligned to the trailing edge. Destination
photography should dominate discovery cards; text and controls should remain
short and easy to scan. Use full-width primary actions when they are the
screen's main next step. In RTL, mirror directional layouts and retain
appropriate locale-specific typography.

### Responsive Behavior & Touch

Use the compact, medium, and expanded breakpoints to adapt rails, gutters,
and form layout without changing the underlying hierarchy. Keep horizontal
rails scrollable on narrow screens, allow wider layouts to expose more cards,
and avoid fixed heights for text-heavy regions. Preserve a 48px minimum
interactive target, scalable text, semantic labels, localized copy, and
Arabic RTL support.

## 6. Design System Notes for Stitch Generation

### Language to Use

Describe TokiGo as **quiet premium travel editorial**: pure white surfaces,
near-black typography, confident oversized headings, restrained hairlines,
soft halo elevation, and vivid destination photography. Ask for a light-only
screen with generous section spacing, useful travel details, clear
provider-backed facts, and no decorative color in the global navigation.

### Color References

Use **Paper White `#FFFFFF`** for the canvas, **Action Ink `#111111`** for
primary controls, **Primary Ink `#1A1A1A`** for content, and **Secondary Grey
`#6E6E6E`** for supporting copy. Reserve **Wordmark Red `#FF2D2D`** for the
logo; apply semantic colors only to their status meanings and mood hues only
to mood identity.

### Component Prompts

- “Create a TokiGo destination rail card with a full-bleed real travel photo,
  cover crop, 18px rounded corners, a soft black bottom scrim, and a concise
  white city label. Keep the surrounding page white and omit unsupported
  ratings or prices.”
- “Design a premium hotel stay card with a 4:3 full-width photograph and a
  white information sheet overlapping it by 48px. Use an 18px radius, subtle
  ink halo, Manrope typography, neutral ink rating, and a clearly aligned
  price.”
- “Create a calm travel search screen using a white rounded input with a
  hairline border, an ink primary action, 16px page gutters, and an
  oversized editorial heading. Keep mood color limited to the selected mood
  indicator and support Arabic RTL.”

### Incremental Iteration

Start with the white canvas, heading hierarchy, and section rhythm. Add
destination photography and image scrims next, then apply card overlap and
soft halo details. Finish with interaction states, semantic colors, and
Arabic RTL. If a screen feels too colorful, remove hue from global controls
before changing the mood accents; if it feels too dense, increase section
spacing rather than adding more card decoration.
