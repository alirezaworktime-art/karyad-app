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

- Work use (taxi, ride-hailing) or declared severe conditions → severe
  intervals for every item. Missing severe values fall back to normal ones.
- Mineral or semi-synthetic oil → the engine-oil change follows its severe
  interval and is capped at 5,000 km (mineral) or 7,000 km (semi).
- Each item is due at whichever comes first: km or months since it was last
  logged (or since the car was added).
- Odometer between readings = last reading + average daily km × days.
- «نزدیک» (due soon): within max(1,000 km, 10% of the interval) or 14 days.

## Catalog sync

The catalog's source of truth is `karyad-backend/catalog/`. Copy the file
into `assets/catalog/` when it changes; `test/features/catalog` fails if the
copy no longer parses.

## Next modules

- Local notifications for due items (`flutter_local_notifications`).
- Driver ledger (income, fuel, commission, net per hour) for work mode.
- Insurance, technical inspection and traffic-plan reminders.
- Service-history PDF for selling the car.
