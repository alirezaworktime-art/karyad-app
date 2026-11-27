# AGENTS.md

Guidance for anyone — human or AI assistant — working in this repository.

- Read `docs/ARCHITECTURE.md` first; keep its layers (domain → data →
  application → presentation) and dependency direction.
- Flutter 3.50+: import `package:material_ui/material_ui.dart`. It already
  exports `GlobalMaterialLocalizations`; do not add `flutter_localizations`.
- Do not name domain types after Flutter widgets or animation classes
  (for example `Interval` clashes with the animation curve; the catalog uses
  `ServiceInterval`).
- Persian UI: format numbers and dates through `PersianFormat`; parse user
  numbers with `PersianFormat.parseInt` (accepts Persian, Arabic and Latin
  digits).
- If you cannot run Flutter locally, push a branch and read
  `ci-logs/<branch>:ci-report.txt`.
