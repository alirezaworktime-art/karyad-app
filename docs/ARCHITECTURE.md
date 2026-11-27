# Architecture

## Principles

1. **Local-first.** All user data lives on the device. Reminders, history
   and the catalog work with no network. The backend only adds fresher
   catalog data and update notices.
2. **Feature folders, layered inside.** Each feature under `lib/features/`
   has up to four layers, and dependencies point inward only:
   - `domain/` — pure Dart models and rules. No Flutter imports. Fully unit
     tested. Example: `MaintenancePlanner` decides what is due.
   - `data/` — storage and loading (`GarageRepository`,
     `CatalogRepository`). Interfaces first, so engines can change.
   - `application/` — state and use cases (`GarageController`, a
     `ChangeNotifier`). Screens call it; it calls repositories.
   - `presentation/` — widgets only. No storage or business rules.
3. **Few dependencies.** Flutter SDK plus small, stable packages
   (`shared_preferences`, `shamsi_date`, `url_launcher`). Every new package
   needs a reason in its PR.
4. **Persian and RTL by default.** Locale `fa_IR`, Vazirmatn font (bundled,
   OFL licensed), Solar Hijri dates and Persian digits via
   `core/format/persian_format.dart`. Use direction-aware icons
   (`arrow_back`, `chevron_right`), which mirror automatically in RTL.

## Layout

```
lib/
  main.dart                     wires repositories → controller → app
  app/                          MaterialApp, theme (brand colors)
  core/format/                  Persian numbers and Jalali dates
  features/
    catalog/
      domain/catalog.dart       catalog model + JSON parsing (schema v1)
      data/catalog_repository   bundled asset loader
    garage/
      domain/vehicle.dart       Vehicle, OdometerReading, ServiceRecord
      domain/maintenance_planner.dart   what is due, and how urgent
      data/garage_repository    shared-preferences storage with backup copy
      application/garage_controller.dart
      presentation/             onboarding, home, sheets
assets/
  catalog/maintenance-catalog.json   copy of karyad-backend's catalog
  fonts/                              Vazirmatn
test/                           mirrors lib/
```

## Scheduling rules

The app never guesses the odometer. Every reminder is an absolute target the
user can check against the dashboard and the calendar.

- **Targets, not countdowns.** Each item is due «در X کیلومتر یا تا تاریخ Y»,
  whichever comes first.
- **History first.** Logged item → due = last km + interval, last date +
  months.
- **No history → factory schedule.** Km follow the manufacturer's milestones
  from 0 (an 80,000 km belt on a 62,000 km car is due at 80,000); months
  count from the day the car was added.
- **Oil sticker.** At onboarding the user may type the number on the
  oil-change sticker; the oil target is exactly that number.
- **Odometer readings.** The user types the dashboard value (prompted every
  14 days, 7 for work cars). From two or more readings a week apart the app
  learns km/day and adds «حدود ۳ هفته دیگر»; it never asks for km/day.
- **Visits.** Items due within 2,000 km (or 45 days for time-only items) of
  the most urgent one are grouped into the next visit, logged together.
- **Severe schedule.** Work use (taxi, ride-hailing) → severe intervals for
  every item, falling back to normal values where severe ones are missing.
  Mineral / semi-synthetic oil → severe oil interval, capped at 5,000 /
  7,000 km.
- **Status.** Overdue when km or date passed; «نزدیک» within 1,000 km or
  30 days.

## Catalog sync

The catalog's source of truth is `karyad-backend/catalog/`. Copy the file
into `assets/catalog/` when it changes; `test/features/catalog` fails if the
copy no longer parses.

## Next modules

- Local notifications for due items (`flutter_local_notifications`).
- Driver ledger (income, fuel, commission, net per hour) for work mode.
- Insurance, technical inspection and traffic-plan reminders.
- Service-history PDF for selling the car.
