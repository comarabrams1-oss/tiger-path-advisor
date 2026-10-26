# Schedule updates and change history

After a successful inline schedule request, the app compares the actual before/after timetable and preferences. It displays a short “What changed” list and saves the full details in a collapsed change log. A request that changes nothing is recorded explicitly as a no-op. Provider or validation failures keep the draft unchanged and display an error rather than a fabricated change.

The log records the request, local timestamp, term, course additions/removals, section/time/location/instructor changes, credit totals, unresolved items and preference changes. It retains the latest 20 updates on the current browser/device, isolated by the mock student profile. It does not sync across devices, restore past timetables, undo updates or register courses. Storage errors are shown; unreadable history is not overwritten automatically.

Supporting explanations use info icons with hover and tap support and keyboard-accessible buttons. Current selections, actual outcomes, conditional prerequisites, missing offerings and advisor-review warnings remain visible. Change-log disclosure rows start closed.
