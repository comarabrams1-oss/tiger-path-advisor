# Programs of study and student scenarios

Open **Programs of study** from Home or the book icon in Degree Progress. Search by major, concentration, or course code and open the original catalogue page with zoom support. The library includes 40 source entries from the supplied Benedict College 2025–2026 catalogue. Some are concentrations or certificates, not 40 distinct bachelor's majors.

Program pages and scheduling rules are deliberately separate. Four majors have app mappings: Computer Science (the existing 2024 mapping), Computer Engineering, Electrical Engineering, and Physics (2025–2026). Other entries are clearly marked reference-only; opening their source does not authorize the planner to invent requirements. The CS source reference is 2025–2026 while the existing CS app mapping remains labeled 2024.

## Fictional sign-in scenarios

| Account | Student | Classification | Major | Earned / current credits |
| --- | --- | --- | --- | --- |
| demo.student@my.benedict.edu | Jordan Taylor | Freshman | Computer Science | 6 / 16 |
| demo.sophomore@my.benedict.edu | Casey Brooks | Sophomore | Electrical Engineering | 33 / 16 |
| demo.junior@my.benedict.edu | Morgan Lee | Junior | Computer Engineering | 76 / 15 |
| demo.senior@my.benedict.edu | Riley Chen | Senior | Physics | 96 / 12 |

Alex Morgan's original engineering freshman account remains available at demo.engineering@my.benedict.edu. All are mock identities, not verified student accounts. Existing per-email isolation for chat, change history, and preferences applies. New scenarios calculate credits and GPA from their fixture transcripts. Riley's 12-credit term is full time, and explicitly confirmed elective credit is kept separate from unverified electives.

## Automatic checks

`ProgramCheckService.checkAll()` iterates the registry, checking requirement totals, duplicate identifiers/course codes, and course coverage. It lists unresolved prerequisite codes and alternative-course gaps for advisor review. The library runs these checks without selecting a particular major; advisor context receives the current program's review notes automatically.

`flutter test` checks every mapping, every primary class-year scenario, and all source images/continuations. Netlify's build now runs analysis and the full tests before publishing, so these checks run whenever the site is updated.

Electrical Engineering retains the printed PHYS 244 prerequisite for EE 333; it does not silently substitute PHYS 234. Graduating-senior design clearance, unresolved math equivalencies, service learning, approved electives, and unavailable section snapshots may still require advisor review. All programs retain deterministic prerequisite, degree, lab-pairing, credit and conflict checks; Gemini cannot waive them.

To regenerate the reference library from page-level text files extracted from the same catalogue PDF:

```sh
python3 tool/import_program_library.py --pdf /path/to/catalogue.pdf --text-dir /path/to/page-text-files
flutter test
```

The importer indexes every matching program heading and preserves original page layouts as images, including split-page tables. Review changed program rules before adding a new planner mapping. Do not include private Tiger Portal captures, session data, keys, or real student records in this pipeline.
