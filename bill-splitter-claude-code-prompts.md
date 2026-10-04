# Bill Splitter iOS App: Claude Code Prompt Set

A sequence of copy-pasteable prompts to build the app with Claude Code.
Give Prompt 0 first (context), then work through the prompts in order.
Review and test after each step before moving on.

---

## Prompt 0: Project context (paste this first)

```
I'm building a native iOS app that splits a restaurant bill. Here's the full concept. Keep it in mind for everything that follows.

CORE IDEA
A user photographs a restaurant receipt, the app reads the line items, the user claims which items are theirs, and the app outputs exactly how much they owe. Payment happens out of band (Venmo etc.). The app does NOT process payments.

MVP SCOPE (build this first)
- Single user, single device. No accounts, no backend, no groups yet.
- Flow: upload/capture receipt photo -> parse line items -> claim items -> confirm "mini receipt" -> done.

ITEM CLAIMING: two interchangeable modes over the same underlying data:
1. Swipe mode (Tinder-style): one item at a time, swipe left = not mine, right = mine.
2. Checklist mode: whole bill shown at once, tap to toggle items as mine.
The user chooses the mode based on how much of the bill is theirs (swipe for low coverage, checklist for high coverage). Both modes write to the same claim state; they are two front-ends over one data model.

QUANTITY HANDLING
- Special quantity UX appears ONLY when a line item's quantity > 1.
- For single-unit items, claiming is instant (one tap / one swipe).
- For multi-unit items (e.g. 10 burgers, I had 3), use a deliberate UX (e.g. a stepper) so the user never inadvertently claims 1 when they had several. A little extra friction here is acceptable and desired. Exact interaction TBD. Make it a clean, swappable component.

TAX
- Pull the EXACT tax amount from its own line item on the receipt. Do not estimate a percentage.
- Allocate tax proportionally to each person's claimed subtotal.

TIP
- Not on the receipt. Default to 20%, calculated on the POST-TAX total.
- Make the tip rate adjustable by the user. Make the tip base (post-tax vs pre-tax) a single config point so it's easy to change later.

MINI RECEIPT (confirmation step)
- Shows the user's claimed items, their subtotal, their share of tax, and their tip, broken out so it's clear how the total is composed.

FUTURE (do NOT build now, but keep the architecture open to it)
- Groups: multiple people join a session; items get assigned to specific people.
- Fractional attribution: split a single item across people (e.g. a bottle of wine 50/50). This depends on groups existing.

TECH PREFERENCES
- Native iOS, Swift + SwiftUI.
- Use Apple's Vision framework (VNRecognizeTextRequest) for on-device OCR in the MVP, no third-party OCR service.
- Keep the receipt-parsing layer isolated behind a protocol so the OCR/parsing implementation can be swapped later.

Confirm you understand the scope, then wait for my next prompt before writing code.
```

---

## Prompt 1: Scaffold

```
Scaffold the Xcode project.

- Swift + SwiftUI, iOS 17+ target, single app target named "TabSplit" (or suggest a better name).
- Set up a clean folder structure: Models, Services (OCR/parsing), ViewModels, Views, Utilities.
- Add a simple app entry point with a placeholder home screen that has a single "Scan a receipt" button.
- No third-party dependencies yet.

Give me the file tree and the key files. Explain how to open and run it.
```

---

## Prompt 2: Data model

```
Define the core data model. This is the foundation. Both claim UIs and the mini receipt read from it, so get it right before any UI.

Model these:
- LineItem: id, name, unitPrice, quantity (Int), and a claimedQuantity (Int, 0...quantity) representing how many units the current user has claimed.
- Receipt: id, an array of LineItem, the exact tax amount (Decimal) read from the receipt, an optional pre-tax subtotal, and the receipt total.
- A derived "ShareSummary" (the mini receipt): the user's claimed items, their claimed subtotal, their proportional share of tax, the tip, and their final total.

Rules to implement as pure functions (easy to unit-test):
- claimedSubtotal = sum of (unitPrice * claimedQuantity) across items.
- taxShare = receipt.tax * (claimedSubtotal / receiptPreTaxSubtotal).
- tip = (claimedSubtotal + taxShare) * tipRate, tipRate defaulting to 0.20. Keep the tip BASE (post-tax) as a single configurable value.
- finalTotal = claimedSubtotal + taxShare + tip.

Use Decimal for all money math, never Double. Add unit tests covering single-unit claims, multi-unit partial claims, and the tax proportion. Keep this layer UI-free.
```

---

## Prompt 3: Receipt scanning / parsing

```
Build the receipt capture + parsing layer behind a protocol so it can be swapped later.

- Define a protocol ReceiptParser { func parse(image: UIImage) async throws -> Receipt }.
- Provide a VisionReceiptParser implementation using Apple's Vision framework (VNRecognizeTextRequest) for on-device OCR.
- Parse recognized text lines into LineItems (name, quantity, unit price) and detect the tax line and total. Handle common receipt quirks: quantity prefixes (e.g. "2 Burger"), prices at line end, a "Tax"/"Sales Tax" line, a "Total"/"Subtotal" line.
- Where parsing is ambiguous, return best-effort results; the user will confirm/edit on the next screen.
- Add camera capture + photo library picker for the image.
- Include a "manual edit" fallback: after parse, show the parsed items in an editable list so the user can fix OCR mistakes before claiming.

Note the parsing accuracy is the hardest part. Keep it isolated and testable, and log the raw OCR output in debug builds so I can tune it.
```

---

## Prompt 4: Claim views (the two modes)

```
Build the two item-claiming UIs. Both read and write the SAME claim state (claimedQuantity on each LineItem) via a shared ViewModel; they are two front-ends over one model.

SWIPE MODE:
- Card stack, one LineItem at a time. Swipe right = claim, left = skip.
- If quantity == 1: a swipe claims the whole item instantly.
- If quantity > 1: before completing the claim, present a stepper (1...quantity) so the user picks how many units are theirs. Make this deliberate so they can't accidentally claim 1 when they had several.

CHECKLIST MODE:
- The whole bill as a tappable list. Tap toggles an item as mine.
- quantity == 1: tap toggles claimed on/off.
- quantity > 1: tapping reveals an inline stepper (0...quantity) for the claimed count.

- Let the user switch between modes at any time without losing claim state.
- Factor the multi-unit quantity picker into ONE reusable component used by both modes.
```

---

## Prompt 5: Mini receipt + finish

```
Build the confirmation screen (the "mini receipt") and wire up the full flow.

MINI RECEIPT:
- Show the user's claimed items (with claimed quantity and line totals).
- Show, broken out: claimed subtotal, tax share, tip, and final total, so it's clear how the total is composed.
- Tip control: editable tip rate, default 20%, calculated on the post-tax total. Show the resulting tip amount live.
- A clear headline number: "You owe $X".

FLOW:
- Wire home -> capture/parse -> edit-parsed-items -> choose claim mode -> claim -> mini receipt.
- On the mini receipt, a "Copy amount" / share-sheet action so the user can send the number to whoever they're paying (out-of-band payment).

Keep everything driven by the pure functions from the data-model step.
```

---

## Notes for later phases (don't build yet)

- **Groups:** introduce a Person entity and let claims belong to a personId; a session holds multiple people. The current single-user flow becomes "a session with one person."
- **Fractional attribution:** once claims are per-person, allow a claim to hold a fraction of a unit (e.g. 0.5) so a bottle of wine can be split. Keep the money math in Decimal to handle this cleanly.
