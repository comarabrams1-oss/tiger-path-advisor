# Gemini academic advisor

Open Course Recommendations → Ask AI about classes I need, or use the same button
from Semester Plan. The screen displays deterministic remaining requirements and
checked eligibility without making any network request. Asking Gemini requires
the sharing checkbox and an explicit button press.

Gemini receives the current audit, checked course eligibility, proposed plan,
and question. The app does not automatically send names, GPA, grades, or a full
transcript. Text entered by the student is sent as written. Responses are held
only in screen memory. Gemini cannot register a student or modify the plan.

## Connect a Firebase project

This implementation uses Firebase AI Logic with the Gemini Developer API.
Do not place a Gemini API key in Dart, a dart-define, GitHub, or this configuration
file. The Firebase app API key below is a client configuration identifier, not
your Gemini Developer API key.

1. In the Firebase console, create or select your project. Open AI Logic and
   complete Get started using the Gemini Developer API. Enable the required
   services and choose a supported Gemini model. No Firebase project or billing
   settings are created or changed by this code.
2. Register Android app `com.example.tiger_path` and Apple app
   `com.example.tigerPath`. These are the current repository identifiers.
   Use your own permanent identifiers before store distribution.
3. Copy `config/firebase.example.json` to `config/firebase.local.json`.
   Fill it with the Firebase app configuration values from your project:
   app API key, project ID, project number/messaging sender ID, and each Firebase
   app ID. Android and iOS app IDs differ. Change GEMINI_MODEL if your project
   uses a different supported model.
4. Configure Firebase App Check. Debug builds use the debug provider; register
   the device/emulator debug token in the Firebase console. Never commit debug
   tokens or enable the debug provider in distributed release builds. Release
   Android builds use Play Integrity; release Apple builds use App Attest with
   Device Check fallback. Register those providers and enforce App Check for AI
   Logic in your project. Platform signing/attestation configuration is required.
5. Run:

```sh
flutter pub get
flutter run --dart-define-from-file=config/firebase.local.json
```

The app initializes Firebase lazily when the student asks a question, so missing
configuration does not block Transcript, Degree Progress or Schedule Builder.
The CI builds intentionally run without live project configuration and do not
contact Gemini. They test model calls with injected responses.

For web development, also fill FIREBASE_WEB_APP_ID and
FIREBASE_RECAPTCHA_SITE_KEY and configure the web App Check provider/domain.
For macOS, register a separate Firebase macOS app and fill FIREBASE_MACOS_APP_ID;
the native app must have outgoing-network entitlement. Windows/Linux Gemini
clients are not configured by this implementation.

Before distributing, configure service quotas and review applicable Google data
handling terms for the selected service/plan and your institution's requirements.
The checked course catalog is incomplete, the sample student is still hardcoded,
and free-elective completion still uses the prototype audit shortcut. The AI is
instructed to disclose these limitations instead of making up missing approvals.

## Verify

```sh
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug
flutter build ios --release --no-codesign
flutter build ios --simulator --debug
```

After configuration, test a live question on a registered device. Confirm that a
blocked course stays blocked, an in-progress prerequisite stays conditional, and
the AI acknowledges unverified course availability. A successful mocked test or
unsigned build does not verify live Firebase access, quotas, or device signing.

Official references:

- https://firebase.google.com/docs/ai-logic/get-started?platform=flutter
- https://firebase.google.com/docs/ai-logic/security
- https://firebase.google.com/docs/app-check/flutter/default-providers
