# Schedule updates and change history

After a successful inline schedule request, the app compares the actual before/after timetable and preferences. It displays a short “What changed” list and saves the full details in a collapsed change log. A request that changes nothing is recorded explicitly as a no-op. Provider or validation failures keep the draft unchanged and display an error rather than a fabricated change.

The log records the request, local timestamp, term, course additions/removals, section/time/location/instructor changes, credit totals, unresolved items and preference changes. It retains the latest 20 updates on the current browser/device, isolated by the mock student profile. It does not sync across devices, restore past timetables, undo updates or register courses. Storage errors are shown; unreadable history is not overwritten automatically.

Supporting explanations use info icons with hover and tap support and keyboard-accessible buttons. Current selections, actual outcomes, conditional prerequisites, missing offerings and advisor-review warnings remain visible. Change-log disclosure rows start closed.

## Specific class and instructor requests

Both Ask Tiger Path and Build with Tiger Path can revise the current in-session draft. In the main chat, an explicit edit produces an **Update current schedule** button; tapping it opens the same draft and runs the request once. A draft must first be generated. Drafts are isolated by profile and do not survive a browser reload.

The helper receives selected sections with their times and instructors, plus eligible alternatives. Instructor matches are prioritized in the bounded candidate context. Responses can exclude verified courses or exact sections and request verified instructor sections. Exclusions and section choices are enforced during planning, recovery, and timetable generation. Requested courses are prioritized ahead of maximizing credits, while prerequisite, degree, lab, availability, conflict, and credit-limit checks remain deterministic. Removing a course does not erase its outstanding degree requirement. Ambiguous requests ask for clarification without changing the draft.

Actual outcomes and unfulfilled instructor requests are reported separately from the model's proposed summary. Spring 2027 PHYS 234 section 01 is taught by Pandit, Rishi (MWF 1:00–1:50 PM); it conflicts with CSC 238 section 01. Selecting that Physics section can therefore reduce credits when other eligible offerings cannot fill the gap. The app never invents a section or claims a full schedule when the verified choices do not support one.
