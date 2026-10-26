# Tiger Portal term import

Keep all captures in `private_data/` (ignored by Git). Never save portal HTML,
cookies, request headers, authentication fields, or student records in assets.
Use the existing sanitized capture shape: `{"pages":[{"html":"..."}]}`.
Each HTML page needs the selected `#pg0_V_ddlTerm` option and course-results
`#pg0_V_dgCourses` table. Retain only the term selector and course table when
capturing; remove links, form fields, scripts, and account/student information.
Capture every subject and every results page for the selected term. Section
counts alone do not prove coverage; compare the portal totals and subject list.

Run from the project root (use your installed Dart executable):

```sh
dart run tool/import_tiger_portal_capture.dart \
  private_data/spring_2027_sanitized.json \
  '2026-2027 - Spring' \
  private_data/course_sections_spring_2027_review.json
```

The importer requires an exact selected term, rejects empty matching pages,
invalid section identities/meetings, and conflicting duplicates. It exports
only fields from `CourseSection.toJson()` and refuses to overwrite an output.
Review counts, TBA meetings, dates, subject coverage and course identifiers
before copying the reviewed JSON into `assets/data/course_sections_spring_2027.json`.
Then add its path to `pubspec.yaml` and map `spring2027Term` to that asset in
`CourseSectionRepository._termAssets`. Generated Schedule automatically loads
registered Spring sections. Do not register Spring against the Fall asset.

The repository accepts the old ` - Full Semester` caller suffix as an alias;
other sessions must retain distinct term names. When data is unavailable the
existing Spring demonstration label remains visible. Asset-load failures also
currently fall back to demonstration data; the label identifies this behavior.

Run `flutter analyze` and `flutter test` after import. Seat availability is a
capture-time snapshot. Check the portal before registration.
