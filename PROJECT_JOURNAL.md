# PenningPal — Project Journal

## Active State
- **Current Phase**: Phase 4 — Brand kits, curated font pairings, and CTA QR codes (complete). Lifetime paywall gating from Task 4.4 still applies.
- **Official name**: **PenningPal** (rebranded from working titles Clean Canvas / SocialSlate). User-facing strings, native display names, watermarks, and legal copy use PenningPal. Package ID is `com.shoebillsoftware.penningpal` on iOS and Android. The Dart package name is `penningpal`.
- **Current Blocker**: Google Play RevenueCat public key is still empty. Create `pro_lifetime` in App Store Connect / Play Console and attach it to the `default` offering and `pro_access` entitlement before store shipping. Simulator purchases use `ios/PenningPalConfiguration.storekit`.
- **Target Stack**: Flutter (latest stable), State: Riverpod or Signals, Clipboard: `super_clipboard`, Storage: Hive / SharedPrefs
- **Git Remote**: `origin` → https://github.com/BCuracao/PenningPal (`main`, public). Working tree tracks `origin/main`. GitHub redirects the former `BCuracao/SocialSlate` URL.

## Architectural Decision Records (ADRs)
* **ADR-001 (Engine Separation)**: All Markdown-to-Unicode and Markdown-to-HTML transformers must reside in `lib/core/converter/` as pure Dart libraries without Flutter UI framework imports.
* **ADR-002 (Local Persistence)**: User scratchpad auto-saves on every debounce (400ms) locally via Hive. Multiple drafts live in `drafts_box`; no sync engine needed.
* **ADR-003 (IAP Provider)**: RevenueCat SDK will manage StoreKit and Google Play Billing for the single $4.99 non-consumable product ID (`pro_lifetime`).

## Development Roadmap
- [x] Task 1.1: Initialize Flutter project skeleton and modular directory tree.
- [x] Task 1.2: Implement `UnicodeConverter` with unit tests covering Latin-1, numerals, and nested markdown.
- [x] Task 1.3: Implement `HtmlClipboardService` with dual MIME-type support (`text/html`, `text/plain`).
- [x] Task 2.1: Build minimal markdown scratchpad UI with word/character count indicators.
- [x] Task 2.2: Add one-tap platform export actions (LinkedIn, X, Substack).
- [x] Task 2.3: Implement visual keyboard formatting toolbar and real-time styled text controller.
- [x] Task 2.4: Implement Multi-Draft Drawer, auto-titling, and App Settings.
- [x] Phase 2: Multi-draft Hive engine, drawer UI, status tags, search & duplicate.
- [x] Task 2.5: Upgrade Scratchpad to true WYSIWYG rich-text editor with zero visible Markdown tokens.
- [x] Task 3.1: Implement `CardExportCanvas` with 1:1 and 9:16 aspect ratio templates.
- [x] Task 3.2: Implement image save to gallery (`image_gallery_saver` or native share sheet).
- [x] Task 3.4: Implement Multi-Slide Carousel splitting, pagination badges, and batch export.
- [x] Task 3.5: Implement on-device syntax highlighting for code cards and terminal templates.
- [x] Task 3.6: Implement rich Markdown card rendering, auto-scaling typography, and hardened carousel splitting.
- [x] Task 3.7: Implement Copy Image to Clipboard via super_clipboard and interactive pinch-to-zoom inspect.
- [x] Task 3.8: Implement LinkedIn Multi-Page PDF Carousel export, new card theme presets, and multi-profile brand switcher.
- [x] Task 3.9: Implement custom photo backgrounds with Gaussian blur and contrast scrim sliders.
- [x] Task 4.1: Integrate RevenueCat lifetime paywall gate.
- [x] Task 4.2: Configure App branding (SocialSlate), offline legal pages, launcher icons, and release ProGuard rules.
- [x] Task 4.3: Generate and configure PenningPal 1024x1024 launcher icons and adaptive assets.
- [x] Task 4.4: Production RevenueCat StoreKit 2 integration, dynamic localized price, strict Pro gating, and local StoreKit configuration.
- [x] Phase 1: Platform character HUD, LinkedIn fold warning, framework templates, and native share sheet.
- [x] Phase 3: Specialized slide roles (Cover/Body/CTA), auto-fit font scaling, and thumbnail drag-and-drop reorder strip.
- [x] Phase 4: Curated Google Font pairings, reusable Brand Kits, and CTA QR code generator.

## Session Log
<!-- Agents append timestamped summaries of completed work here -->

### 2026-09-18 — Task 1.1: Flutter skeleton & modular tree
- Created Flutter project (`clean_canvas`, org `com.cleancanvas`) in workspace root.
- Added packages: `flutter_riverpod`, `super_clipboard`, `hive`, `hive_flutter`, `google_fonts`; dev: `build_runner`, `hive_generator`.
- Replaced counter boilerplate with `ProviderScope` → `CleanCanvasApp` → placeholder `ScratchpadScreen`.
- Created dirs: `lib/core/{converter,clipboard,persistence}`, `lib/features/{scratchpad/{presentation,state},exporter/{presentation,render,templates},paywall}`, `lib/shared/{models,theme,widgets}`, `test/core/`.
- Placeholder files: `unicode_engine.dart`, `html_engine.dart`, `clipboard_service.dart`, `draft_storage.dart`, `unicode_engine_test.dart`.
- `flutter analyze` clean; widget smoke test updated.

### 2026-09-18 — Task 1.2: UnicodeEngine + unit tests
- Implemented pure Dart `UnicodeEngine.convertForSocial` in `lib/core/converter/unicode_engine.dart` (no `package:flutter/*`; dart:core only).
- Scalar mappings via `String.fromCharCodes`:
  - Bold: A–Z `U+1D400`–`U+1D419`, a–z `U+1D41A`–`U+1D433`, 0–9 `U+1D7CE`–`U+1D7D7`
  - Italic: A–Z `U+1D434`–`U+1D44D`, a–z `U+1D44E`–`U+1D467` (small `h` → `U+210E`)
  - Bold italic: A–Z `U+1D468`–`U+1D481`, a–z `U+1D482`–`U+1D49B`
  - Monospace: A–Z `U+1D670`–`U+1D689`, a–z `U+1D68A`–`U+1D6A3`, 0–9 `U+1D7F6`–`U+1D7FF`
- Parser: `***`/`___`, `**`/`__`, `*`/`_`, inline `` `code` ``, line-start `- `/`* ` → `• `, `#`/`##`/`###` headers stripped + bolded; unmatched markers left intact; punctuation/emoji/non-Latin/accented Latin pass through; UTF-16 surrogates preserved.
- Soft-break expansion (`\n` → `\n\n`) when `preserveLineBreaks` is true; nested mixed emphasis combines to bold italic.
- Tests: `test/core/unicode_engine_test.dart` — 34 cases; `flutter test test/core/unicode_engine_test.dart` all passed; `flutter analyze` clean.
- Modified: `lib/core/converter/unicode_engine.dart`, `test/core/unicode_engine_test.dart`, `PROJECT_JOURNAL.md`.
- Follow-up: Task 1.3 `HtmlClipboardService` dual MIME write.

### 2026-09-18 — Task 1.3: HtmlEngine + dual MIME clipboard
- Implemented pure Dart `HtmlEngine` in `lib/core/converter/html_engine.dart` (no `package:flutter/*`; dart:core only).
  - `markdownToHtml`: `#`/`##`/`###` → `<h1>`–`<h3>`; `***`/`___` → `<strong><em>`; `**`/`__` → `<strong>`; `*`/`_` → `<em>`; `` `code` `` → `<code>`; fenced blocks → `<pre><code>`; `> ` → `<blockquote>`; `- `/`* ` lists → `<ul><li>`; paragraphs with in-block `\n` → `<br/>`.
  - `markdownToPlain`: strips markdown tokens for the `text/plain` clipboard fallback (headings, emphasis, fences, list markers, blockquote prefixes).
  - HTML-escapes `&`, `<`, `>` in prose and code; unmatched markers left intact; snake_case `_` not treated as italic.
