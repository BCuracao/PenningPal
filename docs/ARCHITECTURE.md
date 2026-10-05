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
* Hive box `drafts_box` stores one document per draft (never synced). `DraftItem` (`lib/features/scratchpad/models/draft_item.dart`) is the document:
  ```dart
  class DraftItem {
    final String id; // UUID
    final String title;
    final String markdownContent;
    final DraftStatus status; // draft | ready | published
    final DateTime createdAt;
    final DateTime updatedAt;
  }
  ```
* `DraftStatus` paints a muted grey **Draft** pill, an amber/orange **Ready** pill, or a green **Published** pill.
* Schema v2 keys are `draft:<id>` maps plus `__active_id__`. A one-time migration lifts the legacy single-document keys (`id` / `content` / `updatedAt`) into a real `DraftItem`. If the box has no drafts and a `legacy_draft` string or map is present, that blob becomes the first draft so existing text is not lost.
* Titles are inferred from the first non-empty line (heading / bold / plain text, markdown tokens stripped) and fall back to `"Untitled Draft"`. Duplicating a draft stores `"[Title] (Copy)"` with the same markdown and status.
* UI updates are non-blocking: writes run asynchronously on a 400ms debounce timer against the active draft, refreshing `updatedAt` and the inferred title while keeping `status`.
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
* **Share sheet**: `ShareExportService` opens the OS share sheet. A single card is written to a temp PNG and shared as `XFile`. A carousel is compiled with `LinkedInPdfExporter` and that multi-page PDF is shared, so LinkedIn, AirDrop, Files, and messaging apps receive one document. **Save Image** still writes PNGs to Photos. **Export LinkedIn PDF** remains the Pro-gated action.
* **LinkedIn PDF Carousels**: `LinkedInPdfExporter` compiles rasterized 1:1 slides into a multi-page PDF on-device via the pure-Dart `pdf` package. Each page is `PdfPageFormat(1080, 1080, marginAll: 0)` with the PNG drawn `BoxFit.cover` so LinkedIn document posts swipe full-bleed. `CardExportService.shareLinkedInPdf` opens the native share sheet as `application/pdf`. Free users hitting **Export LinkedIn PDF** see `PaywallBottomSheet`.
* **Card Themes**: Free: **Minimal**. Pro: **Midnight**, **Terminal**, **Modern Aurora** (slate + indigo/violet blooms), **Editorial Warm** (cream paper), **Neo-Brutalist** (4px black border), and **Custom Brand** (hex / swatch / color-wheel picker). `CardCanvas` paints `backgroundGradient`, `overlayGradients`, and `resolvedBorder` from `CardThemeConfig`.
* **Photo Backdrops**: Pro users can pick a local photo (`image_picker`) as a full-bleed 1080×1080 / 1080×1920 canvas background. The file is copied into application-support `photo_backdrops/` and never uploaded. `CardCanvas` paints `ImageFiltered` Gaussian blur (`sigma` 0–30) plus a dark/light contrast scrim (`overlayOpacity` 20–85%) under the author header and markdown. `CarouselBatchExporter` precaches the file once so every carousel slide and LinkedIn PDF page reuses the same decoded image.
* **Code Cards**: Fenced markdown (` ```[lang] `) is parsed on-device into prose + code segments. `SyntaxCardBlock` paints JetBrains Mono with Atom One Dark (dark / Terminal palettes) or GitHub Light (light palettes); unknown or missing language tags fall back to plain monospace. Highlighting uses bundled `flutter_highlight` / `highlight` — no network.

### 4.4. Entitlement Gating (`lib/features/paywall/`)
* `AppConfig` holds the Apple RevenueCat public key, the Google key (empty until Play Console is linked), entitlement `pro_access`, offering id `default`, and `kDemoModeBypassPaywall` (`false` for production).
* `PaywallService` configures `purchases_flutter` with StoreKit 2, loads `Offerings.current` (falling back to the `default` offering), purchases that lifetime package, and restores. A cancelled store sheet returns without an error alert.
* `isProPurchasedProvider` is true when `pro_access` is active or demo bypass is on. `PaywallNotifier` keeps it current with `Purchases.addCustomerInfoUpdateListener`. `currentOfferingProvider` loads the localized store price.
* The paywall CTA uses `package.storeProduct.priceString` (`Unlock Lifetime Pro — €4.99`) and falls back to `Unlock Lifetime Pro — $4.99` when offerings cannot be loaded.
* While the user is not Pro: Midnight, Terminal, Aurora, Editorial, Neo-Brutal, and Custom Hex show lock badges. Tapping a locked theme, Remove Watermark, + Choose Photo, or Export LinkedIn PDF opens `PaywallBottomSheet`. `CardCanvas` forces the watermark and strips custom photos. Free accounts keep one brand profile; + Add Profile opens the paywall.
* Local StoreKit testing: `ios/PenningPalConfiguration.storekit` defines the non-consumable `pro_lifetime` at 4.99. The Runner scheme selects that file so the iOS Simulator can complete a purchase without an Apple sandbox account.

### 4.5. Scratchpad Editor (`lib/features/scratchpad/`)
* **Raw buffer invariant**: Hive still stores standard Markdown. The editor never rewrites that buffer into Unicode or HTML. Visual styling lives in the Quill document; debounced auto-save (400ms) serializes it back to Markdown before `UnicodeEngine`, `HtmlEngine`, `CardCanvas`, and `CarouselDeck` read it.
* **`markdownToDelta` / `deltaToMarkdown`** (`lib/features/scratchpad/render/markdown_quill_bridge.dart`): Bidirectional bridge. Headings, bold, italic, quotes, bullets, inline code, and fenced blocks become Quill attributes. A thematic break (`---`, `***`, `___`) becomes a `slideBreak` embed and serializes back to `---` so carousel slide counts stay stable.
* **`QuillEditor`**: The scratchpad editing surface. Users see formatted text — H1 26sp bold, H2 21sp semi-bold, body 17sp at 1.5 line height, an indented italic quote with a 3px accent rule, and an inline `── Slide Break N ──` banner. Raw `**`, `#`, `>`, and `---` are not painted.
* **`FormattingToolbar`**: Keyboard accessory above the export/status stack, wrapped in `TextFieldTapRegion` so taps keep the software keyboard up. **B**, **I**, **H** (H1 → H2 → body), **•**, **”**, **</>**, a framework button (`Icons.auto_awesome`), and **+ Slide** call Quill formatting commands. Buttons highlight while the caret sits in bold, italic, or a heading. `+ Slide` inserts the embed with haptic feedback.
* **Platform HUD**: `PlatformCounterHud` sits directly above the formatting toolbar. It shows word count, reading time (`wordCount / 200`, rounded up), and live meters for LinkedIn (3,000), X (280), and Threads (500). Green holds through 70% of a limit, amber through the limit, and red after it. Tapping a badge focuses that platform's meter. LinkedIn also flags an opening hook longer than 210 characters.
* **LinkedIn fold**: `LinkedInFoldIndicator` under the editor marks the ~210-character mobile "see more" cutoff and lists line-break indexes. It does not insert a character into the Markdown buffer.
* **Frameworks**: The toolbar opens `TemplatePickerBottomSheet` with Contrarian Hook, The 5-Step Breakdown, and The Story + Lesson. Each skeleton includes a `---` slide break. A blank draft inserts immediately. A draft that already has text asks to append or replace.
* **Draft switching**: The editor binds to `activeDraftIdProvider`. Changing the active draft flushes the 400ms debounce, replaces the Quill document from the stored Markdown, and moves the caret to the end. Keystrokes do not reload the document, so the native cursor is not reset on each save. A status pill in the app bar sets `Draft`, `Ready`, or `Published` on the open draft without reloading the document.
* **Drafts drawer**: The folder button opens a local workspace (`DraftsDrawer`) with New Draft, instant search (title or body), status chips (`All`, `Drafts`, `Ready`, `Published`), and a Settings & Profile footer. Each row shows the title, preview, status pill, relative time, and slide count. The open draft is highlighted. Swipe or the row menu can duplicate, change status, or delete; delete offers an Undo snackbar. Switching drafts flushes pending edits, then loads the selected buffer into the editor.
* **Settings sheet**: Default author profile (synced with `cardSettingsProvider`), Pro status / restore purchases, and Terms / Privacy / version. Privacy Policy and Terms of Service are bundled markdown assets under `assets/legal/` and open in `LegalDocumentViewer` — no hosted web page is required.

### 4.6. Store Identity & Release
* Display name is **PenningPal** (`MaterialApp.title`, iOS `CFBundleDisplayName` / `CFBundleName`, Android `android:label`). Package ID is `com.shoebillsoftware.penningpal` on iOS and Android.
* Launcher icons and native splash are generated from `assets/icon/` (deep slate `#0B0F19` → `#1E293B` field, geometric fountain-pen nib over a rounded card/slate) via `tool/generate_penningpal_icon.dart`, `flutter_launcher_icons`, and `flutter_native_splash`. Android adaptive icons use `icon_background.png` + `icon_foreground.png`; iOS master `app_icon.png` is opaque RGB.
* Android release builds enable R8/ProGuard (`android/app/proguard-rules.pro`) with keep rules for Hive adapters, RevenueCat, and Play Billing.