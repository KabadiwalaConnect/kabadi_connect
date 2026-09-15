# Collector v2 phone acceptance â€” Checkpoint84

All phone cases below are **NOT TESTED** until performed on your actual app. Automated results are in VALIDATION_REPORT.md, not a substitute for these cases.

Use only disposable test transactions. Do not clear an unlinked guest's data to test recovery. Verify the exact Auth UID privately; do not post UID/contact screenshots publicly.

## Installation and account

1. Installer `-CheckOnly` passes with correct project; unexpected main pattern stops without changing files.
2. Timestamped backup contains the actual previous main/source/pubspec files.
3. Same welcome artwork/timing for a fresh session; returning collector goes directly to Home.
4. Existing session, profile and lots retain the exact UID after install/restart. No repeat name entry or new anonymous account.
5. Missing cached profile while offline shows a check/retry state, not fresh-account success.
6. Missing/malformed/server-denied profile never silently overwrites data or changes role.
7. Optional email link on disposable guest preserves UID and profile/lots. Existing email on another account refuses merge/switch.
8. Verify linked account recovery on a separate test installation/device; mobile contact alone does not restore an account.
9. Simulate Auth link success but profile update failure: do not relink/switch; verify Save profile repairs email metadata after reconnect.

## Layout / voice / language

10. All collector routes have identical artwork/slogan/skyline/footer; welcome itself is unchanged.
11. Home tiles visibly select dark green; camera is circular; Home/Messages remain legible at 320px width and large text.
12. EN/HI/MR switches labels and general guidance; on returning Home its bottom navigation updates too.
13. Speaker mute persists; hold to replay; no text box repeating spoken guidance. Actual safety/consent/errors remain visible.
14. Camera/gallery/menu/selection/submit controls give spoken feedback; no private email/password/phone/reference is read aloud.

## Local drafts / photos / sync

15. Save an incomplete local draft; restart normally; draft remains under the same UID.
16. Take a photo and Save; restart; real local photo still loads, not a category illustration.
17. Camera permission denial/gallery cancel/storage failure returns a truthful error or unchanged draft.
18. Kill process during camera on a disposable test draft, reopen that SAME draft and test lost-image recovery.
19. No-photo/unconfirmed-material/NaN/infinite/zero/negative/over10000kg draft cannot be queued as a valid lot.
20. Queue in airplane mode: local record survives; no cloud/offer success is claimed. Reconnect and retry: one stable cloud lot, not duplicates.
21. Timeout/restart/retry produces one lot revision. Unsynced concurrent edits are preserved or shown as conflict, not silently overwritten.
22. Two devices edit same synced draft: optimistic revision conflict prevents stale overwrite. Resolve by reviewing cloud version and explicit local metadata replacement.
23. Offered/reserved/archived lots refuse metadata sync edits. Cloud archive is not account deletion and does not unlock an offer.
24. Local photo path/bytes never appear in Firestore offer/profile/lot documents; photos are device-only and not implied backed up.

## Directory / prices

25. Exactly one imported directory entry, phone has no `.0`, address and regional-office fields shown separately. No fake verified badge/distance/pickup promise/live offer.
26. Search and local saved contact persist; call/email open external apps or show a clear unavailable message.
27. Price asset loads, source date displayed, city/material calculation correct. No INR/live-source assumption; invalid/missing inputs do not show misleading valuations.

## Marketplace / handover / ledger

28. No published demand yields an honest empty state. Real request query works with new rules/indexes.
29. Tap lot card/photo: selects only, does not submit. Send only selected synced matching lot; cache/pending/busy/duplicate states block unsafe submit.
30. Successful send creates one v2 proposal and locks the whole lot atomically. No second live offer on same lot.
31. Recycler UI is pending tomorrow. Once connected, ONLY target verified recycler quote/reject appears as an actual response; collector cannot simulate it.
32. Collector accepts a nonexpired quote from still-verified buyer; lot reserves. Withdrawal/rejection before acceptance releases it atomically.
33. QR is an identifier only. Request handover after checking actual scale weight; collector cannot mark completed. Recycler explicit completion updates both offer and lot.
34. Before completed handover, receipt creation fails. After completion, record only actual received money; no automatic payment or bank verification appears.
35. Receipt network timeout/restart: retry same journal from Sync, no duplicate entry. A conflicting new pending entry for same offer is blocked.
36. Receipt statements are immutable; copy clearly labels not-bank-verified/not-tax-invoice. Ledger totals explicitly apply to newest100 loaded receipts, not lifetime income.
37. Legacy offers remain read-only and are not incorrectly marked reserved/accepted/paid.

## Required before real-world deployment

Build recycler publisher/inbox/scanner, real authorization review/provenance, handover correction/dispute/accepted-cancellation paths, safe photo sharing/backup if required, financial reconciliation, robust pagination and monitoring. Passing these demo cases does not certify regulatory compliance or production security.

Report format:

```text
Case number:
PASS / FAIL / BLOCKED:
Expected:
Actual:
Relevant error code (no private credentials):
```