- Implemented `ClipboardService` in `lib/core/clipboard/clipboard_service.dart` via `super_clipboard`:
  - `copyPlainText` writes `Formats.plainText` on a `DataWriterItem`.
  - `copyRichText` writes `Formats.htmlText` + `Formats.plainText` on a single `DataWriterItem` through `SystemClipboard.instance?.write`.
  - Falls back to `Clipboard.setData` when the native clipboard is unavailable (test harness / unsupported desktop).
- Tests: `test/core/html_engine_test.dart` — 36 cases covering headings, inline/mixed formatting, lists, code, blockquotes, escaping, dual-payload integrity; `flutter test test/core/html_engine_test.dart` all passed; `flutter analyze` clean.
- Modified: `lib/core/converter/html_engine.dart`, `lib/core/clipboard/clipboard_service.dart`, `test/core/html_engine_test.dart`, `PROJECT_JOURNAL.md`.
- Follow-up: Task 2.1 scratchpad UI with word/character counts.

### 2026-09-18 — Task 2.1: Scratchpad UI + Hive auto-save
- Implemented `DraftStorage` in `lib/core/persistence/draft_storage.dart`:
  - Hive box `drafts_box` opened via `init()` (`Hive.initFlutter`) from `main.dart`.
  - Stores active draft `content` (`String`) and `updatedAt` (`DateTime`) plus id `active`.
  - API: `saveDraft`, `loadDraft`, `clearDraft` (plus `loadUpdatedAt` / `loadActiveDraft`).
  - In-memory fallback when `init()` is skipped so unit tests need no plugin binding.
- State: `ScratchpadState` (`content`, `wordCount`, `charCount`, `estimatedReadMinutes`, `isSaving`) with pure stats helpers (whitespace/punctuation word split; ~200 wpm ceil).
- Riverpod `Notifier` `scratchpadProvider` loads the persisted draft on launch; `updateContent` refreshes stats immediately and debounces Hive writes at 400ms; pending text is flushed on dispose.
- UI: `ScratchpadScreen` — Inter typography, expanding multiline `TextField`, bottom status bar (`N words` · `N chars` · `N min read` · `Saved`/`Saving...`).
- Root: `main.dart` initializes Hive before `runApp`, wraps `ScratchpadScreen` in `ProviderScope` with a Hive-backed `draftStorageProvider` override; Material 3 paper canvas theme.
- Tests: `test/features/scratchpad_state_test.dart` — word/char/read-time, notifier updates, 400ms debounce coalescing, Hive round-trip, widget input → live counters. `flutter test` 87 passed; `flutter analyze lib test` clean.
- Modified: `lib/core/persistence/draft_storage.dart`, `lib/features/scratchpad/state/scratchpad_state.dart`, `lib/features/scratchpad/state/scratchpad_notifier.dart`, `lib/features/scratchpad/presentation/scratchpad_screen.dart`, `lib/main.dart`, `test/features/scratchpad_state_test.dart`, `test/widget_test.dart`, `PROJECT_JOURNAL.md`.
- Follow-up: Task 2.2 one-tap platform export actions (LinkedIn, X, Substack).

### 2026-09-18 — Task 2.2: One-tap platform export actions
- Added `PlatformExporter` in `lib/features/scratchpad/presentation/export_actions.dart`: in-memory conversion only (never writes back to the scratchpad / Hive buffer).
  - LinkedIn / X / Threads → `UnicodeEngine.convertForSocial` + `ClipboardService.copyPlainText` (`• ` bullets, hard line breaks).
  - Substack / Medium → `HtmlEngine.markdownToHtml` + `markdownToPlain` via `ClipboardService.copyRichText` (dual MIME).
  - Empty/whitespace drafts return `false` and skip clipboard writes.
- UI: `ExportToolbar` docked above the status bar on `ScratchpadScreen` (`resizeToAvoidBottomInset: true` so it rides the keyboard).
  - LinkedIn and Substack copy in one tap; X / Threads opens a modal sheet with 280 / 500 limits (amber when over).
  - Light haptic on every copy; floating SnackBar ("Copied formatted text for LinkedIn!", "Copied rich text for Substack & Medium!", plus X / Threads variants).
  - Card / Carousel opens placeholder `CardExporterScreen`.
- Tests: `test/features/export_actions_test.dart` — exporter unit cases + widget taps (LinkedIn, X, Threads, Substack, empty draft, card navigation, X-limit amber). `flutter test` 98 passed; `flutter analyze lib test` clean.
- Modified: `lib/features/scratchpad/presentation/export_actions.dart`, `lib/features/scratchpad/presentation/export_toolbar.dart`, `lib/features/scratchpad/presentation/scratchpad_screen.dart`, `lib/features/exporter/presentation/card_exporter_screen.dart`, `test/features/export_actions_test.dart`, `PROJECT_JOURNAL.md`.
- Follow-up: Task 3.1 `CardExportCanvas` with 1:1 and 9:16 templates.

### 2026-09-18 — Task 3.1: Card exporter canvas + rasterizer
- Implemented `CardThemeConfig` / `CardPresets` in `lib/features/exporter/templates/card_theme_config.dart`.
  - Fixed social canvases: 1:1 Square `1080×1080`, 9:16 Story `1080×1920`.
  - Presets: **Minimal Clean** (`#F8F9FA`, charcoal `#1F2937`, accent border), **Midnight Dark** (`#0F172A` → `#1E293B` gradient, `#F8FAFC` type), **Dev Terminal** (`#1E1E1E`, JetBrains Mono, macOS traffic-light chrome, light syntax coloring).
  - `showWatermark` defaults to `true` (`Made with Clean Canvas`); `copyWith` ready for the Pro strip-watermark gate.
- `CardCanvas` is a stateless presentation widget (`text`, `author`, `theme`, `aspectRatio`) wrapped in `RepaintBoundary(key: canvasKey)`. Body text auto-sizes with max-line fade so long drafts never overflow the canvas.
- `CardRasterizer.capturePng` snapshots the boundary at a fixed `pixelRatio: 3.0` (device-DPI independent), waits on `debugNeedsPaint` in debug, encodes PNG bytes. Preview uses `FittedBox` so the 1080px canvas fits mobile viewports without changing layout metrics.
- `CardExporterScreen`: live scaled preview, 1:1 / 9:16 segmented control, template carousel, character meter + overflow warning, **Export Card** action (bytes held for Task 3.2 share/save).
- `ExportToolbar` Card action pushes `CardExporterScreen(text: currentDraft)` — draft buffer is never mutated.
- Tests: `test/features/card_rasterizer_test.dart` (presets, dimensions, canvas overflow, watermark, PNG signature, exporter UI). `flutter test` 116 passed; `flutter analyze lib test` clean.
- Modified: `lib/features/exporter/templates/card_theme_config.dart`, `lib/features/exporter/presentation/card_canvas.dart`, `lib/features/exporter/render/card_rasterizer.dart`, `lib/features/exporter/presentation/card_exporter_screen.dart`, `lib/features/scratchpad/presentation/export_toolbar.dart`, `test/features/card_rasterizer_test.dart`, `test/features/export_actions_test.dart`, `PROJECT_JOURNAL.md`.
- Follow-up: Task 3.2 save PNG to gallery / native share sheet.

### 2026-09-18 — Task 3.2: Gallery save + native share sheet
- Added `share_plus` ^12.0.1, `path_provider` ^2.1.5, `gal` ^2.3.2. All file IO stays on-device (temp cache or Camera Roll); no cloud upload.
- `CardExportService` in `lib/features/exporter/render/card_export_service.dart`:
  - `saveImageTemporarily` writes PNG bytes to `getTemporaryDirectory()`.
  - `saveToGallery` uses `gal` (`putImageBytes` + album `Clean Canvas`), requests Photos access, and returns `false` on denial/errors instead of throwing.
  - `shareCardImage` writes a temp PNG then opens the system share sheet (`SharePlus.instance.share` / `ShareParams.files`, equivalent to `Share.shareXFiles`).
  - Filename helpers: timestamped `clean_canvas_YYYYMMDD_HHMMSS.png`, path/illegal-character sanitization, PNG-signature validation.
