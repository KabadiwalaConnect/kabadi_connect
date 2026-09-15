# Recycler integration contract â€” after Collector v2 / Checkpoint84

This is a technical handoff, NOT a working recycler UI, verification grant or permission to bypass rules. The supplied datasheet has one unreviewed directory entry and no linked Firebase UID, validity date or independent authorization source. Do not create a fake verified user from it.

## Account / authorization

- Keep the collector's current UID/role intact. Use a separate recycler account/device or recoverable account setup; do not toggle the collector's saved role to test.
- New recycler registration remains `authorizationStatus: pending`.
- A trusted admin must review genuine current authorization and relevant categories before assigning `verified`. Client profile updates cannot change role/authorization.
- Collector directory contacts are local source records only. They are not the `users/{recyclerUid}` document and are not buying requests.
- Collectors cannot directly read buyer private profile documents. Their send/accept transactions rely on current-authorization checks in security rules. Do not reintroduce forbidden private-profile reads.

## Buying requests

Path: `recyclerRequests/{requestId}`.

Required for current collector consumption:

```text
recyclerUid         actual recycler Auth UID
recyclerName        accurate business display snapshot
city                one of the app's current supported cities
material            Copper / Aluminium / Iron / PCB / Battery / CRT / LCD / Cable / Motor
status              active
authorizationStatus verified (publication snapshot; not sufficient by itself)
expiresAt           Firestore Timestamp in the future
pricePerKg          optional real numeric indicative rate
currency            INR if pricePerKg is an INR rate
```

**Current client create/update/delete is denied.** Only trusted admin publication is supported today. Tomorrow implement a verified-recycler publisher with strict schema, ownership, expiry and snapshot rules; do not broadly enable all authenticated writes. Publish only actual buyer demand, not manufactured directory-derived demand.

Collector request view loads up to50 active verified-snapshot requests, then applies local city/expiry filters. Current authorization is checked again at proposal creation. Future inbox/publisher queries must be validated with emulator tests and matching indexes.

## V2 proposal

`recyclerRequests/{rid}/offers/{collectorUid}_{lotId}`:

```text
schemaVersion: 2
collectorUid, lotId, material, weightKg
status: proposed
createdAt: serverTimestamp
requestId: rid
recyclerUid, recyclerName, city: exact request snapshots
```

Atomic paired lot update:

```text
users/{collectorUid}/lots/{lotId}
status: offered
activeRequestId: rid
activeOfferId: offer document ID
updatedAt: serverTimestamp
```

A proposal without its paired lock, or a lock without its proposal, is denied. Same lot cannot support two concurrent active offers. Deterministic IDs prevent duplicate creation for the same request/lot pair. Legacy offers without schemaVersion2 are readable but read-only; migration is a separate audited operation, not an implied UI upgrade.

## Recycler actions permitted by current rules

Only the verified recycler owning the request can act. Use transactions/batches and read fresh state; do not trust QR/UI snapshots.

### Quote

From `proposed`, update offer only:

```text
status: quoted
quoteRate: positive finite INR per kg, <= 10000000
quoteCurrency: INR
quoteExpiresAt: Timestamp > request.time, <= request.time + 7 days
quotedAt: serverTimestamp
```

No mutation of collector weight/material/identity is permitted. Initial implementation supports one quote, not arbitrary counteroffer/revision history.

### Reject

From `proposed` or `quoted`, atomically:

```text
offer: status rejected, rejectedAt serverTimestamp
lot: status draft, activeRequestId '', activeOfferId '', updatedAt serverTimestamp
```

### Collector acceptance (already implemented)

A valid nonexpired quote from a currently verified buyer is accepted atomically:

```text
offer: status accepted, acceptedAt serverTimestamp
lot: status reserved, updatedAt serverTimestamp
```

Collector withdrawal is allowed only before acceptance and must release the lot atomically. Accepted-order cancellation/dispute/refund workflow is not yet implemented.

### Handover request (collector implemented)

From `accepted`:

```text
status: handoverPending
handoverWeightKg: >0 and <=10000
handoverRequestedAt: serverTimestamp
```

This is the collector's scale-weight statement. It is not automatically a mutually confirmed handover.

### Handover confirmation (recycler UI needed)

From `handoverPending`, after physically reviewing weight and goods, atomically:

```text
offer: status completed, completedAt serverTimestamp
lot: status handedOver, updatedAt serverTimestamp
```

Recycler cannot change the reported weight as part of completion. Corrections/disputes need a separately designed workflow; do not silently overwrite the collector's statement. Completion is proof of these two authenticated app actions, NOT certification of final recycling/regulatory compliance.

## QR

Payload: `KC2|{requestId}|{offerId}`.

- Identifier only, not a secret credential or payment code.
- Parse the exact three-part versioned payload, validate IDs, then fetch the offer under the signed-in recycler's own authorized request.
- Never execute a raw path/URL from an arbitrary QR or bypass Auth.
- Scanning/replaying the QR must not itself submit completion. Show current goods/weight/quote and require explicit real recipient confirmation.
- Current collector implementation generates QR; recycler scanner UI is not delivered.

## Photos

Collector photos remain in app-private device storage and are never uploaded in this free/contact-only build. Receiver cannot load them from Firestore. `photoStorage: deviceOnly` is an honest declaration, not an image URL or evidence proof. Cloud photo storage, consent/access rules, retention and costs must be approved and implemented separately.

## Payments

`collectorPayments/{id}` stores only the collector's statement of an actual received amount:

```text
collectorUid, requestId, offerId
amount >0, <=100000000
currency INR
method cash / upi / bank
reference String <=100
kind collectorRecordedReceipt
createdAt serverTimestamp
```

Requires a completed v2 handover belonging to the collector. Client update/delete is denied. No bankVerified field, payment initiation, gateway key, payout status or fabricated receipt is supported. A receipt is not a tax invoice. Partial/multiple receipts can be recorded, so never infer full payment merely from the presence of one record. Ledger currently shows newest100 account receipts, not a full reconciliation engine.

Future payment/recycler acknowledgements require separate rules and tests; do not let a buyer mark collector receipts as bank-verified.

## Required next acceptance tests

1. Separate legitimate recycler account remains pending until genuine admin review.
2. Verified buyer inbox only lists its own requests/offers; other buyer and collector access is denied.
3. Publisher validates source, expiry, ownership, categories and supported city; no arbitrary verified claims.
4. Real buyer quote appears in collector My Offers without manual fake collector writes.
5. Collector accept reserves lot; second buyer/request cannot reserve it.
6. Offline/stale/revoked buyer states cannot complete sensitive transitions.
7. QR fetches only authorized current record; explicit physical-confirmation action completes paired offer/lot update.
8. Collector records actually received money; no simulated bank verification.
9. Add correction, cancellation/dispute, administrative exception handling and robust pagination before production use.

Existing emulator tests are in `security-tests/rules.test.mjs`. They seed fictional fixtures with rules disabled ONLY inside the isolated local demo emulator. Never use that seeding pattern against production.
