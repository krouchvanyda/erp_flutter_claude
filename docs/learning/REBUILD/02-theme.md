# Step 1.2 — Theme (design tokens)

## 1. Why

Our app has many screens. If every screen writes its own colors and sizes:

```dart
Text('Hi', style: TextStyle(fontSize: 16, color: Color(0xFF1A1D23)))  // screen A
Text('Hi', style: TextStyle(fontSize: 15, color: Color(0xFF1B1D22)))  // screen B 😕
```

…then nothing matches, dark mode is impossible, and a brand color change
means editing 200 files.

**Design tokens** fix this: we name every color, size and text style **once**,
and every widget uses the names.

## 2. Picture

```
 ERP_MOBILE_DESIGN_GUIDE.md  (the designer's spec)
            │  copied once into code
            ▼
 ┌──────────────── lib/core/theme/ ─────────────────┐
 │  app_colors.dart   raw palette (#3B4FE8 …)       │
 │  app_spacing.dart  4 · 8 · 16 · 24 · 32 · 48     │   TOKENS
 │  app_radius.dart   8 · 12 · 16 · 24 · 999        │   (names for values)
 │  app_shadow.dart   card · modal                  │
 │  app_font_size.dart   11 · 12 · 14 · … · 32      │
 │  app_text_style.dart  15 theme styles + build()  │
 │  app_label.dart    AppLabel widget               │
 └───────────────────────┬──────────────────────────┘
                         │ mapped ONCE
                         ▼
 ┌──────────── app_theme.dart ──────────────┐
 │ light() ─► ThemeData(colorScheme, text…) │   THEME
 │ dark()  ─► ThemeData(colorScheme, text…) │   (Flutter's format)
 └───────────────────────┬──────────────────┘
                         │ MaterialApp(theme:, darkTheme:, themeMode:)
                         ▼
 ┌──────────── every widget ────────────────┐
 │ Theme.of(context).colorScheme.primary    │   USE
 │ Theme.of(context).textTheme.titleMedium  │
 │ AppSpacing.md · AppRadius.lg             │
 └──────────────────────────────────────────┘
```

**Two kinds of tokens:**

| Kind | Changes in dark mode? | How widgets read it |
|---|---|---|
| Colors, text colors | ✅ yes | `Theme.of(context).colorScheme.xxx` |
| Spacing, radius, font size | ❌ no | `AppSpacing.md`, `AppRadius.lg` directly |

## 3. Code

### `abstract final class` (used in every token file)

```dart
abstract final class AppSpacing {
  static const double md = 16;
}
```

- `abstract` → you can't create it: `AppSpacing()` is an error.
- `final` → nobody can `extends` or `implements` it.
- Together: a **namespace** — just a box of constants.
- (In `Environments` we used a private constructor `Environments._()` for
  the same goal. `abstract final` is the newer Dart 3 way. Both work.)

### `app_colors.dart`: the raw palette

```dart
static const Color primary = Color(0xFF3B4FE8);
static const Color surface = Color(0xFFF8F9FC); // page background
static const Color surfaceDark = Color(0xFF0F1117);
```

- `0xFF3B4FE8` = `FF` (alpha, fully visible) + `3B4FE8` (RGB).
- Light **and** dark values both live here.
- **Rule:** widgets don't import `AppColors`. Only `AppTheme` does. Widgets
  use `colorScheme`, so they work in dark mode with zero extra code.
- The guide only gives dark `surface` + `card`. The other dark values
  (`surfaceVariantDark`, …) are **our picks** — change them freely.

### `app_spacing.dart`, `app_radius.dart`, `app_shadow.dart`

Plain numbers. Spacing is always a multiple of 4, so layouts line up.

### Text: 3 files, 2 ways to style text

```
 app_font_size.dart   ── AppFontSize.value11 … value32   one size scale
        │
        ▼
 app_text_style.dart  ── AppTextStyle.build(...)  ◄── the ONE place that makes a TextStyle
        │                AppTextStyle.titleMedium …   (Inter + Khmer fallback)
        │                      │
        │                      └──► AppTheme.textTheme ──► AppBar, buttons, TextField,
        │                                                  Dialog, SnackBar, TabBar…
        ▼
 app_label.dart ────────── AppLabel(text:, fontSize: AppFontSize.value24)  your text
```

| You want… | Use |
|---|---|
| Text that Flutter draws itself (AppBar title, typed text, hints, dialogs) | nothing — `AppTheme` already did it |
| Show your own text | `AppLabel(text: …, fontSize: AppFontSize.value16)` |
| A `TextStyle` for `TextField(style:)`, `RichText` | `Theme.of(context).textTheme.bodyLarge` |

#### `app_text_style.dart`: the single builder

```dart
static TextStyle build({required double fontSize, String fontFamily = 'Inter', Color? color, ...}) {
  return GoogleFonts.getFont(fontFamily, fontSize: fontSize, color: color, ...)
      .copyWith(fontFamilyFallback: [khmerFallback]);
}
```

- `GoogleFonts.getFont('Inter')` downloads the font the first time and caches
  it. Any Google Font name works (`'Poppins'` too).
