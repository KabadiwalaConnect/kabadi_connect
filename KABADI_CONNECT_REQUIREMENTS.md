# KabadiConnect — Requirements & Proposed Implementation

Checkpoint 02 — 2026-09-08
Status: User requirements captured; architecture proposals and open decisions NOT yet approved. No custom implementation performed.

## Product
Android Flutter app for SIH.
Tagline: An Offline-First Digital Bridge Between Informal E-Waste Collectors and Authorized Recyclers.
Core proposition: FAIR VALUE → BEST OFFER → VERIFIED HANDOVER.
Roles: informal collectors, authorized recyclers/aggregators, platform administrator.
Languages: Hindi and Marathi. Low-literacy interface: large touch targets, prominent icons, minimal text, one primary action per screen, spoken guidance.

## Required collector home
1. Sell E-Waste (dominant action)
2. Today's Price
3. Find Recycler
4. My Earnings
5. Safety
Additional proposed small status controls: language, audio, offline/sync status and profile. Visual styling needs approval; no screenshot/Figma reference supplied.

## MVP checklist (all required by user)
- [ ] Collector registration/profile
- [ ] Hindi/Marathi interface
- [ ] Photo-based material classification
- [ ] Material/weight entry
- [ ] Price board
- [ ] Fair-value calculation
- [ ] Recycler database
- [ ] Authorized recycler filtering
- [ ] Recycler offer comparison
- [ ] Lot creation
- [ ] QR/unique Lot ID
- [ ] Recycler-side interface
- [ ] Handover confirmation
- [ ] Payment/earnings ledger
- [ ] Digital transaction record
- [ ] Offline lot creation and synchronization
- [ ] Safety guidance

## Collector flow
Photo/material identification → weight/condition → fair-value range → compare offers → choose recycler → lot/QR → pickup/handover → scan + photo + actual weight → both parties confirm → payment recorded → ledger and receipt.
Proposed clarification: create a LOCAL DRAFT early, then submit/commit a lot after offer selection. Offline users must also be able to save a lot without live offers. Final versus draft terminology to approve.

## Demo acceptance journey
8 kg PCB → photo classification → fair-value range → authorization-aware offers → Recycler B recommended if actual scoring supports it → lot reference → recycler scans → both confirm → payment recorded → receipt/dashboard.
AI confidence must come from actual model output, not a hardcoded 87%. Any sample offers, rates, recycler profiles, simulated payment or staged model output must be explicitly labeled demo data. Handover verification does not prove downstream recycling completion.

## Data requirements
- Material catalog: category/subcategory, description, reference image. Lot-specific photo, weight, condition and source belong to lot records.
- Prices: material, location, timestamp, buying/quoted rates, unit, recycler, history, provenance and validity.
- Recyclers: name, facility, accepted materials, authorization evidence/status/validity, rates, pickup, service area.
- Transactions: lot, collector, recycler, quoted/final weights and rates, final total, timestamps, payment and transaction status.
- Traceability: photo, weight, timestamps, optional consented GPS, handover reference, separate actor confirmations, subsequent status events.
- Additional proposed entities: profiles/roles, offers, payment acknowledgements, immutable audit events, synchronization outbox.

## Matching rules
User weights: authorization 30%, material compatibility 25%, price 25%, distance 10%, pickup 10%.
Proposed mandatory eligibility filters BEFORE scoring: valid verified authorization for the relevant material, material compatibility, service area. A high price must never compensate for missing authorization.
Normalize score inputs to 0..1; weighted total to 100. Eligible profiles may all receive the full authorization/material points. Missing location must be shown, not invented. Price normalization and pickup preferences need definition.

