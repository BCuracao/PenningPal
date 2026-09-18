# Clean Canvas — Project Journal

## Active State
- **Current Phase**: Phase 4 — Lifetime Paywall (complete)
- **Current Blocker**: None. Replace placeholder RevenueCat public keys and store product IDs before App Store / Play shipping.
- **Target Stack**: Flutter (latest stable), State: Riverpod or Signals, Clipboard: `super_clipboard`, Storage: Hive / SharedPrefs

## Architectural Decision Records (ADRs)
* **ADR-001 (Engine Separation)**: All Markdown-to-Unicode and Markdown-to-HTML transformers must reside in `lib/core/converter/` as pure Dart libraries without Flutter UI framework imports.
* **ADR-002 (Local Persistence)**: User scratchpad auto-saves on every debounce (400ms) locally via Hive. No sync engine needed.
* **ADR-003 (IAP Provider)**: RevenueCat SDK will manage StoreKit and Google Play Billing for the single $4.99 non-consumable product ID (`pro_lifetime`).

## Development Roadmap
- [x] Task 1.1: Initialize Flutter project skeleton and modular directory tree.
- [x] Task 1.2: Implement `UnicodeConverter` with unit tests covering Latin-1, numerals, and nested markdown.
- [x] Task 1.3: Implement `HtmlClipboardService` with dual MIME-type support (`text/html`, `text/plain`).
- [x] Task 2.1: Build minimal markdown scratchpad UI with word/character count indicators.
- [x] Task 2.2: Add one-tap platform export actions (LinkedIn, X, Substack).
- [x] Task 3.1: Implement `CardExportCanvas` with 1:1 and 9:16 aspect ratio templates.
- [x] Task 3.2: Implement image save to gallery (`image_gallery_saver` or native share sheet).
- [x] Task 4.1: Integrate RevenueCat lifetime paywall gate.

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

### 2026-09-18 — Git hygiene + GitHub remote (`socialslate`)
- Hardened root `.gitignore`: Flutter/Dart artifacts (`build/`, `.dart_tool/`, `.flutter-plugins*`, iOS Generated/*, `android/.gradle/`, `local.properties`), secrets (`.env*`, `*.jks`/`*.keystore`/`*.p12`/`*.key`), IDE caches (`.idea/`, `.vscode/`, `*.iml`), while keeping `.cursor/rules/` tracked.
- Initialized Git on `main`, committed project assets (source, tests, docs, Cursor rules), created GitHub remote `socialslate`, pushed `main`.
- Modified: `.gitignore`, `PROJECT_JOURNAL.md`; created remote `origin` → `socialslate`.
- Follow-up: none for VCS; still replace RevenueCat placeholder keys before store shipping.
