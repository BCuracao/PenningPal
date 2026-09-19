# PenningPal — Architecture Specification

## 1. High-Level Principles
* **Pure Offline Execution**: No external network dependencies, APIs, or authentication backends.
* **Separation of Transforms**: Text engines and canvas rendering logic exist as standalone, UI-agnostic modules with dedicated unit tests.
* **Deterministic Output**: Formatting conversions must produce identical results across platforms without side effects.

---

## 2. Directory Structure

```text
lib/
├── core/                       # Pure Dart logic (zero Flutter UI dependencies)
│   ├── converter/              # Markdown token parsing & Unicode transformation
│   │   ├── unicode_engine.dart # Mathematical Alphanumeric conversion
│   │   └── html_engine.dart    # Substack/Medium rich-text formatting
│   ├── clipboard/              # Multi-MIME system clipboard writer
│   └── persistence/            # Hive box wrappers & storage schemas
├── features/
│   ├── scratchpad/             # Main drafting screen & editor controls
│   │   ├── presentation/       # Scratchpad UI, formatting bar, styled editor
│   │   └── state/              # Editor state, markdown format actions, debounce
│   ├── exporter/               # Visual carousel & quote card generator
│   │   ├── presentation/       # Card preview modal, aspect-ratio toggles
│   │   ├── render/             # Off-screen RepaintBoundary rasterizer
│   │   └── templates/          # Visual card presets (Dark, Minimal, Code)
│   └── paywall/                # RevenueCat lifetime unlock integration
└── shared/
    ├── models/                 # Shared data models (Draft, ExportConfig)
    ├── theme/                  # App typography, color tokens
    └── widgets/                # Generic buttons, bottom sheets, sliders
```

---

## 3. Core Data Flow

```text
[ User Input ]
      │
      ├──> (Debounce: 400ms) ───> [ Hive Local Store ] (Local Auto-Save)
      │
      ├──> [ Unicode Engine ] ──> [ Clipboard Writer ] ──> System Clipboard (X / LinkedIn)
      │
      ├──> [ HTML Engine ]    ──> [ super_clipboard ]   ──> System Clipboard (Substack)
      │
      └──> [ Card Exporter ]  ──> [ RepaintBoundary ]   ──> Image Rasterizer ──> Native Share / Photos / PNG Clipboard
                                                                                 └──> LinkedInPdfExporter (on-device PDF)
```

---

## 4. Module Boundaries & Responsibilities

### 4.1. Formatting Engine (`lib/core/converter/`)
* Operates strictly on raw strings.
* Does not import `package:flutter/*` (only `dart:core`).
* Maintains lookup tables for UTF-16 surrogate pairs representing Mathematical Alphanumeric Unicode symbols.
* Implements fallback rules so unsupported characters (symbols, punctuation, non-Latin alphabets) bypass conversion safely without throwing exceptions.

### 4.2. Local Storage (`lib/core/persistence/`)
* Hive box `drafts_box` stores one document per draft (never synced):
  ```dart
  class Draft {
    final String id;
    final String title;
    final String content;
    final DateTime createdAt;
    final DateTime updatedAt;
  }
  ```
* Schema v2 keys are `draft:<id>` maps plus `__active_id__`. A one-time migration lifts the legacy single-document keys (`id` / `content` / `updatedAt`) into a real `Draft` so existing buffers are not lost.
* Titles are inferred from the first non-empty line (heading / bold / plain text, markdown tokens stripped) and fall back to `"Untitled Draft"`.
* UI updates are non-blocking: writes run asynchronously on a 400ms debounce timer against the active draft.
* Author profile (name, handle, avatar shortcut) lives in a separate on-device `settings_box` and is read by `cardSettingsProvider`.
* Ghostwriter / brand personas live in `profiles_box` (`AuthorProfile`: id, name, handle, avatarPath, defaultFont, defaultThemeId). Free accounts may keep 1 profile; Pro unlocks unlimited switching. `cardSettingsProvider` selects, adds, edits, and deletes personas and stamps the active identity onto exported cards.

### 4.3. Visual Card Exporter (`lib/features/exporter/`)
* **Off-Screen Rendering**: Cards are rendered in an off-screen widget tree attached to a detached `RenderRepaintBoundary` or via an invisible overlay.
* **Canvas Output Dimensions**:
  * Square: 1080 × 1080 px
  * Vertical: 1080 × 1920 px
