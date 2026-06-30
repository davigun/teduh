# Design

The visual system for **Teduh**. Warm, devotional, print-dignified. This file is the single source of truth: the prototype and the Flutter `ThemeData` both derive their tokens from here.

## Direction

A finely printed Bible, reimagined for a phone held in low morning light. Ink on warm paper, a literary serif for Scripture, a quiet sans for the few controls that exist. Calm comes from paper, measure, and rhythm, not from gradients or decoration.

- **Color strategy:** Committed. A warm paper tone carries the entire surface; a single clay accent does all the work of action and "now". This is not Restrained gray-with-one-accent: the warmth *is* the brand.
- **Theme scene:** "A reader at 6am or 10pm, phone in hand in dim warm light, seeking a calm unhurried moment in Scripture." The scene forces a warm **light** default (paper), with a true **night** mode for evening and a **dusk** sepia in between. Three reading temperatures, user-chosen.
- **Anchor references (concrete, not adjectives):**
  1. A Schuyler / Cambridge goatskin-bound Bible: cream India paper, red-letter text, ribbon marker, restrained serif.
  2. iA Writer: typographic calm, focus mode, the screen as a quiet page.
  3. Apple Books / Kindle "Bookerly" sepia reading mode: warm, adjustable, content-only.

## Color

All values **OKLCH**. Never `#000`/`#fff`; every neutral is tinted warm (hue ~50–85). Three themes share one token contract; only values change.

### Theme: Pagi (Morning — default, warm light)

| Role | OKLCH | Use |
|---|---|---|
| `bg` | `oklch(0.968 0.013 83)` | App paper background |
| `surface` | `oklch(0.992 0.008 83)` | Raised sheets, cards, app bar |
| `surface-sunken` | `oklch(0.945 0.016 80)` | Insets, chapter-grid wells |
| `ink` | `oklch(0.265 0.018 50)` | Primary text + Scripture |
| `ink-secondary` | `oklch(0.460 0.020 55)` | Labels, metadata |
| `ink-muted` | `oklch(0.605 0.018 60)` | Verse numbers, captions, disabled |
| `hairline` | `oklch(0.900 0.015 80)` | Borders, dividers (1px) |
| `accent` | `oklch(0.560 0.130 42)` | Primary action, "today", selection (clay) |
| `accent-pressed` | `oklch(0.500 0.130 42)` | Pressed/active |
| `accent-wash` | `oklch(0.945 0.030 50)` | Tinted backgrounds for selected/today |
| `on-accent` | `oklch(0.985 0.010 83)` | Text/icon on clay |
| `gold` | `oklch(0.740 0.110 78)` | Streak flame, celebration accents |
| `redletter` | `oklch(0.500 0.150 26)` | Words of Christ (muted garnet) |
| `success` | `oklch(0.580 0.100 150)` | "Selesai" / read checkmark (muted sage) |

### Theme: Senja (Dusk — sepia)

`bg oklch(0.910 0.030 75)` · `surface oklch(0.935 0.026 75)` · `surface-sunken oklch(0.880 0.034 72)` · `ink oklch(0.320 0.030 48)` · `ink-secondary oklch(0.480 0.030 52)` · `ink-muted oklch(0.600 0.028 58)` · `hairline oklch(0.840 0.030 70)` · `accent oklch(0.520 0.130 40)` · `accent-wash oklch(0.880 0.040 50)` · `gold oklch(0.700 0.110 76)` · `redletter oklch(0.470 0.150 26)` · `success oklch(0.540 0.100 150)`

### Theme: Malam (Night — warm dark)

`bg oklch(0.205 0.012 60)` · `surface oklch(0.245 0.013 60)` · `surface-sunken oklch(0.175 0.010 60)` · `ink oklch(0.900 0.014 84)` · `ink-secondary oklch(0.700 0.014 70)` · `ink-muted oklch(0.560 0.014 64)` · `hairline oklch(0.320 0.012 60)` · `accent oklch(0.700 0.110 46)` · `accent-pressed oklch(0.640 0.110 46)` · `accent-wash oklch(0.290 0.030 50)` · `on-accent oklch(0.190 0.010 60)` · `gold oklch(0.780 0.100 80)` · `redletter oklch(0.680 0.130 30)` · `success oklch(0.680 0.090 152)`

All three are tuned so `ink` on `bg` and `on-accent` on `accent` clear WCAG AA (≥4.5:1 body, ≥3:1 large/UI).

## Typography