- **`fontFamilyFallback`**: Inter has no Khmer letters. When Flutter meets `ស`,
  it tries the next font in the list → Noto Sans Khmer.

```
 "Hello សួស្តី"
   H e l l o   → Inter            ✅
   ស ួ ស ្ ត ី → not in Inter → fallback → Noto Sans Khmer ✅
```

- The **15** named styles fill **every** Material `TextTheme` slot. If one slot
  is empty, Flutter uses its own default there (Roboto, **no Khmer**). For
  example a Dialog title uses `headlineSmall` and TabBar labels use
  `titleSmall`. 6 of them aren't in the design guide; they're marked
  *"our pick"* in the code.
- The named styles have **no color**. `AppTheme` adds the color per
  light/dark mode.
- They use `AppFontSize`, so the theme and `AppLabel` share one size scale.
- `static final` (not `const`): `GoogleFonts.getFont()` runs at runtime, and
  `const` needs a value known at compile time.

#### `app_label.dart`: the widget

```dart
const AppLabel(
  text: 'Welcome back',
  fontSize: AppFontSize.value24,
  fontWeight: FontWeight.w700,
)
```

- It's `Text` + `AppTextStyle.build(...)`, with handy defaults
  (`lineHeight 1.3`, `overflow: fade`, `softWrap: true`).
- **`color` is optional, and we pass it straight through (`color: color`).**
  When null, `Text` takes the color from the widget around it:

```
 on a page            → theme text color (dark / light per mode)
 inside FilledButton  → white (onPrimary)
 inside OutlinedButton→ primary blue
 inside AppBar        → AppBar foreground
```

- ⚠️ **Don't** write `color: color ?? Theme.of(context).textTheme.bodyMedium?.color`.
  That *always* sets a color, so a FilledButton label becomes dark text on
  blue. Leaving it `null` is what lets the parent decide.
- ⚠️ **Don't** build the style with a plain `TextStyle(fontFamily: 'Inter')`.
  A plain name only works if `Inter.ttf` is bundled in `assets/`; we have none,
  so Flutter silently uses the system font and loses the Khmer fallback.
  Always go through `AppTextStyle.build`.
- `AppFontSize.value24` instead of `24`: the sizes match the design scale,
  so nobody invents a `23`.

### `app_theme.dart`: tokens → Flutter `ThemeData`

```dart
static ThemeData light() => _build(_lightScheme);
static ThemeData dark()  => _build(_darkScheme);
```

**One `_build`, two color schemes.** Light and dark share all the shape rules
(radius, button height…). Only colors differ. So we can't forget to style a
button in dark mode.

```dart
static const ColorScheme _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.primary,
  surface: AppColors.surface,
  surfaceContainerLowest: AppColors.card,           // cards
  surfaceContainerHighest: AppColors.surfaceVariant, // input fill
  ...
```

The **mapping** from the design guide names to Material 3 names:

| Design guide | Material 3 `ColorScheme` | Used for |
|---|---|---|
| primary | `primary` | buttons, links |
| primaryContainer | `primaryContainer` | chip / badge background |
| surface | `surface` | page background |
| card (white) | `surfaceContainerLowest` | `Card` |
| surfaceVariant | `surfaceContainerHighest` | input fill |
| onSurface | `onSurface` | main text |
| onSurfaceVariant | `onSurfaceVariant` | secondary text |

**Dark mode is not just "dark background".** Two colors change too:

| Token | Light | Dark | Why |
|---|---|---|---|
| `primary` | `#3B4FE8` | `#7B8BFF` | `#3B4FE8` on `#0F1117` = **3.1:1** contrast. Text needs **4.5:1**. `#7B8BFF` = **6.3:1** ✅ |
| `onPrimary` | white | `#0F1117` | White on the light `#7B8BFF` = 3.0:1 ❌, dark text = 6.3:1 ✅ |
| `errorContainer` | `#FEE2E2` | `#3B1518` | A light pink box would glow in dark mode. |

```
 contrast ratio:  1:1 ── 3:1 ──── 4.5:1 ─────── 7:1 ── 21:1
                  same    big text   normal text   great   black/white
                  color   only       minimum ✅
```

```dart
final textTheme = TextTheme(
  titleMedium: AppLabel.titleMedium,
  ...
).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
```

`AppLabel` styles go into Flutter's `TextTheme` and get their color here.
Now `Theme.of(context).textTheme.titleMedium` = the right font, size, weight
**and** color for the current mode.

**Component themes** (set once, every widget gets them):

| Theme | What it does |
|---|---|
| `appBarTheme` | flat, same color as the page, left-aligned title |
| `cardTheme` | white (dark: `#1A1D23`), radius 16, no shadow |
| `filledButtonTheme` / `outlinedButtonTheme` | full width, 52px high, radius 12 |
| `inputDecorationTheme` | filled, no border at rest, 2px primary border on focus |

So in a screen you just write `FilledButton(...)` — no styling at all.

### `main.dart`: plug it in

```dart
MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  themeMode: _mode,          // light / dark / system
  ...
```

