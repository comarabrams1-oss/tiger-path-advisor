# Ask Tiger Path setup

The Flutter client calls `/.netlify/functions/advisor`. The Netlify function
calls Gemini using a server-only key. No key belongs in Dart, assets,
`--dart-define`, Git, or the chat. The feature is disabled until configured.

In the existing site's Netlify environment-variable settings, add these with
Functions scope (use the secret-value control for the key):

- `GEMINI_API_KEY`: your existing Google AI Studio key
- `GEMINI_MODEL`: a model ID available to that key in AI Studio
- `AI_ENABLED`: `true`

Deploy after configuration and code review. Local `.env` values are not
transferred to Netlify when code is pushed. Set `AI_ENABLED=false` to disable calls. Your account's free-tier
eligibility and limits determine whether requests succeed; the app cannot
guarantee unlimited or free service. Do not enable billing without deciding
on a budget separately.

For local end-to-end web development, use Netlify Dev to serve both the function
and the compiled `build/web` site. Put environment variables in an ignored
`.env` file; do not commit it. Native Flutter platforms need a separately
configured HTTPS endpoint and authentication policy; the current UI targets
the existing Netlify web deployment.

The chat sends questions and minimal computed context (classification, program,
requirement statuses, ranked recommendations, prerequisite outcomes and section
counts) to Google Gemini. It does not send the student's name, grades, GPA,
full transcript, portal HTML, or session data. Chat history is saved on this browser; New chat starts another conversation.
Use Saved chats to restore or clear stored conversations. Users should not type private information into it.
The current profile is the existing test-student profile used elsewhere in the
app; a real student import is not added by this feature.

The deterministic services remain the source of truth. AI output is explanatory
text and never feeds back into eligibility, degree audits, plans or enrollment.
The endpoint accepts client-computed context for explanations; it is not an
independently verified academic decision service. AI can still make mistakes.

The endpoint has request-size, message-count, question-length, timeout and output
limits plus Netlify's IP rate-limit configuration (10 requests per minute).
Same-origin checks are not authentication. This first version does not add user
accounts; assess access controls and the provider quota before public rollout.

Validation:

```sh
flutter analyze
flutter test
node --test test/server/advisor.test.mjs
flutter build web --release
```

Server tests mock Gemini and never spend quota. A successful live response and
quota availability must still be checked after private key configuration.

References:
- https://ai.google.dev/api/generate-content
- https://docs.netlify.com/build/functions/api/

## Local connection verified

On October 25, 2026 the configured key successfully generated responses with
`gemini-3.1-flash-lite`, including a typed question through the web UI.
`gemini-2.5-flash` rejected access for this account, while `gemini-3.8-flash`
timed out during testing. The model is selected in the ignored local `.env`.
Run `node tool/dev_advisor_server.mjs` to serve the compiled app and local
AI endpoint at `http://127.0.0.1:8765`. Restart it after changing `.env`.
This preview is bound to the local computer and does not publish the app.

## Saved conversations and app actions

The advisor now saves up to 20 conversations on the current browser/device, with
up to 40 recent exchanges per conversation. New chat keeps the previous saved
conversation; Saved chats restores or clears history. Only the last five complete
exchanges plus the new question are sent to Gemini, alongside freshly computed
academic context. Stored requirement statuses are compared with the current
record to identify progress changes. Old answers are historical and may describe
an earlier academic state. The current profile remains the demo student; chat
cannot update transcripts, course completion, grades, or enrollment. Account-backed
profiles and cross-device synchronization remain future work. History storage is
not encrypted, so shared-device users should clear their saved chats.

Gemini returns a JSON answer and optional actions. Both server and client validate
an allowlist of theme presets and app destinations. Buttons apply the action only
when tapped. No arbitrary routes, URLs, commands, academic record mutations, or
code execution are supported. Theme changes persist through ThemeService and
update the app's root theme. Navigating back refreshes the academic context.

## Mock student sign-in

The app starts at a mock sign-in page requiring an address in `my.benedict.edu`.
The email is normalized and validated locally. No password is requested, no email
is sent, and ownership is not verified. This is a demonstration session, not
Tiger Portal authentication and not access control for the Gemini endpoint.
The optional remembered session uses browser/device storage. Sign-out clears
that session and returns to login, while saved conversations remain available
when the same email is used again on that browser. Conversations are keyed by a
stable encoded email; this separates demo histories but provides no security
against somebody entering another email or inspecting local storage.

Every mock login still displays the existing sample academic record. The email
is not added to Gemini's context. Real accounts, verified sign-in, private
student data and account-backed progress require a separate authentication and
data integration. Earlier anonymous demo chats are not automatically assigned
to the first student email.

## Custom colors from chat

Color requests can return `customTheme` actions with primary and accent colors
in six-digit `#RRGGBB` format plus a light/dark background choice. The server
and client reject malformed colors and non-boolean modes. The chat previews
both colors, then the student's tap applies and persists them through the same
custom-theme settings used by Theme Studio. Presets and navigation still work.

## Chat submission and connection errors

Enter submits a question; Shift+Enter inserts a newline. Mobile keyboards expose
a Send action. Active text composition is not submitted mid-composition.
The proxy returns safe error codes for quota, model access, provider access,
timeout, malformed response/action, and connection failures. The client maps
these codes to specific messages, without displaying upstream response bodies
or secrets. Failed questions remain in the composer for retrying.
