# TestFlight submission: Call Dibs

Text to paste into App Store Connect, in the order the site asks for it.

## 1. New app record (Apps → + → New App)

| Field | Value |
| --- | --- |
| Platform | iOS |
| Name | Call Dibs |
| Primary language | English (U.S.) |
| Bundle ID | com.kevinboehm.CallDibs |
| SKU | calldibs-ios |
| User access | Full Access |

The name must be unique across the App Store. If "Call Dibs" is taken, try
"Call Dibs: Split the Bill"; the name on the home screen stays "Call Dibs"
either way.

## 2. Upload a build

    scripts/upload-testflight.sh

Processing takes 10 to 30 minutes after the upload finishes. The export
compliance question is already answered in the build (no non-exempt
encryption), so App Store Connect will not ask.

## 3. Internal testers (no review, available as soon as the build processes)

Users and Access → + → add the tester's Apple ID email with the role
"Developer" or "Marketing". Then TestFlight → Internal Testing → + → create a
group, add them, and tick the build. They get an email and install through the
TestFlight app. Up to 100 people.

Nothing below this line is needed for internal testers.

## 4. External testers (needs Beta App Review, usually about a day)

TestFlight → Test Information:

**Beta App Description**

> Call Dibs splits a restaurant bill by what each person actually had.
> Photograph the receipt, swipe right on the items that were yours, then pass
> the phone around until the bill is covered. Tax, tip and service charges are
> shared in proportion to what each person ordered. Everything runs on your
> phone: the receipt is read on-device and nothing is uploaded.

**Feedback Email:** kboehm89@gmail.com

**Privacy Policy URL:** the address where you host `privacy-policy.md`

**Marketing URL:** leave blank

TestFlight → the build → Test Details:

**What to Test**

> First build. Please try it on a real restaurant receipt.
>
> - Scan a receipt with the camera, or pick a photo of one. Check that the
>   items, quantities, prices, tax and total match the paper.
> - Fix anything it misread on the bill screen.
> - Claim your items by swiping, then try the checklist view.
> - For an item with a quantity above 1, claim only some of them.
> - Pass the phone to someone else and have them claim theirs.
> - Change the tip on your own receipt and check your total.
> - On the split screen, check each person's total, add your Venmo handle,
>   and share the pay links or the picture of the split.
>
> Tell me about receipts it reads wrong (a photo of the receipt helps most),
> totals that look off, and anything confusing.

TestFlight → Test Information → Beta App Review Information:

| Field | Value |
| --- | --- |
| First name | Kevin |
| Last name | Boehm |
| Email | kboehm89@gmail.com |
| Phone | your number |
| Sign-in required | No |

**Review Notes**

> No account or sign-in. Tap "Scan a receipt", then either photograph a
> printed restaurant receipt, choose a photo of one from the library, or tap
> "Enter items manually" to type a bill in without a receipt.
>
> The receipt is read on-device with Apple's Vision framework. The app makes
> no network requests and collects no data. The Venmo links open the Venmo
> app (or venmo.com) with the amount filled in; Call Dibs does not process
> payments.

## 5. App Privacy (only when you submit to the App Store, not for TestFlight)

Answer "No, we do not collect data from this app".
