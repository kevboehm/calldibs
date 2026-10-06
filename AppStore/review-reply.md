# Reply to App Review (Guideline 2.1, Information Needed)

Paste the text below into the reply in App Store Connect and attach the
screen recording. Then paste the same text into App Review Information →
Notes on the version page, replacing what is there.

---

Hello, and thank you for reviewing Call Dibs. The information you asked for is below, and a screen recording from a physical iPhone is attached.

1. SCREEN RECORDING
Attached. It starts by launching the app and shows the whole flow: scanning a receipt, checking the bill, each person claiming their items, each person's share, the full split, sharing a pay link, and History. The app has no accounts, registration or login, no user-generated content visible to other users, and no paid content, subscriptions or in-app purchases.

2. PURPOSE AND AUDIENCE
Call Dibs splits a restaurant bill by what each person actually ordered. It is for anyone eating out in a group: friends, roommates, coworkers. Splitting a bill evenly is unfair when people ordered different things, and working out each share by hand, with tax and tip, is slow and error-prone. Call Dibs reads the receipt, lets each person pick their items, and gives everyone their exact share with tax, service charges and their own tip included.

3. HOW TO USE IT
No account, login or sample files are needed.
- Tap "Scan a receipt", then "Take a photo" of any printed restaurant receipt, or "Choose from library". To test without a receipt, tap "Enter items manually" and type in a few items and prices.
- Check the items against the receipt (tap Edit to correct anything) and tap "Start calling dibs".
- Enter a name, then swipe right on the items that are yours and left on the ones that aren't. Tap Review to see that person's share and set their tip.
- Tap "Pass to the next person" and repeat, or "That's everyone" to see the full split.
- On the split screen, "Add how you get paid" takes a Venmo, Cash App or PayPal username (any text works for testing). Each person then has a "Send link" button that opens the share sheet.
- Tap Done to finish. The split is kept under History on the home screen.

4. EXTERNAL SERVICES
None. The app has no backend, makes no network requests, and contains no third-party SDKs, analytics or advertising.
- Receipt text is recognized on the device with Apple's Vision framework.
- When a scan doesn't add up to the receipt's printed total, the app may ask Apple's on-device language model (the Foundation Models framework, where Apple Intelligence is available and switched on) for a second reading. This runs entirely on the device, and no third-party AI service is used.
- Payment processing: none. Call Dibs does not move, hold or process money. It only builds a standard public link (venmo.com, cash.app or paypal.me) containing the payer's own username and an amount, which the user shares or opens. Any payment happens in that separate app, between the users.

5. REGIONAL DIFFERENCES
The app works the same way in every region. Two details follow the currency printed on the receipt rather than the user's location: the Venmo, Cash App and PayPal links are offered only for bills in US dollars, since those services pay in dollars (other bills share the amounts without links); and the suggested tip starts at 20% for bills in US or Canadian dollars and at 0% for other currencies, where the user can still add one. The app is in English.

6. REGULATED INDUSTRY OR THIRD-PARTY MATERIAL
Not applicable. Call Dibs is a calculator: it is not a financial service and does not process payments or hold funds. It contains no protected third-party material. Venmo, Cash App and PayPal are named only to identify the user's own payment app.

Thank you,
Kevin Boehm
kboehm89+calldibs@gmail.com
