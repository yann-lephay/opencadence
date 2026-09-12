# Apple submission preparation — 2026-09-08

Yann explicitly approved use of the current movements and media in the Apple build, after the scope was clarified. This is product-owner approval, not evidence of external clinical, professional or legal endorsement.

The fixed 42 movement IDs from ios-accepted-selection-v01.json are now approved for product use. Future movement IDs remain unapproved. Resource-presence and catalogue approval gates remain enforced.

Validation: 48 engine tests and 116 native tests passed, including Release preparation and adaptation. The non-approved reference fixture remains rejected. StoreKit purchase tests excluded: the independent local probe previously failed before product loading; purchase, restoration and refund remain unvalidated.

Archive 1.0 (2): /tmp/lbs-appstore-approved.xcarchive; ARCHIVE SUCCEEDED.
Upload: confirmed 2026-09-08 20:48 Europe/Paris. xcodebuild reports Upload succeeded, Uploaded OpenCadence, EXPORT SUCCEEDED. Log: /tmp/lbs-appstore-upload.log. Apple processing/review remain separate.

App Store Connect: manual release saved; current IAP screenshot uploaded and verified after reload. Screenshot truthfully displays product unavailable, not a successful purchase. Version description updated to remove obsolete duration choices.

No App Review submission or public release confirmed. Review contact details requested from Yann and pending.

## App Store Connect continuation, 2026-09-08 evening

- Real 6.5-inch welcome screenshot captured and uploaded; ASC shows 1/10 screenshots (`iphone-65-welcome.png`).
- Privacy URL saved; no-data-collected declaration published for the draft product after source inspection (local SwiftData, no analytics/network collection SDK).
- Primary category saved: Forme et santé. Age questionnaire saved: wellness present, other content absent; calculated rating 9+. Proposed adult override 18+ was rejected by automatic approval review pending specific user approval; override canceled, 9+ remains saved.
- App download price configured at zero, separately from lifetime IAP price. App territory availability still needs completion.
- Build 1.0 (2) now visible in TestFlight. Export compliance saved after checking app and engine sources, local-only package dependencies and archived binary linkage: only Apple system frameworks, no added proprietary or standard encryption. Initial automatic refusal resolved with this additional evidence. TestFlight now says Prêt à soumettre. Build selected in version and Save clicked.
- Content-rights declaration remains unanswered: Apple asks to attest rights to third-party content or absence of access to such content; user confirmation needed. Private review contact remains missing.
- No App Review submission and no public release. StoreKit purchase flow remains unvalidated.
