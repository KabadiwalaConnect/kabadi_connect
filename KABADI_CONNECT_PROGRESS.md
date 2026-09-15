# KabadiConnect — Project Handoff & Progress

Last updated: 2026-09-08

## How to use this file
At the start of a new chat, attach this file and the current relevant project files. This file records progress; it is not a source-code backup. The assistant cannot directly access the user's Windows laptop. User-run changes are only verified when the user supplies results. Update this file after every agreed step, recording changes, tests, errors, and the next action. Keep a downloaded copy with the project and replace it with each updated version.

## Current status
- Previous project was permanently deleted at the user's request.
- Fresh Android-only Flutter project created at D:\FlutterProjects\kabadi_connect.
- User confirmed the default Flutter counter app runs on their physical Android phone.
- No custom features in the fresh project have been verified.
- Product requirements and architecture are NOT yet agreed. Do not implement features until requirements are clarified.

## Confirmed development environment
- Windows 11 laptop; approximately 7.33 GB usable RAM.
- Flutter stable 3.47.2 at D:\flutter; Dart 3.13.2.
- Android SDK: D:\Android; SDK 36; Android licenses accepted.
- JDK 17: C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot.
- Flutter configured to use that JDK.
- Phone: V2153; device ID 10BD141N8F0016P; Android 14/API 34.
- GRADLE_USER_HOME: D:\GradleCacheFresh (user-level environment setting saved).
- Most recent TEMP/TMP: D:\Temp. Session-level settings must be reapplied in new terminals as needed.
- Last reported free space: C: 4.4 GB, D: 83.14 GB.
- Last reported free RAM: 1.04 GB before the successful baseline confirmation. Current RAM/storage unknown.
- Visual Studio Windows-build warning is not a blocker for Android.

## Fresh-project configuration instructions given
User reported completion and confirmed baseline runs; current files have not been independently inspected.
In android/gradle.properties preserve generated settings, replacing org.gradle.jvmargs with:
```properties
org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=768m -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8
org.gradle.workers.max=1
org.gradle.parallel=false
kotlin.compiler.execution.strategy=in-process
```
Do not copy old TensorFlow workarounds into the new project by default.

## Lessons from the deleted project
- JDK installed at drive root reported java.home=D: and led to incorrect Java-home resolution. Dedicated JDK installation fixed that problem.
- Old tflite_flutter 0.11.0 integration encountered Java/Kotlin target mismatch and TensorFlow namespace conflicts with the previous AGP 9.x setup.
- Oversized Gradle heap (8 GB) contributed to a confirmed native-memory allocation failure on this laptop.
- C: disk exhaustion blocked builds; new Gradle cache and temporary files were placed on D:.
- DNS resolution failures for Maven Central and Google blocked dependency downloads; later DNS checks passed.
- These are historical findings, NOT reasons to add old plugins or workarounds to the fresh app.

## Product decisions
Pending. The previous app was described as an e-waste app for kabadiwalas and recyclers, but the user wants requirements understood afresh. Do not treat previous features as approved scope.

## Working agreement requested by user
- Understand what to build and how before implementation.
- Update a durable progress/handoff file after every step so work can continue in a new chat.
- Separate planned work, implementation instructions, and user-verified results.

## Milestones
- [x] Fresh Flutter Android baseline runs on physical phone (user-confirmed).
- [ ] Collect product requirements and main user journeys.
- [ ] Agree MVP scope and exclusions.
- [ ] Select architecture, storage/backend, and dependency strategy.
- [ ] Implement and test features incrementally.

## Next action
User supplied detailed SIH requirements at Checkpoint 02. Read companion KABADI_CONNECT_REQUIREMENTS.md for the full 17-feature checklist, proposed architecture, demo journey and unresolved decisions. Clarify visual reference, AI scope/model availability, backend/role setup, deadline and test-device availability. Approve plan before coding.

## Checkpoint 02 — Requirements captured
- Product: offline-first digital bridge between informal e-waste collectors and authorized recyclers; administrator is third role.
- Core: FAIR VALUE → BEST OFFER → VERIFIED HANDOVER.
- Required home: Sell E-Waste, Today's Price, Find Recycler, My Earnings, Safety.
- Hindi/Marathi, large icons/buttons, minimal text, spoken guidance.
- All 17 MVP requirements recorded in companion requirements file; none implemented yet.
- Matching weights recorded: authorization 30%, material 25%, price 25%, distance 10%, pickup 10%.
- No visual screenshot/Figma reference supplied; pixel-identical styling cannot yet be specified.
- AI classification timing conflicts between Phase 2+ wording and MVP demo: decision pending. No model/data supplied.
- Architecture proposals are not user-approved. Keep real vs demo data, payment recording vs transfer, and handover vs actual recycling claims explicit.
- Updated handoff documents; no app source changes.