`MaterialApp` picks `theme` or `darkTheme` based on `themeMode`, and every
widget below rebuilds with the new colors.

```
 themeMode = light ──► uses theme      ──► AppTheme.light()
 themeMode = dark  ──► uses darkTheme  ──► AppTheme.dark()
 themeMode = system ─► follows the phone setting
```

The demo screen (`_ThemePreviewPage`) is **temporary**. It shows a title,
card, Khmer text, input, and buttons so you can see every token. Step 1.4
replaces it with the router.

> ⚠️ The toggle uses `setState` — fine for a throwaway demo. The real theme
> switch will be a Cubit (BLoC) saved in `shared_preferences`, because our
> rule is "BLoC owns all real state".

## 4. 🤔 Why like this? (other ways)

| Choice we made | Other way | Why we didn't pick the other way |
|---|---|---|
| Tokens in `core/theme/` | Hard-coded `Color(...)` / `16` in widgets | Nothing matches, no dark mode, a brand change means editing every file. |
| Widgets read `colorScheme` | Widgets read `AppColors.primary` | `AppColors` doesn't know light vs dark. `colorScheme` changes automatically. |
| Our own `ColorScheme(...)` | `ColorScheme.fromSeed(seedColor: …)` (the old app did this) | `fromSeed` **generates** colors, so you don't get the exact designer values (`#F8F9FC`, `#EEF0F5`…). We want the guide's exact colors. |
| Named styles fed into `TextTheme` **and** an `AppLabel` widget | Only the `AppLabel` widget | A widget can't style things that Flutter draws itself (AppBar title, button labels, `ListTile`). The `TextTheme` covers those; `AppLabel` is a shortcut for your own text. |
| `color` nullable everywhere | Default `Colors.black` | Black is invisible on the dark page `#0F1117`. |
| `AppLabel` uses `AppTextStyle.build` | `AppLabel` builds a plain `TextStyle(fontFamily: …)` | Two builders = two places to fix the font. And a plain family name doesn't load Google Fonts, so Inter + Khmer silently disappear. |
| `AppLabel` passes `color: color` (may be null) | `color ?? textTheme.bodyMedium.color` | Always setting a color stops the parent from deciding: FilledButton text turns dark on blue. |
| Fill all 15 `TextTheme` slots | Only the 9 in the design guide | Empty slots fall back to Roboto (no Khmer) in dialogs, tabs, etc. |
| A lighter `primary` in dark mode | The same `#3B4FE8` | Only 3.1:1 contrast on the dark page: blue text is hard to read. |
| Static classes for spacing/radius | `ThemeExtension<AppSpacing>` | Spacing doesn't change with dark mode, so the extension adds code for no gain. We **will** use a `ThemeExtension` later for status colors (success/warning containers) if they need dark versions. |
| `google_fonts` (download + cache) | Bundle `.ttf` files in `assets/fonts/` | Bundling works offline from the first launch, but adds ~1 MB per font + license files. `google_fonts` is simpler to learn. **Trade-off:** the very first launch needs internet, or the system font is used. We can switch to bundled files later without touching any widget. |
| One `_build(scheme)` | Two full `ThemeData(...)` blocks | Two copies drift apart: you style a button in light and forget dark. |

## 5. Try it

```bash
flutter run --flavor dev -t lib/main_dev.dart
```

You should see:
- the app bar with **ERP Dev** and a 🌙 button
- "Welcome back" in **Inter Bold 24** (every text on this page is an `AppLabel`)
- a white card with **Khmer text** rendering correctly
- a grey filled **Email** field → tap it: a **blue 2px border** appears
- a blue **Sign in** button with **white** text, and an outlined
  **Use biometrics** button with **blue** text (the `AppLabel` inherits the
  color from the button)

Tap 🌙 → everything switches to **dark**: page `#0F1117`, card `#1A1D23`,
light text, and a **lighter blue** button with **dark** text. **No widget code changed** — only the theme.

**Experiment:** in `app_colors.dart` change `primary` to `Color(0xFFE11D48)`
(red), hot reload. Every button, the focus border, and links turn red. That
is the power of tokens. (Change it back after.)

## 6. Check yourself

1. A widget needs the secondary text color. Do you write
   `AppColors.onSurfaceVariant` or `Theme.of(context).colorScheme.onSurfaceVariant`? Why?
2. Why does `AppLabel` pass `color: color` instead of `color ?? bodyMedium.color`?
3. Why is `AppTextStyle.titleMedium` `static final` and not `static const`?
4. What happens to Khmer text if we remove `fontFamilyFallback`?

<details><summary>Answers</summary>

1. `colorScheme.onSurfaceVariant` — it switches with dark mode. `AppColors`
   is always the light value.
2. `null` lets `Text` take the color from its parent: white in a
   FilledButton, blue in an OutlinedButton, the theme text color on a page.
   Always setting a color breaks button labels.
3. `GoogleFonts.getFont()` is a function that runs at runtime. `const` only
   allows values known at compile time.
4. Inter has no Khmer glyphs, so Flutter falls back to whatever the system
   picks — it may look different on each phone, or show boxes (☐).

</details>
