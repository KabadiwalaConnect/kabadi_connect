# Collector v2 â€” Integrated build / Checkpoint 84

**Name + mobile contact, same saved account, shared collector artwork/footer. No OTP, AI, cloud photo upload or real payment processing is enabled.**

This is a coordinated collector-side implementation, not a claim that every production requirement is finished. Recycler-side UI/publishing is the next delivery. Real quotes and confirmed handovers need an actual authorized recycler account using its own permitted actions. Empty demand/offers/receipts stay honestly empty.

## Easiest installation â€” one readable script, no ZIP

Download **[INSTALL_COLLECTOR.ps1](INSTALL_COLLECTOR.ps1)**. It contains the complete individual source files as readable text, not an encrypted payload. You do not need to download every Dart file separately if using it.

Before running: save your work and stop `flutter run`. **Do not uninstall or clear app data. Your current UID and records must stay intact.**

### 1. Check only (changes nothing)

In PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\INSTALL_COLLECTOR.ps1" -ProjectPath "D:\FlutterProjects\kabadi_connect" -CheckOnly
```

Change the Downloads path if you saved the script elsewhere. The execution-policy option applies only to this PowerShell invocation; the script does not change the machine policy.

The script checks required source/assets and recognizes the existing `home: WelcomeScreen()` / `home: const WelcomeScreen()` expression in your actual main.dart. It wraps that exact existing widget in `CollectorSessionGate`, preserving the rest of main.dart, Firebase initialization, language loading and welcome implementation/timing/artwork. It does not generate a guessed replacement welcome.

**If it says main.dart is not recognized, stop and send the actual main.dart. It stops before changing files.** A pre-existing gate from this installer is accepted on repeat runs. The actual laptop main.dart was not supplied, so this compatibility check is important.

### 2. Install after the check passes

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\INSTALL_COLLECTOR.ps1" -ProjectPath "D:\FlutterProjects\kabadi_connect"
```

The script:
- Backs up files it will replace plus main.dart/pubspec/pubspec.lock into a timestamped `collector_backup_...` folder inside the project.
- Writes complete files to the correct `lib`, `test` and setup locations.
- Adds four packages using `flutter pub add`: sqflite, path_provider, qr_flutter, url_launcher, with tested compatible version constraints.
- Does **not** delete accounts/data, sign out, clear phone storage, uninstall, deploy Firebase rules, alter Android configuration, enable billing, or turn AI on.
- Does **not** replace your current app_language.dart, language_screen.dart, role_selection_screen.dart, firebase_options.dart, artwork or price dataset.

If package resolution fails, source backup still exists. Share the error; do not start changing Gradle/Android versions blindly. `-SkipPackages` is available for an offline source-only install, but you must resolve the packages before running the app.

### 3. Publish the matching rules

The script writes this file to your project root:

**[firestore_collector.rules](firestore_collector.rules)**

Firebase Console â†’ correct project `kabadiconnect-ad86b` â†’ Firestore Database â†’ Rules:
1. Back up the actual published rules.
2. Compare any independently added collections/policies before replacing. These rules cover the known app schema, not unknown local additions.
3. Paste the complete new rules file and Publish.

**Do not publish the older name/mobile or My Offers rules for this v2 client.** V2 offers reserve a lot atomically, and the rules must match. Legacy offer documents are read-only; old clients' six-field offer writes are intentionally not permitted under v2.

No recycler from the JSON is automatically inserted into Authentication/users or assigned verified status.

### 4. Add/keep these indexes and wait for Enabled

Firestore â†’ Indexes â†’ Composite:

| Collection ID | Query scope | Fields |
|---|---|---|
| offers | Collection group | collectorUid Ascending, createdAt Descending |
| collectorPayments | Collection | collectorUid Ascending, createdAt Descending |

Keep the existing offers index if it already matches. Do not remove unrelated indexes. Exact definitions: [firestore_collector.indexes.json](firestore_collector.indexes.json).

The installer does not change firebase.json or automatically deploy indexes. For beginners, Console creation avoids accidentally deploying an old rules file referenced by an existing firebase.json.

### 5. Authentication

- **Anonymous remains enabled** for name + mobile-contact registration.
- Returning normal sessions should now go straight to Collector Home, without repeatedly entering name/mobile.
- Optional recovery: enable **Email/Password** in Firebase Authentication. From Profile & recovery, the current guest can explicitly link their own email/password to the SAME UID. This is not a new account or automatic account merge.
- Email recovery remains optional. No real SMS/Phone provider is required or activated.
- After linking, a fresh installation can use **Recover linked email account** on the registration screen. A currently signed-in account is not silently switched.
- Losing an unlinked guest session can still lose access. Local photos do not become cloud backups simply because email recovery is linked.

