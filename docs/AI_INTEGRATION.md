# Tiger Path AI integration

The advisor and inline schedule helper use the same server-side Netlify endpoint: `/.netlify/functions/advisor`. Gemini 3.5 Flash-Lite is the configured production model, with its minimal thinking level explicitly selected for these latency-sensitive explanation and routing requests. The browser never receives the API key.

## Production configuration

Netlify must have `AI_ENABLED=true`, `GEMINI_MODEL=gemini-3.5-flash-lite`, and `GEMINI_API_KEY` set for the production context and available to Functions. Configure values through Netlify's environment-variable API/UI, not `netlify.toml`, Flutter defines, a committed `.env`, or public assets. Environment changes require a new deployment. The existing account uses Netlify's default environment scopes; granular scopes require a paid plan.

A live `NOT_CONFIGURED` error means at least one setting is missing in the deployed function. `MODEL_UNAVAILABLE`, `PROVIDER_BUSY`, `QUOTA`, `PROVIDER_ACCESS`, and `TIMEOUT` are distinguished from unverified schedule choices. Rate-limit HTML from the host is also handled without pretending the student chose an invalid section. Requests retry once on a provider 503, with a shared 45-second provider timeout.

## Capabilities

- Explain computed remaining requirements, recommended courses, student classification, conditional prerequisites, instructor/time/room/delivery details, and imported seat snapshots.
- Follow the active student's major and catalog automatically, including program-mapping warnings. Program references do not authorize invented requirements.
- Offer buttons to open Transcript, Degree Progress, Recommendations, Schedule Builder, Theme Studio, or Programs of Study.
- Offer custom colors, presets, or classic/soft/sharp layout changes. A student must tap the offered action; a layout change preserves the palette.
- Retain up to 20 local conversations per mock student and compare fresh requirement status with the previous conversation snapshot. This is device-local history, not cross-device student authentication or a live transcript feed.
- Turn in-tab schedule requests into validated preferences/course/section proposals. The deterministic planner performs eligibility, credit, co-enrollment, availability, and conflict checks; applied differences appear in the per-profile change log.

Explicit asynchronous sections have no invented weekly meeting time. Unknown/TBA sections remain distinct and require verification. No action enrolls a student, modifies academic records, grants placement/permission, or overrides prerequisite/degree rules.

## Validation

Run `flutter analyze`, `flutter test`, and `node --test test/server/*.test.mjs`. Netlify runs all three before publishing. Mock tests cover context filtering, errors/retry, allowed and rejected actions, action application after a tap, saved history/progress changes, and deterministic schedule updates. Separately smoke-test the deployed endpoint with fictional profiles and actual imported offerings. Mock tests alone do not prove production environment configuration.

Free-tier model limits and provider availability still apply. Real student authentication, cloud history sync, registration, and live Tiger Portal synchronization are outside this prototype's integration.