## Offline contract
Offline: photo capture, material/weight entry, local drafts/lots/records, cached prices/recycler data with last-sync timestamps, safety guidance.
Offline must not imply live offer freshness, current authorization or server-verified settlement.
Proposed: SQLite persistent local store + local photo files + persistent outbox. Sync uses authenticated server API, idempotency keys, retry/backoff, version checks and upload completion state. App-open/resume and explicit Sync trigger initially; background sync later. Preserve original offline records and detect conflicting edits.
Offline handover confirmations remain pending reconciliation; do not label server-verified until both authenticated parties' matching confirmations are accepted.
Use UUIDs as canonical offline-safe IDs; readable references may follow LOT-KC-2026-XXXXXX with server-side uniqueness handling. QR contains an opaque reference/token, not sensitive profile information; QR alone is not proof of handover.

## Proposed architecture — approval pending
- One Flutter Android codebase with role-specific collector/recycler/admin screens for MVP.
- Feature-based folders with UI, domain logic, repositories and local/remote data layers.
- SQLite for offline data; one state management approach selected after architecture approval.
- Supabase/PostgreSQL backend is a candidate, not selected. Authentication + server-enforced role/row policies + private photo storage. No admin/service secrets in the app.
- Real sync demo requires two clients and a shared backend; role switching on one phone alone is insufficient to demonstrate cross-user synchronization.
- Add native dependencies one at a time, build/test each, retain checkpoint/lockfile.

## AI scope conflict requiring decision
User lists AI-assisted classification as Phase 2+ but also requires photo classification in MVP and a confidence-based SIH demo.
Options: real offline model (requires labeled data/model assets and preprocessing details); real online model (classification not offline); explicitly labeled mock UI before integrating real classifier. Manual correction required; low confidence must not force classification. No model or dataset supplied yet.
AI price estimation, anomaly detection, pickup clustering, route optimization and prediction remain later features.

## Payment & authorization boundaries
Initial proposal: record cash/UPI payment evidence and collector receipt acknowledgement, not move money. Actual payment integration needs provider credentials/webhooks and is a separate choice.
Authorization needs genuine evidence checked against appropriate official sources and tracked validity; demo profiles must not imply real authorization.
Fair-value engine initially transparent weight × sourced rate range with condition/grade assumptions. It is indicative, not guaranteed payout; real-time official rate claims require actual sources.
Safety guidance must avoid hazardous dismantling instructions; reviewed multilingual guidance and emergency cautions needed.

## Proposed stages with tests
1. Approve flows, visual direction, role setup and demo boundaries.
2. UI + localization + navigation using explicit demo data; test on phone.
3. Local database, profile, photos, material/weight, offline lot creation and restart persistence.
4. Price/ranking engines with sample-data labels and unit tests.
5. Backend/auth, role enforcement, offers and retry-safe two-device sync.
6. QR, handover confirmations, payment acknowledgement, ledger/receipt; test duplicate scans and disputed weights.
7. Real classifier integration and evaluation; manual fallback.
8. Safety/audio refinement, accessibility/offline failures, SIH demo rehearsal.
Spoken prompts can be bundled recordings for reliable offline guidance; offline TTS availability depends on installed language voices. Speech recognition is not assumed to work offline.

## Open questions
1. Visual reference/Figma available or should assistant design based on written principles?
2. Must first demo have real offline AI? Any existing .tflite model, labels, dataset?
3. Approve one role-based app and a real shared backend? Existing hosting preference/account?
4. SIH deadline, second Android device availability, initial geographic market and demo-vs-real data/payment expectations?

## Latest checkpoint
Requirements recorded only. Next: resolve key questions, approve MVP/design, then implement the first small UI milestone. Do not claim features completed until tested.

## Checkpoint 03 — Welcome visual reference
User supplied screenshot reference and requested welcome screen first. Cream background, leaf logo, Kabadiwalla Connect display name, Behtar Kal Saaf Kal subtitle, friendly collector/cart illustration, green Hindi Start button, Hindi footer. Close recreation delivered as standalone Flutter source/assets package with original generated illustration. Exact original art/font unavailable. Functional next-screen placeholder only. Implementation and phone appearance not verified yet. Remaining scope questions still open.
