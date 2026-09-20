# PenningPal

<p align="center">
  <img src="assets/icon/app_icon.png" alt="PenningPal icon" width="128" height="128">
</p>

<p align="center">
  <strong>Write markdown once. Ship it to LinkedIn, X, Threads, Substack, and Medium — fully offline.</strong>
</p>

PenningPal is a Flutter iOS and Android app for people who draft in markdown and publish on social platforms. It turns a local scratchpad into Unicode-formatted posts, rich HTML for newsletters, and 1080px social cards — without accounts, cloud sync, or a backend.

The GitHub repository is still named [SocialSlate](https://github.com/BCuracao/SocialSlate); the product name is **PenningPal**.

## Why it exists

Most social networks ignore markdown. Bold, italic, headings, and code either vanish or look messy when you paste. PenningPal keeps a **raw markdown buffer** on device, then converts at export time:

- **LinkedIn, X, and Threads** get Mathematical Alphanumeric Unicode (bold, italic, monospace) plus real line breaks and bullets.
- **Substack and Medium** get dual-MIME clipboard payloads (`text/html` + `text/plain`) so paste keeps headings, emphasis, lists, and code.
- **Cards and carousels** rasterize markdown into square (1080×1080) or story (1080×1920) PNGs, or a swipeable LinkedIn PDF.

The original draft is never rewritten. Screen readers and later edits still see standard markdown.

## Features

### Scratchpad
- Live markdown styling in the editor (headings, bold, italic, quotes, fenced code) while tokens stay in the buffer
- Keyboard formatting toolbar: bold, italic, heading cycle, bullets, quotes, code, and **+ Slide** (`---`) for carousels
- Word, character, and estimated read-time counters
- Auto-save every 400ms to on-device Hive storage
- Multi-draft drawer with search, auto-titling, rename, and swipe-to-delete
- Author name, handle, and brand profiles stamped onto exported cards

### One-tap text export
- LinkedIn copy (Unicode)
- X / Threads copy with 280 / 500 character hints
- Substack / Medium rich paste (HTML + plain fallback)
- Empty drafts never write to the clipboard

### Visual cards
- Square and 9:16 story canvases at a fixed 1080px layout, then rasterized at 3× for sharp PNGs
- Carousels split on markdown thematic breaks (`---`, `***`, `___`)
- Rich card typography: headings, emphasis, blockquotes, lists, inline code — markers never paint on the canvas
- On-device syntax highlighting for fenced code (JetBrains Mono; Atom One Dark / GitHub Light palettes)
- Share, save to Photos, copy PNG to clipboard, pinch-to-zoom inspect
- Batch share/save for multi-slide decks
- LinkedIn multi-page PDF carousels (full-bleed 1080×1080 pages)

### Privacy by design
- 100% client-side. No PenningPal server, no sign-in, no analytics SDK
- Drafts, settings, brand profiles, and photo backdrops stay in local Hive / app support files
- Privacy Policy and Terms of Service ship as bundled assets and open in-app

## Free vs Pro

| | Free | Pro ($4.99 one-time) |
| --- | --- | --- |
| Unlimited markdown drafting and conversion | ✓ | ✓ |
| Clipboard export for LinkedIn, X, Threads, Substack, Medium | ✓ | ✓ |
| Basic card export (Minimal theme) | ✓ | ✓ |
| Remove “Made with PenningPal” watermark | | ✓ |
| Midnight, Terminal, Aurora, Editorial Warm, Neo-Brutalist themes | | ✓ |
| Custom hex / brand colors | | ✓ |
| Custom photo backdrops (blur + contrast scrim) | | ✓ |
| LinkedIn PDF carousels | | ✓ |
| Unlimited ghostwriter / brand profiles | 1 profile | Unlimited |

Pro is a **non-consumable lifetime unlock** (`pro_lifetime`) via RevenueCat + App Store / Google Play. It is not a subscription. Restore Purchases re-applies the entitlement on devices signed into the same store account.

## Stack

- **UI:** Flutter (iOS and Android first), Material 3, Riverpod
- **Transforms:** pure Dart `UnicodeEngine` and `HtmlEngine` (no Flutter imports)
- **Clipboard:** `super_clipboard` (plain, HTML, PNG)
- **Storage:** Hive (`drafts_box`, `settings_box`, `profiles_box`)
- **Export:** `RepaintBoundary` PNG rasterizer, `gal` + `share_plus`, on-device `pdf`
- **IAP:** RevenueCat (`purchases_flutter`)

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for module boundaries and data flow.

## Getting started

Requires [Flutter](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.13.0`).

```bash
git clone https://github.com/BCuracao/SocialSlate.git
cd SocialSlate
flutter pub get
flutter test
flutter run
```

Package IDs are `com.cleancanvas.cleanCanvas` (iOS) and `com.cleancanvas.clean_canvas` (Android). Display names, watermarks, and legal copy use **PenningPal**.

### Tests and analysis

```bash
flutter test
flutter analyze lib test
```

Conversion logic lives under `lib/core/converter/` and is covered by unit tests before UI bindings.

### Store shipping (maintainers)

Before App Store / Play submission, replace placeholder RevenueCat public keys and product IDs in `lib/core/config/revenue_cat_config.dart`, create the `pro_lifetime` product in both stores, attach it to the `pro_access` entitlement, and turn off demo paywall bypass in `lib/core/config/app_config.dart`.

## License

Source in this repository is provided for the PenningPal app. In-app [Privacy Policy](assets/legal/privacy_policy.md) and [Terms of Service](assets/legal/terms_of_service.md) apply to the distributed product.
