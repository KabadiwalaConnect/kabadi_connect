# Validation report â€” Collector v2 / Checkpoint84

## Executed results

| Check | Actual result |
|---|---|
| Flutter harness analyzer | **No issues found** |
| Flutter input/weight tests | **11 passed, 0 failed** |
| Firestore emulator authorization/state tests | **27 passed, 0 failed** |
| PowerShell installer syntax/fixture checks | **PASS** (PowerShell 7.6.6, sandbox fixtures) |
| Production deployment/writes | **Not performed** |
| Android build/device/manual acceptance | **Not performed** |

Flutter 3.47.3 / Dart 3.13.3 were installed temporarily in the sandbox. User-reported laptop version is Flutter3.47.2 / Dart3.13.2. Analyzer and Flutter tests used an isolated validation app with actual delivered files and API-compatible app_language/main harness stubs. The user's actual main/app_language/pubspec were not supplied; those harness stubs are NOT shipped. Tests do not prove the entire laptop app, camera, SQLite process-death handling, real Auth recovery or UI rendering works.

The 11 Flutter tests cover Indian contact normalization, malformed contact/name/role/language rejection before Auth access, and weight boundaries/types/NaN/infinity. No Firebase writes or SMS calls occur in these unit tests.

Rules tests ran on isolated project **demo-kabadi-collector** with local Firestore emulator1.19.8, firebase-tools13.35.1, Firebase JS11.10.0 and rules-unit-testing4.0.1. Dummy users/requests/lots were seeded only in the emulator. No real recycler verification/data was fabricated in production. The emulator was stopped after tests. Expected permission-denied logs are assertions of blocked operations, not unexpected failures.

## Passing Firestore test cases

1. own profile readable; other profile and unauthenticated access denied
2. new valid contact profile allowed; no client authorization escalation
3. invalid mobile and false verification claim rejected
4. owner can edit contact; cannot add a foreign email
5. owner can add exact linked Auth email without changing UID
6. valid new lot and optimistic revision edit allowed
7. invalid weight, stale revision, foreign lot write rejected
8. collector cannot publish self-verified buyer request
9. proposal and lot lock succeed atomically
10. proposal without lot lock rejected
11. lot lock without corresponding offer rejected
12. expired request rejects offer and preserves draft
13. revoked recycler rejects offer despite published verified snapshot
14. duplicate/second request and metadata editing cannot reuse locked lot
15. only target verified buyer can quote, not collector or another buyer
16. quote cannot overwrite collector weight or use negative rate
17. accept requires paired reservation; collector cannot forge completion
18. revoked recycler blocks quote acceptance
19. withdrawal releases lot atomically
20. buyer rejection requires atomic release
21. full two-party handover and receipt transaction succeed
22. receipt before handover, another owner, edits and bank-verification flag rejected
23. offers group query owner-filtered only; buyer cannot list unrelated lot collection
24. legacy profile and lot remain readable; legacy lot can be deliberately migrated
25. buyer can list own requests and nested offers, not another buyer requests
26. collector active-demand query works; unfiltered request listing denied
27. receipt query is owner filtered and cannot expose another collector

## Defects caught and corrected during this build

- Removed collector transaction reads of buyer private profiles; current authorization is enforced by rules instead.
- Added permitted owner/collector read-before-create of a nonexistent receipt ID so idempotent transactions can work without broad existing-record reads.
- Replaced unsupported TextTheme.apply(fontWeightDelta) with a supported merged text theme; cleaned analyzer findings.
- Fixed buyer request LIST rule to use query-provable resource ownership while keeping verified-buyer checks. A newly added buyer inbox-query test initially failed, then passed with the corrected rule; no blanket read grant was used.
- Cleared onboarding navigation on registration success, preserved original main welcome via guarded installer adaptation, and made Home navigation labels rebuild with locale.
- Added SQLite pending-receipt deduplication for the same offer/payload and blocked a different new pending receipt for that offer until the prior attempt is reviewed.

## Re-run rules tests locally (optional developer step)

Install a compatible JDK and Node, then from the installed `security-tests` directory:

```powershell
npm install
npm run verify
```

This explicitly starts an isolated demo emulator, runs the test file, then stops it. Do not substitute a production project or production data. Emulator tests do not enforce production index availability, so add/wait for the documented indexes separately.

## Still unverified

Actual Windows main pattern and installation, real Android build/plugin compatibility, full device layouts/text scaling/TTS, permission denial, camera process-death recovery, SQLite disk failures/large queues, dual-device sync/uncertain-write races, real account-link/email recovery, live publication/quotes/handover, production rules/index deployment and all cases in COLLECTOR_QA.md. Do not label these PASS based on source checks.

## Installer checks actually executed

- PowerShell parser accepted the generated readable installer.
- CheckOnly completed without changes on a recognized fixture.
- Source-only fixture installation backed up the original main and wrote all embedded file bytes matching their SHA-256 manifest.
- Existing welcome/main was preserved exactly except the single home wrapper and import.
- Repeat installation did not double-wrap main.
- A main file with only a commented welcome expression was rejected with no file changes.
- Package installation was skipped in these installer fixtures; package resolution was independently performed in the Flutter validation harness. These were PowerShell7.6.6/Linux fixtures, not execution on the user's Windows/PowerShell environment. The script targets PowerShell5.1-compatible constructs; actual laptop compatibility still needs CheckOnly.