- Platform entries:
  - iOS `Info.plist`: `NSPhotoLibraryAddUsageDescription` (+ `NSPhotoLibraryUsageDescription` for album writes).
  - Android `AndroidManifest.xml`: `WRITE_EXTERNAL_STORAGE` `maxSdkVersion=29` (required through Android 10 / API 29), `requestLegacyExternalStorage`, `SEND` image query for the share sheet.
- UI: `CardExporterScreen` action bar — **Teilen** (haptic on success) and **In Fotos sichern** (snackbar „In Fotos gespeichert“); both buttons disable with a spinner while rasterizing.
- Tests: `test/features/card_export_service_test.dart` — filename generation, empty/invalid buffers, permission denial, share/save widget taps. `flutter test` 131 passed; `flutter analyze lib test` clean.
- Modified: `pubspec.yaml`, `lib/features/exporter/render/card_export_service.dart`, `lib/features/exporter/presentation/card_exporter_screen.dart`, `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`, `test/features/card_export_service_test.dart`, `test/features/card_rasterizer_test.dart`, `test/features/export_actions_test.dart`, `PROJECT_JOURNAL.md`.
- Follow-up: Task 4.1 Integrate RevenueCat lifetime paywall gate.

### 2026-09-18 — Task 4.1: RevenueCat lifetime paywall
- Monetization: free tier keeps unlimited text conversion + basic card export (Minimal theme, watermark on). Pro is a $4.99 one-time non-consumable (`pro_lifetime`) unlocking Midnight / Terminal themes, custom typography, and watermark removal via entitlement `pro_access`.
- Added `purchases_flutter` ^10.10.1 and `url_launcher` ^6.3.2. Placeholders live in `lib/core/config/revenue_cat_config.dart` (`appl_` / `goog_` public keys).
- `PaywallService` configures the SDK with platform keys + debug logs, reads cached `CustomerInfo` on launch (offline Pro still works), purchases with `Purchases.purchaseProduct('pro_lifetime', type: inapp)`, and restores via `Purchases.restorePurchases()`. Plugin/desktop failures stay on the free tier.
- Riverpod: `paywallProvider` is `AsyncValue<bool>`; `isProPurchasedProvider` is fail-closed (`value ?? false`). Successful purchase/restore writes `AsyncData(true)` so the exporter rebuilds immediately. `main()` initializes the SDK before `runApp`; `CleanCanvasApp` watches the provider to warm cache.
- Paywall UI: modal sheet “Unlock SocialSlate Pro” with benefit bullets, “One-time payment of $4.99 (Lifetime Access)”, “Unlock Lifetime Pro”, Restore Purchases, Terms / Privacy, and in-button spinners while StoreKit / Play is pending.
- Hard gating: Midnight + Terminal chips show a lock and open the sheet if unentitled. “Remove Watermark” does the same. `CardCanvas` applies `theme.enforcedFor(isProPurchased:)` so `showWatermark` is forced `true` whenever `isProPurchased == false` — UI tampering cannot strip the rasterized watermark.
- Tests: `test/features/paywall_test.dart` covers free → pro, cancelled purchase, restore, forced watermark, locked theme intercept, and pending spinner. Existing exporter tests wrap `ProviderScope` with `FakePaywallService`. `flutter test` 143 passed; `flutter analyze lib test` clean.
- Modified: `pubspec.yaml`, `lib/core/config/revenue_cat_config.dart`, `lib/features/paywall/{paywall_service,paywall_provider,paywall_bottom_sheet}.dart`, `lib/features/exporter/{templates/card_theme_config,presentation/card_canvas,presentation/card_exporter_screen}.dart`, `lib/main.dart`, `android/app/src/main/AndroidManifest.xml`, `test/features/paywall_test.dart`, `test/helpers/fake_paywall_service.dart`, exporter/widget tests, `PROJECT_JOURNAL.md`.
- Follow-up: swap placeholder API keys; create `pro_lifetime` in App Store Connect / Play Console; attach it to `pro_access` in the RevenueCat dashboard; enable the iOS In-App Purchase capability before store submission.