### 6. Analyze, test, run

```powershell
cd D:\FlutterProjects\kabadi_connect
flutter analyze
flutter test test/widget_test.dart
flutter run
```

Use a full restart, not just hot reload, after adding native plugins. Do not run routine `flutter clean`/uninstall/data wipes as a login or sync fix.

The supplied widget_test.dart replaces the obsolete starter test with **11 input/weight tests**. If you added your own tests, preserve/adapt them from the backup. Other unrelated files in the laptop project can still produce analyzer findings; share the actual output rather than assuming the entire laptop tree equals the validation harness.

## What is implemented

| Area | Collector implementation and boundary |
|---|---|
| Startup | Existing session/profile routing; new users keep original welcome/onboarding. Missing or denied profiles show review/retry, not a silent new UID. |
| Shared UI | One CollectorPage frame for every collector route: same artwork, 45:55 slogan layout, skyline/footer, bold type, speaker controls. Scrollable bodies, circular camera and large Home/Messages navigation. |
| Lots | Local draft editor, real camera/gallery photo, manual material selection, city, weight validation, local save and queued sync, cloud list/detail, draft edit and archive. |
| Offline | SQLite UID-scoped metadata; app-private durable photo files; sync on Home entry/resume plus explicit Retry; optimistic server revision checks; locked/conflicting lots are not overwritten. |
| Photos | **Device-only**, not uploaded or recycler-visible. App data erase/uninstall can remove them. Retaken/orphaned files are conservatively retained; media cleanup/encrypted export is not implemented. |
| Directory | Exact supplied one-entry business directory, search, local saved contacts, external call/email actions. Authorization is **unreviewed**, not a verified badge. No inferred coordinates, distance, pickup promise or exact material whitelist. |
| Reference prices | Existing dated JSON, city/material/weight reference calculation. Source does not explicitly declare currency/provenance, so values are not labelled live INR prices or guaranteed sale ranges. |
| Requests | Real active, published, verified-snapshot buyer demand only. Current buyer verification checked by rules at offer/acceptance time. Up to 50 loaded requests, client city/expiry filtering. |
| Offers | Tap card/photo to select, then explicit Send selected lot. Whole lot locked to one active offer. My Offers shows newest 100 own proposals and actual statuses. |
| Quotes | Buyer-authored v2 quote â†’ collector accept or withdraw. Collector cannot forge quotes or change recycler verification. No collector counteroffer/price-negotiation field or multiple simultaneous quotes on one lot. |
| Handover | QR identifies private request/offer; collector submits actual scale weight, then the target verified recycler must confirm. QR scan alone cannot complete anything. No remote image evidence or digital-signature certification. |
| Receipts | Collector can record real received payments only after confirmed handover. Stable local journal ID survives timeout/restart. Same outstanding payload is retried; differing pending entries for the same offer are blocked until reviewed in Sync. |
| Ledger | Newest 100 own receipt statements; copy a clearly labelled receipt to clipboard. Not bank verification, tax invoice, lifetime earnings, automatic payment, expense accounting or payout reconciliation. |
| Profile | Name/unverified mobile/language edit; role and UID remain unchanged. Optional same-UID email recovery linking and email/password recovery/reset. |
| Safety | Localized hazardous handling, owner permission/data-erasure cautions, authorization checks and payment-fraud guidance. Not an emergency dispatch or regulatory certification service. |

## Important operational details

### Draft vs sync vs offer

`Save local draft` can save incomplete form metadata. `Save and queue sync` requires photo + confirmed material + valid weight. A queued record is not a synced lot or offer. Only a server-confirmed draft can be offered.

Draft typing is **not auto-saved after each keystroke**: tap Save before leaving. Before opening camera the current draft and a pending camera marker are persisted; reopening that original draft attempts Android lost-photo recovery. Real process-death behavior still needs phone testing.

Local edits on an offered/reserved/archived cloud lot may be kept on the phone but will not overwrite the locked server lot. Review cloud status. If resolving a revision conflict via Cloud lot â†’ Edit, the app asks before replacing unsynced local metadata with the displayed cloud version and keeps the photo.

### V2 lifecycle

```text
Local draft â†’ queued â†’ synced cloud draft
  â†’ proposed + lot offered
  â†’ recycler quoted
  â†’ collector accepted + lot reserved
  â†’ collector handoverPending (actual weight)
  â†’ recycler completed + lot handedOver
  â†’ collector-recorded receipt(s)
```