Two families, bundled as assets (offline-first, no runtime font fetch).

- **Scripture + display:** **Newsreader** (variable serif, optical sizing). Carries verse text, book titles, large numerals. Warm, literary, with true italics for poetry and footnotes.
- **UI chrome:** **Inter** (variable). Labels, buttons, nav, tabs, metadata, verse numbers.

| Token | Family / size / line-height / weight | Use |
|---|---|---|
| `display` | Newsreader · 34 / 1.15 / 500 | Book name on reader, big moments |
| `title` | Newsreader · 24 / 1.25 / 500 | Section + screen titles |
| `chapter-label` | Inter · 13 / 1.0 / 600 · tracking +0.08em uppercase | "PASAL", overlines |
| `scripture` | Newsreader · 19 / **1.72** / 400 | Verse body. The most important style. |
| `scripture-lg` | Newsreader · 21 / 1.74 / 400 | Largest reading size step |
| `verse-num` | Inter · 12 / 1 / 600 · `ink-muted`, superscript | Inline verse markers |
| `body` | Inter · 15 / 1.5 / 400 | UI prose, descriptions |
| `label` | Inter · 14 / 1.3 / 500 | Buttons, list items |
| `caption` | Inter · 12.5 / 1.4 / 500 · `ink-muted` | Metadata, helper text |

- Reading measure capped at ~68ch; on phone that's full width with 22–24px side margins.
- Reader offers a size scale (multiplier 0.9 / 1.0 / 1.15 / 1.3) applied to `scripture`.
- Type scale ratio ~1.2 for UI; scripture sizing is its own deliberate ladder.

## Spacing & Shape

- **Spacing scale (4px base):** 2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64. Vary it for rhythm; never pad everything equally.
- **Radii:** `sm 8` · `md 12` · `lg 16` · `xl 22` · `pill 999`. Buttons are pills. Sheets `xl` top corners.
- **The reading surface uses no card.** Scripture sits directly on `bg` paper, full bleed with generous margins. Cards are reserved for distinct grouped objects (today's reading card on Home, plan rows), never nested.
- **Touch targets:** ≥44px.

## Elevation

Devotional = mostly flat paper. Shadows are warm, soft, low, and rare.

- `e0` flat (reading surface, most lists).
- `e1` app bar on scroll + cards: `0 1px 2px oklch(0.4 0.03 60 / 0.06)`.
- `e2` bottom sheets + FAB: `0 8px 28px oklch(0.4 0.03 60 / 0.14)`.
- Night mode trades shadow for a 1px `hairline` lift; shadows read poorly on dark.

## Motion

Gentle, state-conveying, never decorative. Durations 160–240ms, easing **ease-out-quint** `cubic-bezier(0.22, 1, 0.36, 1)`. No bounce, no elastic.

- Chapter change: 180ms cross-fade + 8px settle, not a slide-carousel.
- Bottom sheets: 220ms ease-out.
- **The one delight:** marking a day read blooms a soft `gold`→`success` glow on the checkmark over ~600ms, and the streak count ticks up. Honors `prefers-reduced-motion` by snapping to the final state.

## Components (contract)

Each interactive component ships all states: default, hover (desktop), focus-visible, pressed, disabled, loading, selected.

- **Primary button** ("Mulai baca", "Tandai selesai"): clay pill, `on-accent` label, `accent-pressed` on press.
- **Theme toggle:** 3-segment control (Pagi / Senja / Malam) with a small sun/dusk/moon glyph.
- **Reading-size stepper:** A− / A+ in the reader settings sheet.
- **Book list / chapter grid:** chapter cells are square-ish chips on `surface-sunken`; **unavailable books** (TSI OT still rolling out) render muted with a small "segera" tag, disabled, never as a dead end.
- **Streak ring + flame:** `gold` ring around the day count; calm, not a slot machine.
- **Day checkmark:** `success` when read; this is the same atom the future "friends read today" row will reuse.
- **Empty/first-run states** teach the next action in one warm sentence, never "Tidak ada data".

## Localization

UI copy is **Bahasa Indonesia** end to end. Strings live in ARB files from day one (`l10n/`), so a second language is a data add, not a refactor. Books use Indonesian names (Kejadian, Keluaran, Mazmur, Matius, …). Numerals are Western Arabic.

## Required attribution (legal, must ship)

TSI is CC BY-SA 4.0: the app must display, in Settings → Tentang, the TSI copyright/source attribution and license, and any future modification of the *text* must stay under the same license. Treat this as a non-removable surface.
