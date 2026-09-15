# Screen 1 — Welcome screen

Reference-inspired Flutter welcome screen. Original AI-generated illustration and hand-drawn vector leaf mark; not a pixel-identical recreation of supplied artwork. No new plugins, network images or Gradle changes. Branding follows screenshot: Kabadiwalla Connect / Behtar Kal, Saaf Kal. Formal product tagline remains in requirements document.

## Install into existing fresh project
1. Stop flutter run. Copy lib/main.dart to project lib/main.dart.
2. Copy assets/images/collector_welcome.png into project assets/images/collector_welcome.png.
3. Copy test/widget_test.dart over the default counter test (it refers to package kabadi_connect).
4. In existing pubspec.yaml, under its ONE existing flutter: block, preserve uses-material-design: true and add:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/collector_welcome.png
```
Do not replace the whole pubspec or add a second flutter block. Use spaces, not tabs.

5. In the configured Windows PowerShell session:
```powershell
cd D:\FlutterProjects\kabadi_connect
$env:GRADLE_USER_HOME = "D:\GradleCacheFresh"
New-Item -ItemType Directory -Force "D:\Temp" | Out-Null
$env:TEMP = "D:\Temp"
$env:TMP = "D:\Temp"
flutter pub get
flutter analyze
flutter test
flutter run -d 10BD141N8F0016P
```
Stop and share any analyze/test error before proceeding. No flutter clean required.

## Acceptance checks
- Cream background, green leaf mark, title, illustration, Hindi CTA and footer show without overflow.
- On smaller screens/large text settings content scrolls instead of clipping.
- Start button opens an explicitly temporary next-screen placeholder; Android back returns.
- Welcome image works without internet after installation.
- Send phone screenshot for visual refinement.

## Validation status
Code and widget test supplied, not compiled/executed against Flutter in the assistant workspace. Phone verification pending. Device Hindi fallback font may differ from reference; no bundled font supplied. Only this screen is implemented, not login, language selection, AI or backend.
## Checkpoint 08 — Language-selection screen
- Reference-style language UI manual code supplied.
- English/Hindi/Marathi app-wide language controller added.
- Continue saves selection using shared_preferences.
- Flutter localization delegates configured.
- Screen 1 leads to language screen after four seconds.
- Screen 3 remains a translated placeholder.
- Future screens must use translation keys.
- Screen 1 image text does not automatically translate.
- Analyze/tests/device appearance and persistence verification pending.