Before acceptance: collector cancellation or recycler rejection atomically releases the lot. An already-used deterministic offer ID is not reused for the same lot/request pair; duplicate retries cannot create a second proposal. New requests can receive a released lot. Existing legacy offers are NOT silently migrated into this new state machine.

Accepted-order cancellation, handover correction/dispute resolution, refunds and admin exception handling are **not implemented**. Do not pilot disputed real transactions until those workflows are built.

### Tomorrow's recycler work

Read [RECYCLER_NEXT_CONTRACT.md](RECYCLER_NEXT_CONTRACT.md). The backend guards for quote/reject/complete are present and emulator-tested, but there is **no recycler inbox/publisher/scanner UI in this delivery**. Live production flows wait for those actions; do not manufacture completed offers in production to make dashboards look populated.

### Still outside this delivery

AI identification; cloud photo upload/evidence sharing; public collector listings and unsolicited buyer quotes; real SMS login; payment gateway/bank verification; FCM push/chat; comprehensive pagination/export/financial reconciliation; admin verification console, consent/authorization-source review and automated legal compliance; production monitoring and full Android acceptance testing. These remain real work, not checked-off placeholders.

## Validation actually performed

- Installed sandbox-only **Flutter 3.47.3 / Dart 3.13.3**; user reported 3.47.2 / 3.13.2.
- Formatted and type/lint checked the delivered Dart source with matching Firebase packages in an isolated validation project: **No issues found**.
- **11 Flutter tests passed**, for contact normalization/input validation and valid/invalid weights. These are not widget-rendering, SQLite recovery or Auth integration tests.
- **27 isolated Firestore emulator tests passed**, including actual permitted/denied operations and two-party state transitions. Emulator project `demo-kabadi-collector`, no real data or production writes.
- Important qualification: actual laptop main.dart/app_language.dart/pubspec were not supplied. Validation used a minimal main and an API-compatible app_language harness stub; those stubs are **not shipped or installed**. Installer must adapt the actual existing main safely.
- PowerShell installer syntax, checksums/backup, exact main preservation, repeat install and reject-without-changes were exercised on isolated PowerShell7.6.6 sandbox fixtures. Actual Windows installation still needs CheckOnly.
- No Android APK/device build, camera permissions/process-death test, real Auth-link/email test, live recycler transaction, production index publication or production rule deployment was performed here.

See [VALIDATION_REPORT.md](VALIDATION_REPORT.md) and [COLLECTOR_QA.md](COLLECTOR_QA.md).

## Individual full-file downloads (manual alternative)

The installer is simpler and also integrates main safely. If downloading individually, do not create `lib/lib` and do not skip the startup integration.

| Full file | Destination |
|---|---|
| [collector_ui.dart](collector_ui.dart) | lib/collector_ui.dart |
| [collector_store.dart](collector_store.dart) | lib/collector_store.dart |
| [collector_home_screen.dart](collector_home_screen.dart) | lib/collector_home_screen.dart |
| [collector_pages.dart](collector_pages.dart) | lib/collector_pages.dart |
| [collector_market.dart](collector_market.dart) | lib/collector_market.dart |
| [collector_session_gate.dart](collector_session_gate.dart) | lib/collector_session_gate.dart |
| [recycler_directory_data.dart](recycler_directory_data.dart) | lib/recycler_directory_data.dart |
| [recycler_requests_screen.dart](recycler_requests_screen.dart) | lib/recycler_requests_screen.dart |
| [my_offers_screen.dart](my_offers_screen.dart) | lib/my_offers_screen.dart |
| [quick_registration_screen.dart](quick_registration_screen.dart) | lib/quick_registration_screen.dart |
| [quick_registration_text.dart](quick_registration_text.dart) | lib/quick_registration_text.dart |
| [quick_profile_service.dart](quick_profile_service.dart) | lib/quick_profile_service.dart |
| [app_speech.dart](app_speech.dart) | lib/app_speech.dart |
| [material_photos.dart](material_photos.dart) | lib/material_photos.dart |
| [widget_test.dart](widget_test.dart) | test/widget_test.dart |

Manual package command:

```powershell
flutter pub add "sqflite:^2.4.4" "path_provider:^2.1.6" "qr_flutter:^4.1.0" "url_launcher:^6.3.2"
```

For a manual full main.dart replacement, send the actual current main.dart; do not replace your welcome with a guessed template.

## Rollback

Stop the app build. Restore source/pubspec/lock from the installer's timestamped backup if necessary. Restore the previously saved **matching** published rules if rolling back to an old client, but note newly created v2 data may not be supported by that old client. Never delete phone data or Firebase records as a source-code rollback. The backup is of files this installer touched, not a full project/account/database backup.