## Change log
### Checkpoint 01
Created this handoff file. Recorded successful baseline, environment, historical pitfalls, and pending requirements. No custom app implementation performed.

## Checkpoint 03 — Screen 1 reference and implementation delivered
- User supplied uploads/image-1.png: WhatsApp screenshot showing cream/green welcome screen, leaf logo, Kabadiwalla Connect, Behtar Kal Saaf Kal, collector/cart illustration, Hindi Start CTA and Hindi footer.
- User approved starting this screen. Other AI/backend/deadline questions remain unanswered; do not block welcome-screen work on those.
- Delivered SCREEN_1_WELCOME.zip containing lib/main.dart, assets/images/collector_welcome.png, test/widget_test.dart and INSTALL.md.
- Original AI-generated collector artwork and vector leaf recreation, not pixel-identical original assets. Display branding follows supplied screenshot; final brand spelling and tagline reconciliation pending.
- No native plugins or Gradle changes. User must register the image in the existing pubspec flutter/assets block.
- Start button navigates to an explicitly temporary next-screen placeholder; screen 2 not designed/approved yet.
- Code and widget test authored, NOT executed in assistant workspace; flutter analyze/test/device screenshot pending.
- Next action: user installs package into local project, runs analyze/test and phone build, sends screenshot; refine screen 1 and update verified status before screen 2.
## Checkpoint 08 — Language-selection screen
- Screen 2 ke reference-style UI ka code diya gaya.
- English/Hindi/Marathi language selection ka code diya gaya.
- Continue par language save karne ke liye shared_preferences use kiya.
- Screen 1 se 4 seconds baad language screen khulne ka code diya.
- Screen 3 abhi translated placeholder hai.
- Code apply hone, tests pass hone aur phone verification ki confirmation pending hai.
## Checkpoint 10 — Full-file screen 3 implementation
- Full replacement code supplied for app_language.dart,
  language_screen.dart, role_selection_screen.dart and widget_test.dart.
- main.dart unchanged.
- Two role illustration assets required in pubspec.yaml.
- Screen 2 saves language and opens role selection.
- Collector/Recycler selection opens role-specific placeholder.
- Registration and permanent role storage are not implemented yet.
- Local analysis, tests and phone verification pending.
## Checkpoint 12 — Firebase prerequisites
- Android package verified: com.example.kabadi_connect.
- Node 22.23.1 and npm 10.9.8 available.
- Debug SHA-1 and SHA-256 obtained.
- Firebase Android registration and FlutterFire setup instructions supplied.
- Firebase configuration, billing/Auth/Firestore setup confirmation pending.
- No database writes or real OTP flow verified yet.
## Checkpoint 13 — Firebase configuration ready
- FlutterFire Android configuration completed.
- lib/firebase_options.dart exists: verified.
- Firebase runtime initialization and database writes not yet tested.
- Real OTP setup and Firestore console settings confirmation pending.
- Registration screen implementation is next.
## Checkpoint 14 — Firebase initialization and database rules
- firebase_auth/cloud_firestore installation instructions supplied.
- Full main.dart supplied with Firebase initialization.
- Existing welcome/language/role screens retained.
- Owner-only Firestore profile rules supplied.
- User cannot self-approve recycler authorization.
- Registration UI, OTP sending and profile writes not implemented yet.
- Rule publication, local checks and runtime initialization pending verification.
## Checkpoint 15 — Firebase runtime verified
- Physical phone V2153 par Firebase initialization successful.
- Success log user ne confirm kiya.
- OTP delivery aur Firestore profile saving abhi pending.
- Next: registration screen with name, phone, OTP and selected role.
## Checkpoint 15 — Firebase runtime verified
- Physical phone V2153 par Firebase initialization successful.
- Success log user ne confirm kiya.
- OTP delivery aur Firestore profile saving abhi pending.
- Next: registration screen with name, phone, OTP and selected role.
## Checkpoint 18 — Current app flow verified
- User confirmed current screens and navigation work.
- Firebase runtime initialization verified.
- Latest tested flow mein blocking freeze/crash report nahi hua.
- Previous disconnect ka exact cause unknown.
- Real OTP and Firestore profile saving remain pending.
- Next milestone: registration screen for Collector and Recycler.