### 2026-09-18 — Git hygiene + GitHub remote (`SocialSlate`)
- Hardened root `.gitignore`: Flutter/Dart artifacts (`build/`, `.dart_tool/`, `.flutter-plugins*`, `.packages`, iOS Generated/*, `android/.gradle/`, `local.properties`), secrets (`.env*`, `*.jks`/`*.keystore`/`*.p12`/`*.key`), IDE caches (`.DS_Store`, `.idea/`, `.vscode/`, `*.iml`), while keeping `.cursor/rules/` tracked.
- Initialized Git on `main`, initial commit of MVP assets (engines, scratchpad/Hive, card exporter, clipboard, paywall, Cursor rules, architecture docs).
- GitHub: renamed remote to **SocialSlate**, set **public**, `origin` → https://github.com/BCuracao/SocialSlate, `main` pushed and tracking.
- Modified: `.gitignore`, `PROJECT_JOURNAL.md` (Active State remote URL + this session log).
- Follow-up: none for VCS; still replace RevenueCat placeholder keys before store shipping.

### 2026-09-18 — Task 3.4: Multi-slide carousel engine
- `CarouselDeck.fromMarkdown` in `lib/features/exporter/models/carousel_deck.dart` (pure Dart) splits the scratchpad draft on markdown thematic breaks (`---`, `***`, `___`, 3+ markers, start/end of file). Empty segments are discarded; no divider → a single slide. Original buffer is never mutated.
- `CardCanvas` accepts optional `currentSlideIndex` / `totalSlides` and paints a top-right `N / M` pill when `totalSlides > 1`, kept clear of the author header and watermark. `isProPurchased` still gates the watermark on every slide.
- `CardExporterScreen` uses `PageView.builder` for carousels, with a “Slide X of Y” banner, prev/next arrows, and dot indicators. Action labels switch: *Share Image* / *Save Image* vs *Share Carousel (N Slides)* / *Save All (N Slides)*. A linear progress bar shows “Exporting slide X of Y...” during batch work.
- `CarouselBatchExporter.renderDeck` inserts an off-screen overlay `CardCanvas`, presents each slide, waits for paint, then rasterizes at `pixelRatio: 3.0` so only one `ui.Image` is live at a time. `CardExportService.shareAllSlides` writes unique temp PNGs and opens one share sheet; `saveAllToGallery` saves sequentially and returns the saved count.
- Tests: `test/features/carousel_deck_test.dart` — divider variants, fallback, pagination strings, badge layout, paging UI, batch labels/progress, Pro watermark forwarding, sequential capture, multi-file share/save. `flutter test` 170 passed; `flutter analyze lib test` clean.
- Modified: `lib/features/exporter/models/carousel_deck.dart`, `lib/features/exporter/render/carousel_batch_exporter.dart`, `lib/features/exporter/{presentation/card_canvas,presentation/card_exporter_screen,render/card_export_service}.dart`, `test/features/carousel_deck_test.dart`, exporter/widget tests for the new button labels, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: none for carousels; still replace RevenueCat placeholder keys before store shipping.

### 2026-09-18 — Task 3.5: On-device syntax highlighting
- Added `flutter_highlight` ^0.7.0 and `highlight` ^0.7.0. Tokenizing and palettes stay on-device; no network calls.
- `CodeBlockParser` in `lib/features/exporter/render/code_block_parser.dart` (pure Dart) splits slide markdown on fenced blocks (` ```lang ` / closing fence), preserves surrounding prose, and maps aliases (`js`/`ts`/`py`/`rs`/`c#`, …) onto highlight.js ids. Missing or unknown tags skip coloring.
- `SyntaxCardBlock` embeds in `CardCanvas`: JetBrains Mono, wrap + dynamic font scale so 1080×1080 / 1080×1920 exports stay unclipped.
  - **Dev Terminal**: `#0D1117` pane, Atom One Dark tokens, macOS traffic-light chrome (replaces the outer title bar when a fence is present).
  - **Minimal**: `#F1F5F9` pane, GitHub Light tokens, no chrome.
  - **Midnight**: same dark pane/tokens as Terminal, no chrome.
- Mixed slides render prose → code → prose. Fence-free Terminal cards keep the existing line-tint fallback.
- Tests: `test/features/code_highlight_test.dart` — language/no-language/unrecognized, mixed parse, buffer non-mutation, canvas overflow on long snippets, theme palettes. `flutter test` 185 passed; `flutter analyze lib test` clean.
- Modified: `pubspec.yaml`, `lib/features/exporter/render/code_block_parser.dart`, `lib/features/exporter/presentation/syntax_card_block.dart`, `lib/features/exporter/presentation/card_canvas.dart`, `test/features/code_highlight_test.dart`, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: none for highlighting; still replace RevenueCat placeholder keys before store shipping.

### 2026-09-18 — Task 2.3: Keyboard formatting toolbar + live markdown styling
- Pure `MarkdownFormatter` in `lib/features/scratchpad/state/markdown_formatter.dart` (no Flutter imports) wraps/toggles tokens around a selection or caret:
  - Bold `**` / italic `*` / inline `` `code` ``, with unwrap-on-second-tap; italic will not steal a surrounding `**` pair.
  - Header cycles the current line through `# `, `## `, `### `, then body text.
  - Bullet / quote toggle `- ` and `> ` at line start.
  - Multi-line selections become fenced ` ``` ` blocks.
  - `+ Slide` inserts `\n\n---\n\n` (carousel thematic break) and leaves the caret after the divider.
- `StyledMarkdownEditingController` paints the raw markdown buffer live: H1 24sp/w700, H2 20sp/w600, bold/italic/quote/code, fenced blocks in monospace with a tinted fill, `---` / `___` as a struck divider rule. Markers (`**`, `#`, `` ` ``) render at 35% opacity. Span text is 1:1 with the stored buffer.
- `FormattingToolbar` docks above the export/status stack (rides the keyboard via `resizeToAvoidBottomInset`). Horizontal accessory: **B**, **I**, **H**, **•=**, **”**, **</>**, plus a filled **+ Slide** chip. Every tap fires `HapticFeedback.selectionClick()` and writes `controller.selection` from the formatter result. `ExcludeFocus` keeps the software keyboard up.
- `ScratchpadScreen` uses the styled controller and forwards toolbar edits through `scratchpadProvider.updateContent` so Hive auto-save still runs.
- Tests: `test/features/formatting_toolbar_test.dart` — wrap/unwrap/cycle unit cases; Bold tap wraps the exact selection; + Slide inserts `\n\n---\n\n`; `buildTextSpan` applies `FontWeight.bold` to `**bold**` content while dimming markers. `flutter test` 201 passed; `flutter analyze lib test` clean.
- Modified: `lib/features/scratchpad/state/markdown_formatter.dart`, `lib/features/scratchpad/presentation/{styled_markdown_controller,formatting_toolbar,scratchpad_screen}.dart`, `test/features/formatting_toolbar_test.dart`, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: none for the editor chrome; still replace RevenueCat placeholder keys before store shipping.

### 2026-09-18 — Task 3.6: Rich markdown cards + auto-scaling type
- Hardened `CarouselDeck.fromMarkdown` divider regex to match LF / CRLF / CR and `---`, `***`, `___` (3+ markers) without swallowing consecutive rules. Slides are trimmed; empty segments dropped. The 3-slide mixed-newline fixture now splits into exactly 3 cards.
- `MarkdownCardContent` renders H1–H3, bold, italic, blockquotes (accent left rule), `•` lists, and inline code as widgets so `#`, `**`, and `>` never paint on the canvas. Fenced blocks still embed via `SyntaxCardBlock`.
- Dropped the 280-character Twitter overflow warning. `CardLayout.fontScaleFor` scales punchy copy 1.25×, standard posts 1.0×, long-form 0.82× (dense 0.7×), left-aligned with 64×48 padding on the 1080px canvas and a FittedBox clip guard.
- Tests: `test/features/card_typography_test.dart` — marker stripping, 3-slide split, scale buckets. Existing rasterizer overflow case now asserts the warning is gone. `flutter test` 211 passed; `flutter analyze lib test` clean.
- Modified: `lib/features/exporter/models/carousel_deck.dart`, `lib/features/exporter/templates/card_theme_config.dart`, `lib/features/exporter/presentation/{markdown_card_content,card_canvas,card_exporter_screen}.dart`, `test/features/{card_typography_test,card_rasterizer_test,carousel_deck_test}.dart`, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: none for card typography; still replace RevenueCat placeholder keys before store shipping.

### 2026-09-18 — Task 2.4: Multi-draft drawer + settings
- Hive `drafts_box` now stores many `Draft` documents (`id`, `title`, `content`, `createdAt`, `updatedAt`) under `draft:<id>` keys, with `__active_id__` pointing at the editor buffer. Schema v2 migrates the legacy single-doc keys (`id` / `content` / `updatedAt`) on first access so existing scratchpad text is kept.
- Auto-title from the first non-empty line (`# Heading`, `**Bold Title**`, or plain text) with markdown tokens stripped; empty buffers use `Untitled Draft`. Active draft still auto-saves on the 400ms debounce.
- `draftListProvider` + `scratchpadProvider.activeDraftId`: switching flushes the pending write, loads the selected draft, and refreshes word/slide stats. New Post creates a blank Hive document and focuses the editor.
- `DraftsDrawer`: SocialSlate header + count, pinned New Post, search, title/preview/relative-time/word/slide badges, active accent, swipe-to-delete with a confirmation dialog. App bar title is the current draft (tap to rename).
- `SettingsBottomSheet`: default author name / handle / avatar shortcut (`cardSettingsProvider`, `settings_box`), Pro Active badge or paywall CTA, Restore Purchases, Terms / Privacy, version `1.0.0`. Card export now stamps the saved author handle.
- Tests: `test/features/draft_storage_test.dart` — CRUD, auto-titling, legacy migration, timestamped switching, drawer/settings widgets. `flutter test` 228 passed; `flutter analyze lib test` clean.
- Modified: `lib/core/persistence/{draft_storage,settings_storage}.dart`, `lib/features/scratchpad/{state/draft_list_notifier,state/draft_presentation,state/scratchpad_state,state/scratchpad_notifier,presentation/drafts_drawer,presentation/settings_bottom_sheet,presentation/scratchpad_screen,presentation/export_toolbar}.dart`, `lib/features/exporter/state/card_settings.dart`, `lib/main.dart`, `test/features/{draft_storage_test,scratchpad_state_test,export_actions_test}.dart`, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: still replace RevenueCat placeholder keys before store shipping.

### 2026-09-18 — Task 4.2: Store branding, offline legal, icons, ProGuard
- Display name is **SocialSlate** everywhere users see it: `MaterialApp.title`, iOS `CFBundleDisplayName` / `CFBundleName`, Android `android:label`. Bundle IDs left as `com.cleancanvas.cleanCanvas` (iOS) and `com.cleancanvas.clean_canvas` (Android) so existing RevenueCat / store product mapping is not silently retargeted.
- Brand mark: slate `#0F172A` field with a geometric **S** glyph in `assets/icon/` (`app_icon.svg` + 1024px PNGs). `flutter_launcher_icons` and `flutter_native_splash` write native mipmaps, adaptive icons, and a dark splash so launch no longer flashes white.
- Offline legal: `assets/legal/privacy_policy.md` and `terms_of_service.md` are bundled Flutter assets. Privacy states no accounts, Hive-local drafts, on-device images, zero telemetry, and anonymous Apple/Google receipt checks via RevenueCat. Terms cover the $4.99 one-time non-consumable lifetime unlock, offline use, and limitation of liability.
- `LegalDocumentViewer` (`flutter_markdown`) opens from Settings and the paywall sheet. Hosted `cleancanvas.app` URLs were removed from `RevenueCatConfig`.
- Android release: `isMinifyEnabled` + `isShrinkResources` with `android/app/proguard-rules.pro` keep rules for Hive adapters, `com.revenuecat.purchases.**`, and Play Billing.
- Tests: `test/features/legal_documents_test.dart` — asset wording, in-app viewer, Settings wiring, `MaterialApp.title`. `flutter analyze lib test` clean; `flutter test` 235 passed.
- Release APK: `flutter build apk --split-per-abi` succeeded with R8 (armeabi-v7a 21.2MB, arm64-v8a 23.8MB, x86_64 25.5MB). Local JDK 17 (`flutter config --jdk-dir` → Temurin 17) was required; Gradle was otherwise launching a Java 8 VM.
- Modified: `pubspec.yaml`, `lib/main.dart`, `lib/core/config/revenue_cat_config.dart`, `lib/features/scratchpad/presentation/{legal_document_viewer,settings_bottom_sheet}.dart`, `lib/features/paywall/paywall_bottom_sheet.dart`, `assets/icon/*`, `assets/legal/*`, `android/app/{build.gradle.kts,proguard-rules.pro,src/main/AndroidManifest.xml}` plus generated splash/icon resources, `ios/Runner/{Info.plist,Assets.xcassets,Base.lproj/LaunchScreen.storyboard}`, `test/features/legal_documents_test.dart`, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: replace RevenueCat placeholder keys; attach a Play/App Store signing config (release still uses the debug keystore); `flutter_markdown` is discontinued on pub.dev (`flutter_markdown_plus` successor) but kept as specified.

### 2026-09-19 — Rebrand to PenningPal
- Official product name is **PenningPal**. Working titles Clean Canvas / SocialSlate are retired from user-facing copy.
- Native display names: iOS `CFBundleDisplayName` / `CFBundleName`, Android `android:label`, web `<title>` / PWA `name` / `short_name`, plus macOS / Linux / Windows window titles.
- In-app: `MaterialApp.title`, drafts drawer header, paywall / settings unlock copy (“Unlock PenningPal Pro”), version line, card watermark `Made with PenningPal`, author fallback, Photos album name.
- Legal: `assets/legal/privacy_policy.md` and `terms_of_service.md` now name PenningPal. iOS photo-library usage strings updated to English PenningPal copy.
- Docs/rules: `.cursor/rules/00-project.mdc`, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md` title + Active State, `README.md`.
- Bundle IDs and Dart package name stay `com.cleancanvas.*` / `clean_canvas` so RevenueCat and store product mapping are unchanged. Git remote remains `BCuracao/SocialSlate`.
- Tests updated for display name, paywall headline, drawer brand, watermark fallback, and share text.
- Modified: `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`, `web/{index.html,manifest.json}`, `macos/Runner/Configs/AppInfo.xcconfig`, `linux/runner/my_application.cc`, `windows/runner/{main.cpp,Runner.rc}`, `lib/main.dart`, `lib/features/{scratchpad/presentation/{drafts_drawer,settings_bottom_sheet},paywall/paywall_bottom_sheet,exporter/{presentation/card_canvas,templates/card_theme_config,render/card_export_service}}.dart`, `assets/legal/*`, `assets/icon/app_icon.svg`, tests, `docs/ARCHITECTURE.md`, `.cursor/rules/00-project.mdc`, `README.md`, `PROJECT_JOURNAL.md`.
- Follow-up: none for naming; still replace RevenueCat placeholder keys before store shipping.

### 2026-09-19 — Task 4.3: PenningPal 1024×1024 launcher icons
- Official mark: deep slate gradient `#0B0F19` → `#1E293B`, geometric fountain-pen nib (amber `#F59E0B` tip, off-white `#F8FAFC` metal) overlapping a rounded card/slate. Replaces the previous SocialSlate **S** glyph.
- Generator: `tool/generate_penningpal_icon.dart` (software SDF rasterizer + PNG encoder) writes `assets/icon/app_icon.png` (opaque RGB master), `icon_background.png` (solid `#0B0F19`), and `icon_foreground.png` (transparent emblem in the central ~66% adaptive safe zone). Vector companion: `assets/icon/penningpal_icon.svg` / `app_icon.svg`.
- `flutter_launcher_icons`: iOS catalog + Android adaptive `launcher_icon` (`adaptive_icon_foreground_inset: 0`, `remove_alpha_ios: true`). Manifest `android:icon` is `@mipmap/launcher_icon`.
- `flutter_native_splash`: launch color `#0B0F19` with the foreground emblem (including Android 12 splash icon background).
- Verified: iOS `AppIcon.appiconset` PNGs are RGB with no alpha; Android `mipmap-{m,h,xh,xxh,xxxh}dpi` contain `launcher_icon.png` plus adaptive foreground/background drawables.
- Modified: `tool/generate_penningpal_icon.dart`, `assets/icon/*`, `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, generated `ios/Runner/Assets.xcassets/` and `android/app/src/main/res/` mipmaps/splash, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: none for icons; still replace RevenueCat placeholder keys before store shipping.

### 2026-09-19 — Card exporter typography & vertical pacing overhaul
- Recalibrated card type for a 1080px canvas (not mobile/desktop points): H1 78px/w800, H2 60px/w700, H3 48px/w600, body 38px/1.55, blockquote 42px italic with a 6px/28px accent rule, lists 38px with 18px item gaps, code 32px/1.4.
- `CardLayout.fontScaleFor` now buckets `<140 → 1.35×`, `140–349 → 1.1×`, `350–700 → 0.95×`, `>700 → 0.82×` (floor so long posts stay legible). Insets are 84px horizontal and 64px vertical.
- `CardCanvas` vertically centers markdown between the author header and watermark so 9:16 Story cards fill the middle third instead of hugging the top. Author name is 32px/w700, handle 26px muted, watermark 24px muted. Name + handle both stamp when set in Settings.
- Preview `FittedBox` still scales the 1080px raster canvas into the phone slot; live type is readable without zooming.
- Tests: `test/features/card_typography_test.dart` updated for the new scale buckets, canvas type sizes, story centering, and preview fit. `flutter test` 239 passed; `flutter analyze lib test` clean.
- Modified: `lib/features/exporter/{templates/card_theme_config,presentation/{markdown_card_content,card_canvas,syntax_card_block,card_exporter_screen},render/carousel_batch_exporter}.dart`, `lib/core/persistence/settings_storage.dart`, `lib/features/scratchpad/presentation/export_toolbar.dart`, `test/features/{card_typography_test,carousel_deck_test,draft_storage_test}.dart`, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: none for typography; still replace RevenueCat placeholder keys before store shipping.

### 2026-09-19 — Task 3.7: Copy card to clipboard, inspect zoom, render overlay
- `CardExportService.copyImageToClipboard` writes raw PNG bytes through `super_clipboard` (`DataWriterItem` + `Formats.png`) and returns `false` when the clipboard is unavailable. Copy always rasterizes the currently visible slide, including carousels.
- Exporter action bar adds **Copy Card** (clipboard icon). Success fires `HapticFeedback.mediumImpact()` and a floating toast: “Card copied to clipboard! Ready to paste.”
- Tapping the live preview opens `CardInspectModal`: `Colors.black87` backdrop, centered `InteractiveViewer` (0.8×–4.0×), close button, and swipe-down to dismiss. Inspect uses a separate canvas so pan/zoom never mutates the rasterization `RepaintBoundary`.
- Glassmorphism overlay (`BackdropFilter` blur 4) with spinner + status (“Rendering 1080px card...” / “Preparing slide N of M...”) while rasterizing; action buttons ignore extra taps.
- Android: declared `super_native_extensions` `DataProvider` so PNG clipboard writes work on-device.
- Tests: `test/features/card_clipboard_test.dart` — successful PNG write, invalid buffer, missing clipboard, Copy Card toast, carousel current-slide copy, tap-to-zoom inspect route. `flutter test` 246 passed; `flutter analyze lib test` clean.
- Modified: `lib/features/exporter/render/card_export_service.dart`, `lib/features/exporter/presentation/{card_exporter_screen,card_inspect_modal}.dart`, `android/app/src/main/AndroidManifest.xml`, `test/features/{card_clipboard_test,card_export_service_test,carousel_deck_test,card_rasterizer_test}.dart`, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: none for copy/inspect; still replace RevenueCat placeholder keys before store shipping.

### 2026-09-19 — Task 3.8: LinkedIn PDF carousels, premium themes, brand profiles
- Themes: **Modern Aurora** (slate `#0B0F19` + indigo `#4F46E5` / violet `#9333EA` blooms), **Editorial Warm** (cream `#F9F6EE`, charcoal `#1C1917`, terracotta `#C2410C`), **Neo-Brutalist** (canary `#FEF08A`, mint accent `#A7F3D0`, 4px black border), **Custom Brand** (12 swatches + hex + `flutter_colorpicker`, Pro). `CardCanvas` paints gradients, overlay blooms, and theme-defined borders.
- On-device `LinkedInPdfExporter` (`package:pdf`) writes marginless 1080×1080 pt pages with full-bleed `BoxFit.cover` PNGs. Carousel action bar adds **Export LinkedIn PDF**; free taps open the paywall.
- `ProfileStorage` (`profiles_box`) stores ghostwriter personas. Free cap is 1; Pro is unlimited. Exporter pill switches identities; Settings exposes the same sheet.
- Paywall bullets now call out watermark removal, LinkedIn PDF carousels, unlimited brand profiles, Aurora / Editorial / Neo-Brutal / Custom Hex, and a one-time $4.99 lifetime unlock.
- Tests: `test/features/pdf_export_test.dart`, `test/features/profile_storage_test.dart`, plus theme / paywall / carousel updates. `flutter test` 266 passed; `flutter analyze lib test` clean.
- Modified: `pubspec.yaml`, `lib/features/exporter/{templates/card_theme_config,presentation/{card_canvas,card_exporter_screen,brand_color_picker_sheet,brand_profile_sheet,syntax_card_block},render/{linkedin_pdf_exporter,card_export_service},state/card_settings}.dart`, `lib/core/persistence/{profile_storage,settings_storage}.dart`, `lib/features/paywall/paywall_bottom_sheet.dart`, `lib/main.dart`, settings sheet, tests, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: still replace RevenueCat placeholder keys before store shipping.

### 2026-09-20 — Task 3.9: Custom photo backdrops with blur and contrast scrim
- `CardThemeConfig` now carries an optional on-device `customBackgroundImagePath` plus `blurSigma` (0–30, default 12), `overlayOpacity` (0.2–0.85, default 0.5), and `isDarkOverlay` (default true). Free rasterization via `enforcedFor` strips the photo and keeps the watermark unless `kDemoModeBypassPaywall` / Pro is active.
- `CardCanvas` paints a full-bleed `ImageFiltered` Gaussian blur + contrast scrim under the author header and markdown so 1080×1080 and 1080×1920 live preview and `pixelRatio: 3` export stay legible.
- `PhotoBackdropStore` copies `image_picker` selections into application-support `photo_backdrops/` (never uploaded). `CardCustomizerControls` exposes Choose / Remove Photo, blur, dimmer, and dark/light scrim toggles; picks are Pro-gated.
- `CarouselBatchExporter` precaches the local file once so carousel slides and LinkedIn PDF pages reuse the same decoded image without extra `ui.Image` leaks. Paywall copy lists the new backdrop benefit.
- Tests: `test/features/custom_background_test.dart`. `flutter analyze lib test` clean; `flutter test` 279 passed.
- Modified: `lib/features/exporter/{templates/card_theme_config,presentation/{card_canvas,card_customizer_controls,card_exporter_screen},render/{photo_backdrop_store,carousel_batch_exporter}}.dart`, `lib/features/paywall/paywall_bottom_sheet.dart`, `pubspec.yaml`, iOS `Info.plist`, Android `AndroidManifest.xml`, tests, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: still replace RevenueCat placeholder keys before store shipping; set `kDemoModeBypassPaywall` to `false` before production submission.

### 2026-09-20 — GitHub README
- Replaced the Flutter starter README with a product-facing overview for PenningPal: what it does, scratchpad/export/card features, Free vs Pro, privacy, stack, local run instructions, and store-shipping notes for maintainers.
- Clarifies that the public GitHub remote remains `BCuracao/SocialSlate` while the shipped name is PenningPal.
- Modified: `README.md`, `PROJECT_JOURNAL.md`.

### 2026-09-20 — GitHub repository renamed to PenningPal
- Renamed the public GitHub remote from `BCuracao/SocialSlate` to `BCuracao/PenningPal` (old URL redirects).
- Updated `origin`, clone instructions, and README so they no longer treat SocialSlate as the current repo name.
- Modified: `README.md`, `PROJECT_JOURNAL.md`.

### 2026-10-04 — Task 2.5: True WYSIWYG scratchpad
- Replaced the scratchpad `TextField` with `flutter_quill` 11.6.0 (`QuillEditor`). `flutter_quill_to_markdown` is not on pub.dev, and `markdown_quill` cannot represent a carousel divider, so the Markdown bridge is a dedicated converter in `lib/features/scratchpad/render/markdown_quill_bridge.dart`.
- `markdownToDelta` loads Hive Markdown into a Quill document: headings, bold, italic, quotes, bullets, inline/fenced code, and thematic breaks (`---`, `***`, `___`) as a `slideBreak` embed. `deltaToMarkdown` writes clean Markdown back, with embeds as `---`, so `CardCanvas`, `CarouselDeck`, and the Unicode/HTML exporters keep the same buffer.
- The editor paints formatted text only: H1 26sp bold, H2 21sp semi-bold, body 17sp at 1.5 line height, an indented italic quote with a 3px accent rule, and a `── Slide Break N ──` banner. Document changes debounce through the existing 400ms Hive save. Draft switches replace the document; keystrokes do not, so the caret is not rebuilt on each save.
- `FormattingToolbar` calls Quill commands for **B**, **I**, **H** (H1 → H2 → body), **•**, **”**, **</>**, and **+ Slide** (haptic). Bold, italic, and heading buttons highlight while the caret is inside that style.
- Tests: `test/features/wysiwyg_editor_test.dart` plus updated toolbar, scratchpad, and export widget tests. `flutter analyze lib test` clean; `flutter test` 284 passed.
- Modified: `pubspec.yaml`, `pubspec.lock`, `lib/features/scratchpad/render/markdown_quill_bridge.dart`, `lib/features/scratchpad/presentation/{scratchpad_screen,formatting_toolbar,quill_formatting,scratchpad_editor_styles,slide_break_embed}.dart`, removed `styled_markdown_controller.dart`, `test/features/{wysiwyg_editor_test,formatting_toolbar_test,scratchpad_state_test,export_actions_test}.dart`, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: still replace RevenueCat placeholder keys before store shipping; set `kDemoModeBypassPaywall` to `false` before production submission.

### 2026-10-05 — Task 4.4: RevenueCat StoreKit 2 integration and strict gating
- `AppConfig` now holds the Apple public SDK key, an empty Google key until Play Console is linked, entitlement `pro_access`, offering id `default`, and `kDemoModeBypassPaywall = false`.
- `PaywallService` configures `purchases_flutter` with StoreKit 2, loads `Offerings.current` (falling back to `default`), purchases that package with `Purchases.purchasePackage`, and restores. A cancelled store sheet returns without an error alert.
- `isProPurchasedProvider` is true when `pro_access` is active or demo bypass is on. `PaywallNotifier` keeps it current via `Purchases.addCustomerInfoUpdateListener`. `currentOfferingProvider` supplies the paywall CTA: `Unlock Lifetime Pro — ${priceString}`, with `Unlock Lifetime Pro — $4.99` when offerings are unavailable.
- Free users still see lock badges on Midnight, Terminal, Aurora, Editorial, Neo-Brutal, and Custom. Tapping a locked theme, Remove Watermark, + Choose Photo, or Export LinkedIn PDF opens `PaywallBottomSheet`. `CardCanvas` forces the watermark and strips custom photos. Free accounts stay at one brand profile.
- Added `ios/PenningPalConfiguration.storekit` (non-consumable `pro_lifetime` at 4.99) and selected it on the Runner scheme so the iOS Simulator can purchase without an Apple sandbox account.
- Tests: `flutter analyze lib test` clean; `flutter test` 289 passed.
- Modified: `lib/core/config/{app_config,revenue_cat_config}.dart`, `lib/features/paywall/{services/paywall_service,state/paywall_providers,presentation/paywall_bottom_sheet}.dart` (previous flat files re-export these), `test/features/paywall_test.dart`, `test/helpers/fake_paywall_service.dart`, `ios/PenningPalConfiguration.storekit`, `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`, `docs/ARCHITECTURE.md`, `README.md`, `PROJECT_JOURNAL.md`.
- Follow-up: add the Google Play RevenueCat public key; create `pro_lifetime` in App Store Connect and Play Console and attach it to the `default` offering and `pro_access`; enable the In-App Purchase capability before device or TestFlight purchases.

### 2026-10-05 — Rename store package ID to Shoebill Software
- Native application ID is now `com.shoebillsoftware.penningpal` on iOS, Android, macOS, and Linux. iOS and macOS test targets use `com.shoebillsoftware.penningpal.RunnerTests`.
- Android `namespace`, `applicationId`, `MainActivity` package, and the super_clipboard provider authority all moved together. Kotlin source now lives at `android/app/src/main/kotlin/com/shoebillsoftware/penningpal/MainActivity.kt`.
- macOS and Windows copyright / company strings now say Shoebill Software.
- Dart package name stays `clean_canvas`. RevenueCat is tied to the store app record, so the Apple and Google apps (and the RevenueCat dashboard apps) must be created or updated under this ID before purchases will match.
- Modified: `ios/Runner.xcodeproj/project.pbxproj`, `macos/Runner.xcodeproj/project.pbxproj`, `macos/Runner/Configs/AppInfo.xcconfig`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/shoebillsoftware/penningpal/MainActivity.kt`, `linux/CMakeLists.txt`, `windows/runner/Runner.rc`, `README.md`, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: register `com.shoebillsoftware.penningpal` in App Store Connect, Play Console, and RevenueCat before store shipping.

### 2026-10-05 — Rename Dart package to penningpal
- `pubspec.yaml` package name is now `penningpal`. Test imports use `package:penningpal/...`. App library files already use relative imports, so they did not need path changes.
- Export filenames (`clean_canvas_YYYYMMDD_HHMMSS.png`) and desktop binary names (`clean_canvas` on Linux, Windows, and macOS) are unchanged.
- Modified: `pubspec.yaml`, `test/**/*.dart`, `PROJECT_JOURNAL.md`.
- Follow-up: run `flutter pub get` after pulling so `.dart_tool/package_config.json` picks up the new name.

### 2026-10-05 — TestFlight release IPA
- `pubspec.yaml` already used `version: 1.0.0+1` (App Store version 1.0.0, build 1). Left unchanged.
- Added `ITSAppUsesNonExemptEncryption` = `false` to `ios/Runner/Info.plist` so App Store Connect can skip the manual export-compliance prompt. `NSPhotoLibraryAddUsageDescription` was already present for card saves.
- `flutter clean`, `flutter pub get`, and `flutter build ipa` succeeded. App Store IPA is `build/ios/ipa/PenningPal.ipa` (30MB). Xcode also wrote `build/ios/archive/Runner.xcarchive`.
- Validation reported display name PenningPal, bundle `com.shoebillsoftware.penningpal`, deployment target 15.0, signed with team `Y6BQW63Q2S`.
- Modified: `ios/Runner/Info.plist`, `PROJECT_JOURNAL.md`.
- Follow-up: upload `PenningPal.ipa` with Transporter or `xcrun altool`; register the bundle ID and `pro_lifetime` in App Store Connect before TestFlight purchases.

### 2026-10-05 — Phase 1: Creator power-ups
- `PlatformMetrics` (pure Dart) counts words, reading time at 200 wpm, and LinkedIn 3,000 / X 280 / Threads 500 character meters. Tone is green through 70%, amber through the limit, and red on overflow. The opening hook is the text before the first blank line or `---` rule; hooks longer than 210 characters raise the LinkedIn fold warning. Line-break indexes are reported so the fold line is visible. The raw Markdown buffer is not rewritten.
- `PlatformCounterHud` docks above the formatting toolbar. Tapping a platform badge focuses that limit. `LinkedInFoldIndicator` sits under the editor and marks the mobile "see more" cutoff.
- `FrameworkTemplates` holds Contrarian Hook, The 5-Step Breakdown, and The Story + Lesson. Each body includes a `---` slide break. The toolbar sparkle button opens `TemplatePickerBottomSheet`. Blank drafts insert immediately. Drafts with text ask "Append to existing text" or "Replace current draft". Append keeps existing slide breaks; Quill round-trips them back to `---`.
- `ShareExportService` writes a temp PNG and calls `SharePlus.instance.share(ShareParams(files: [XFile(path)]))` for a single card. Carousel **Share** (`Icons.share`, labeled Share PDF) rasterizes the deck and shares the multi-page PDF. Save to Photos is unchanged. **Export LinkedIn PDF** stays the Pro-gated action.
- `share_plus` ^12.0.1 was already in `pubspec.yaml`. `flutter pub get` resolves it to 12.0.2.
- Tests: `flutter analyze lib test` clean; `flutter test` 303 passed. New coverage is `test/features/scratchpad_powerups_test.dart` plus share-service cases in `test/features/card_export_service_test.dart`.
- Modified: `lib/features/scratchpad/state/{platform_metrics,framework_templates}.dart`, `lib/features/scratchpad/presentation/{formatting_toolbar,scratchpad_screen}.dart`, `lib/features/scratchpad/presentation/widgets/{platform_counter_hud,linkedin_fold_indicator,template_picker_bottom_sheet}.dart`, `lib/features/exporter/services/share_export_service.dart`, `lib/features/exporter/presentation/card_exporter_screen.dart`, exporter widget tests, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: still add the Google Play RevenueCat public key and register `pro_lifetime` before store purchases. Share PDF on a carousel is available from the Share button without the Pro sheet; Export LinkedIn PDF remains gated.

### 2026-10-05 — Fix carousel share repeating the first slide
- Share and Save both rasterize the deck in `CarouselBatchExporter` before writing files. The frame wait returned immediately whenever the scheduler was idle, so on a phone every capture snapped the first painted slide. A 3-slide share therefore sent slide 1 three times. File names were already unique; the PNG bytes were not.
- `CardRasterizer.waitForNextFrame` now schedules a frame and resumes from its post-frame callback. Each slide is rebuilt and painted before `toImage`.
- Current **Share** on a carousel still compiles those PNGs into one PDF. The previous build's **Share Carousel (N Slides)** attached N PNGs from the same capture path, so an older install shows the same bug.
- Test: `renderDeck reads each slide body before capturing it`. `flutter analyze` on the touched files is clean; carousel, rasterizer, and export service tests passed (71).
- Modified: `lib/features/exporter/render/{card_rasterizer,carousel_batch_exporter}.dart`, `test/features/carousel_deck_test.dart`, `PROJECT_JOURNAL.md`.
- Follow-up: install a new build on the phone. The TestFlight IPA from earlier today does not include this fix.

### 2026-10-05 — Phase 2: Multi-draft content engine
- Each scratchpad document is a `DraftItem` in Hive `drafts_box`: UUID, inferred title, markdown, `DraftStatus` (`draft` / `ready` / `published`), `createdAt`, and `updatedAt`. Status pills are muted grey, amber/orange, and green.
- Legacy split keys (`id` / `content` / `updatedAt`) still migrate. A `legacy_draft` string or map is imported only when the box has no drafts, so an existing workspace is not overwritten.
- The editor stays bound to the active draft. Edits debounce to Hive at 400ms, refresh `updatedAt` and the inferred title, and keep the status. Switching drafts flushes that pending edit, then reloads the Quill document once so the caret is not reset on each keystroke.
- The folder button opens the drafts drawer: search (title or body), chips for All / Drafts / Ready / Published, New Draft, relative time, and slide count. The open draft is highlighted. Swipe or the row menu can duplicate (`Title (Copy)`), change status, or delete. Delete shows an Undo snackbar. The app bar pill sets Draft, Ready, or Published on the open draft.
- Tests: `flutter analyze lib test` clean; `flutter test` 315 passed. New coverage is `test/features/multi_draft_engine_test.dart`.
- Modified: `lib/features/scratchpad/models/draft_item.dart`, `lib/features/scratchpad/storage/draft_storage.dart`, `lib/core/persistence/draft_storage.dart`, `lib/features/scratchpad/state/{draft_providers,draft_list_notifier,scratchpad_notifier,scratchpad_state}.dart`, `lib/features/scratchpad/presentation/{scratchpad_screen,drafts_drawer}.dart`, `lib/features/scratchpad/presentation/widgets/drafts_drawer.dart`, `test/features/multi_draft_engine_test.dart`, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: still add the Google Play RevenueCat public key and register `pro_lifetime` before store purchases.

### 2026-10-05 — Phase 3: Carousel layouts and canvas intelligence
- `SlideRole` (`cover`, `body`, `cta`) auto-detects from position: one slide is body; the first slide of a multi-slide deck is cover; the last slide is CTA when the deck has at least two slides. The exporter’s Cover | Body | CTA control overrides the selected slide, and that choice follows the slide through reorder, duplicate, and delete.
- Cover cards center the copy, enlarge headings (1.2× on top of the length scale), and paint a `SWIPE »` eyebrow, or the opening heading when it is short enough to read as a topic. Body cards stay left-aligned with the `N / M` index badge. CTA cards add the creator avatar, handle, and “Found this valuable? Repost & Follow”.
- `CardLayout.fontScaleFor` is now 1.15× under 120 characters, 1.0× through 280, 0.85× through 450, and 0.75× after that, with tighter line height past 450. Canvas glyphs are clamped at 12px. The body stays in the expanded slot between the header and the watermark so those marks are not pushed outside the card.
- The thumbnail strip under the preview selects a slide, reorders with a horizontal `ReorderableListView`, and can duplicate, delete, or append a page. Edits are written back joined on `\n---\n` and saved to the active draft. The scratchpad reloads its Quill document when that buffer changes from outside the editor.
- Tests: `flutter analyze lib test` clean; `flutter test` 325 passed. New coverage is `test/features/carousel_intelligence_test.dart`.
- Modified: `lib/features/exporter/models/{slide_role,carousel_markdown}.dart`, `lib/features/exporter/templates/card_theme_config.dart`, `lib/features/exporter/presentation/{card_canvas,markdown_card_content,card_exporter_screen,card_inspect_modal}.dart`, `lib/features/exporter/presentation/widgets/slide_thumbnail_strip.dart`, `lib/features/exporter/render/carousel_batch_exporter.dart`, `lib/features/scratchpad/presentation/scratchpad_screen.dart`, `test/features/{carousel_intelligence_test,card_typography_test,carousel_deck_test,card_rasterizer_test}.dart`, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: still add the Google Play RevenueCat public key and register `pro_lifetime` before store purchases.

### 2026-10-05 — Phase 4: Brand kits, font pairings, and CTA QR codes
- `google_fonts` was already at ^8.2.1 (newer than the requested ^6.2.1) and stayed there. Added `qr_flutter` ^4.1.0. QR codes are drawn on device. Font files still come from the existing `google_fonts` cache/fetch, the same way Inter already does.
- `FontPairings` offers Modern Tech (Inter + JetBrains Mono, free), Editorial Authority (Playfair Display + Plus Jakarta Sans), High Impact (Montserrat bold + Open Sans), and Minimalist (Space Grotesk + DM Sans). The last three are Pro. A free tap opens `PaywallBottomSheet`. Headlines use the pairing’s header font; body, handles, and the watermark use the body font. Code stays JetBrains Mono.
- `BrandKit` stores id, name, primary/secondary hex, font pairing id, optional logo path, and aspect ratio. Hive box `brand_kits_box` supports `getAllKits`, `saveKit`, and `deleteKit`. Free accounts can keep one kit; updating that kit is allowed. A second insert without Pro opens the paywall. One tap applies the palette, type, logo, and ratio. Logos are copied into application-support `brand_logos/` and never uploaded.
- CTA slides get a destination field and “Show QR Code on CTA slide”. `QrImageView` sits beside the creator handle. Module color follows the card text color; the quiet zone is an accent-tinted plate. Empty, spaced, and non-http strings show a fallback instead of a code.
- Tests: `flutter analyze lib test` clean; `flutter test` 341 passed. New coverage is `test/features/brand_kits_and_qr_test.dart`.
- Modified: `pubspec.yaml`, `pubspec.lock`, `lib/main.dart`, `lib/features/exporter/models/{font_pairing,brand_kit}.dart`, `lib/features/exporter/storage/{brand_kit_storage,brand_logo_store}.dart`, `lib/features/exporter/state/brand_kit_notifier.dart`, `lib/features/exporter/presentation/widgets/{font_pairing_carousel,brand_kit_carousel,cta_qr_controls,cta_qr_code_widget}.dart`, `lib/features/exporter/presentation/{card_canvas,markdown_card_content,card_exporter_screen,card_inspect_modal}.dart`, `lib/features/exporter/templates/card_theme_config.dart`, `lib/features/exporter/render/carousel_batch_exporter.dart`, `lib/features/paywall/presentation/paywall_bottom_sheet.dart`, `test/features/{brand_kits_and_qr_test,carousel_deck_test}.dart`, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: still add the Google Play RevenueCat public key and register `pro_lifetime` before store purchases. A brand-new font pairing needs a network fetch the first time `google_fonts` has not cached that file.

### 2026-10-05 — Fix mobile viewport crowding
- [x] Fix mobile viewport crowding: Added keyboard dismiss + auto-hide bottom bar in Scratchpad, fixed Card Exporter canvas collapse with pinned hero preview.
- Scratchpad: a tap on empty chrome and a drag on the editor scroll view dismiss the keyboard. The formatting toolbar has a keyboard-hide button on the right edge. While the keyboard is open, the LinkedIn / X / Substack / Card bar and the status strip hide, leaving the compact HUD and formatting toolbar above the keys.
- The platform HUD is one line. The left pill is the active limit (`LinkedIn 120/3000`; tap to cycle X and Threads). The right side is `N words · N min` plus a fold dot (green at or under 210 characters, amber past that). The editor body keeps a 1px fold rule and no longer stacks line-break text under the draft.
- Card exporter is a safe-area column: pinned header (back, title, 1:1 / 9:16), pinned hero preview, and a bouncing scroll view for the control deck. The hero is about 42% of the space under the header for a square card and about 68% for 9:16. The preview is an `AspectRatio` inside `Center` / `FittedBox`, so the 1080px canvas stays proportional. Slide paging stays on the hero. Role, thumbnails, brand kits, font pairings, watermark, photo backdrop, and export actions scroll underneath, with 32px of bottom padding.
- `flutter analyze lib test` clean. Phone-sized widget tests cover keyboard chrome, the dismiss button, drag-to-dismiss, and both card aspect ratios.
- Modified: `lib/features/scratchpad/presentation/{scratchpad_screen,formatting_toolbar}.dart`, `lib/features/scratchpad/presentation/widgets/{platform_counter_hud,linkedin_fold_indicator}.dart`, `lib/features/exporter/presentation/card_exporter_screen.dart`, `test/features/{scratchpad_powerups_test,card_rasterizer_test,card_clipboard_test}.dart`, `docs/ARCHITECTURE.md`, `PROJECT_JOURNAL.md`.
- Follow-up: still add the Google Play RevenueCat public key and register `pro_lifetime` before store purchases.
