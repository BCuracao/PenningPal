# Clean Canvas — Architecture Specification

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
│   │   ├── presentation/       # Scratchpad UI, action bars, counters
│   │   └── state/              # Editor state, undo/redo, debouncing
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
      └──> [ Card Exporter ]  ──> [ RepaintBoundary ]   ──> Image Rasterizer ──> Native Share
```

---

## 4. Module Boundaries & Responsibilities

### 4.1. Formatting Engine (`lib/core/converter/`)
* Operates strictly on raw strings.
* Does not import `package:flutter/*` (only `dart:core`).
* Maintains lookup tables for UTF-16 surrogate pairs representing Mathematical Alphanumeric Unicode symbols.
* Implements fallback rules so unsupported characters (symbols, punctuation, non-Latin alphabets) bypass conversion safely without throwing exceptions.

### 4.2. Local Storage (`lib/core/persistence/`)
* Single Hive box (`drafts_box`) storing lightweight documents:
  ```dart
  class Draft {
    final String id;
    final String content;
    final DateTime updatedAt;
  }
  ```
* UI updates are non-blocking: writes run asynchronously on a 400ms debounce timer.

### 4.3. Visual Card Exporter (`lib/features/exporter/`)
* **Off-Screen Rendering**: Cards are rendered in an off-screen widget tree attached to a detached `RenderRepaintBoundary` or via an invisible overlay.
* **Canvas Output Dimensions**:
  * Square: 1080 × 1080 px
  * Vertical: 1080 × 1920 px
* **Rasterization Process**: Card widgets are scaled using `Transform.scale` to ensure consistent rendering metrics regardless of physical device DPI, rasterized to `dart:ui.Image`, and converted to PNG byte arrays.

### 4.4. Entitlement Gating (`lib/features/paywall/`)
* State tracked via a single reactive boolean: `isProPurchased`.
* Checks RevenueCat cache on launch (`CustomerInfo.entitlements['pro_access']?.isActive`).
* Hard enforcement: The export render pipeline intercepts attempts to rasterize custom themes or strip watermarks if `isProPurchased == false`.