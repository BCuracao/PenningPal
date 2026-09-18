# Privacy Policy

**Effective date:** 18 September 2026  
**Product:** PenningPal (the “App”)

PenningPal is a 100% offline, client-side utility. This policy explains what the App does **not** collect, where your content lives, and how in-app purchases are validated.

## 1. Zero server collection

PenningPal does **not** operate an account system, cloud backend, or remote database. There is:

- No account registration or sign-in
- No user profiles stored on a server
- No upload of drafts, images, or clipboard contents to PenningPal
- No PenningPal-operated API that receives your writing

We cannot read, recover, or share your drafts because they never leave your physical device through this App.

## 2. Drafts stay on your device (Hive)

Every scratchpad draft is stored locally on the device you are using, in an on-device Hive box (`drafts_box`). Titles, body text, timestamps, and the active-draft pointer remain on that device only.

Deleting the App, clearing app storage, or wiping the device permanently removes those drafts. PenningPal does not sync, back up, or replicate drafts to any remote service.

## 3. Images stay on your device

Exported social cards and carousel slides are rasterized on-device. PNG files are written to:

- the App’s local temporary cache, and/or
- the device photo library or the system share sheet, **only when you choose Save or Share**

PenningPal does not upload exported images to a server. Once a file is in Photos or another app you picked in the share sheet, that destination’s own privacy terms apply.

## 4. Zero telemetry and analytics

PenningPal includes **no analytics SDK, crash reporter, advertising identifier collection, or tracking pixels**. The App does not measure feature usage, does not fingerprint your device for marketing, and does not send diagnostic events to PenningPal.

## 5. Author profile and settings

Optional card author fields (display name, handle, avatar color) are stored locally in an on-device Hive box (`settings_box`). They are used only to stamp cards you export and are never transmitted by PenningPal.

## 6. In-app purchases (RevenueCat + Apple / Google)

Pro is a **$4.99 one-time, non-consumable, lifetime unlock** (`pro_lifetime`) that removes watermarks and unlocks additional card themes.

Receipt validation is **anonymous** and is handled solely through Apple App Store or Google Play Billing, mediated by RevenueCat. PenningPal does not create an account for this. StoreKit / Play Billing may send a purchase token and anonymous App User ID to Apple, Google, and RevenueCat so the entitlement can be restored on the same store account.

That purchase metadata is **not** linked by PenningPal to your drafts, images, or author profile. If you are offline, previously cached entitlements continue to unlock Pro on that device.

## 7. Permissions

- **Photo library (add / write):** used only when you save a card to Photos.
- **Network:** used only by the operating system and store SDKs for receipt validation and restore. The App does not require a network connection to draft, convert, or export.

## 8. Children

PenningPal does not target children and does not knowingly collect personal data from anyone, including children under 13 (or the equivalent age in your region).

## 9. Changes

If this policy changes, the updated copy ships inside the App under Settings → Privacy Policy. Because the document is bundled as a local asset, you can read it without visiting a website.

## 10. Contact

Questions about this policy can be sent through the App Store / Google Play listing for PenningPal.