* **Rasterization Process**: Card widgets are scaled using `Transform.scale` to ensure consistent rendering metrics regardless of physical device DPI, rasterized to `dart:ui.Image`, and converted to PNG byte arrays.
* **Carousel Decks**: Scratchpad drafts split on markdown thematic breaks (`---`, `***`, `___`, 3+ markers) across LF / CRLF / CR. Batch export presents each slide sequentially off-screen at identical dimensions and DPI, then shares or saves every PNG together. Watermark / Pro gating is applied per slide via `isProPurchased`.
* **Rich Card Typography**: `MarkdownCardContent` paints headings, emphasis, blockquotes, lists, and inline code as widgets — raw `#` / `**` / `>` never appear on the canvas. Fenced blocks still go through `SyntaxCardBlock`. Type is sized for a 1080px canvas (H1 78px / body 38px / code 32px) then multiplied by `CardLayout.fontScaleFor` (1.35× / 1.1× / 0.95× / 0.82× by character length). Body copy is vertically centered between the author header and watermark; insets are 84×64. A FittedBox clip guard keeps long slides on-canvas; there is no 280-character tweet cap.
* **Inspect & Clipboard**: Tapping the live preview opens a full-screen `InteractiveViewer` inspect modal (pinch-zoom 0.8×–4.0×) so typography and syntax highlighting can be checked at export resolution. **Copy Card** rasterizes the visible slide and writes raw PNG bytes through `super_clipboard` (`Formats.png`) for pasting into Stories, X, LinkedIn, and messaging apps. A glassmorphism overlay reports rasterization progress (`Rendering 1080px card...` / `Preparing slide N of M...`) and blocks duplicate taps.
* **LinkedIn PDF Carousels**: `LinkedInPdfExporter` compiles rasterized 1:1 slides into a multi-page PDF on-device via the pure-Dart `pdf` package. Each page is `PdfPageFormat(1080, 1080, marginAll: 0)` with the PNG drawn `BoxFit.cover` so LinkedIn document posts swipe full-bleed. `CardExportService.shareLinkedInPdf` opens the native share sheet as `application/pdf`. Free users hitting **Export LinkedIn PDF** see `PaywallBottomSheet`.
* **Card Themes**: Free: **Minimal**. Pro: **Midnight**, **Terminal**, **Modern Aurora** (slate + indigo/violet blooms), **Editorial Warm** (cream paper), **Neo-Brutalist** (4px black border), and **Custom Brand** (hex / swatch / color-wheel picker). `CardCanvas` paints `backgroundGradient`, `overlayGradients`, and `resolvedBorder` from `CardThemeConfig`.
* **Code Cards**: Fenced markdown (` ```[lang] `) is parsed on-device into prose + code segments. `SyntaxCardBlock` paints JetBrains Mono with Atom One Dark (dark / Terminal palettes) or GitHub Light (light palettes); unknown or missing language tags fall back to plain monospace. Highlighting uses bundled `flutter_highlight` / `highlight` — no network.

### 4.4. Entitlement Gating (`lib/features/paywall/`)
* State tracked via a single reactive boolean: `isProPurchased`.
* Checks RevenueCat cache on launch (`CustomerInfo.entitlements['pro_access']?.isActive`).
* Hard enforcement: The export render pipeline intercepts attempts to rasterize custom themes or strip watermarks if `isProPurchased == false`. LinkedIn PDF export, extra brand profiles, Aurora / Editorial / Neo-Brutal / Custom Hex, and watermark removal all open `PaywallBottomSheet`.

### 4.5. Scratchpad Editor (`lib/features/scratchpad/`)
* **Raw buffer invariant**: The Hive draft and `TextEditingController.text` stay standard markdown. Visual styling never rewrites tokens into Unicode or HTML.
* **`MarkdownFormatter`**: Pure Dart wrap/toggle helpers (bold, italic, heading cycle, bullet, quote, inline vs fenced code, `\n\n---\n\n` slide breaks) with no Flutter imports.
* **`StyledMarkdownEditingController`**: Overrides `buildTextSpan` so headings, emphasis, quotes, fenced code, and thematic breaks paint live in the TextField. Syntax markers (`**`, `#`, `` ` ``) stay visible at ~35% opacity.
* **`FormattingToolbar`**: Keyboard accessory above the export/status stack. Taps apply formatter results and restore `TextSelection` so the caret never jumps. `+ Slide` inserts a carousel divider with haptic feedback.
* **Drafts drawer**: Hamburger opens a local workspace (`DraftsDrawer`) with New Post, search, swipe-to-delete (confirmation required), and a Settings & Profile footer. Switching drafts flushes the 400ms debounce, then loads the selected buffer into the editor.
* **Settings sheet**: Default author profile (synced with `cardSettingsProvider`), Pro status / restore purchases, and Terms / Privacy / version. Privacy Policy and Terms of Service are bundled markdown assets under `assets/legal/` and open in `LegalDocumentViewer` — no hosted web page is required.

### 4.6. Store Identity & Release
* Display name is **PenningPal** (`MaterialApp.title`, iOS `CFBundleDisplayName` / `CFBundleName`, Android `android:label`). Package IDs remain `com.cleancanvas.cleanCanvas` (iOS) and `com.cleancanvas.clean_canvas` (Android).
* Launcher icons and native splash are generated from `assets/icon/` (deep slate `#0B0F19` → `#1E293B` field, geometric fountain-pen nib over a rounded card/slate) via `tool/generate_penningpal_icon.dart`, `flutter_launcher_icons`, and `flutter_native_splash`. Android adaptive icons use `icon_background.png` + `icon_foreground.png`; iOS master `app_icon.png` is opaque RGB.
* Android release builds enable R8/ProGuard (`android/app/proguard-rules.pro`) with keep rules for Hive adapters, RevenueCat, and Play Billing.