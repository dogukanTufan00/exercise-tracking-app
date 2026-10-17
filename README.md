# Exercise Tracking App

[![CI](https://github.com/dogukanTufan00/exercise-tracking-app/actions/workflows/ci.yml/badge.svg)](https://github.com/dogukanTufan00/exercise-tracking-app/actions/workflows/ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

A gym workout logger for Android (iOS-ready), built with Flutter. Log your exercises, sets, weights and
reps, add notes on how each exercise felt, and see what you lifted last time.

> **Status:** MVP complete, being tested on a real device. [Türkçe açıklama aşağıda.](#türkçe)

## Features

- [x] Workout history list with exercise/set counts and muscle groups
- [x] Workout screen: sets with ± weight/reps steppers, "repeat set", per-exercise notes
- [x] "Last time" hint: the sets you did for the same exercise in your previous workout
- [x] Exercise catalog with muscle groups and Turkish-aware search ("sinav" finds "Şınav")
- [x] Offline-first local storage (SQLite); changes are saved instantly
- [x] Four color themes with a theme picker (dark orange, red/black, yellow/navy, light blue)
- [x] Collapsible exercise cards with a one-line summary
- [x] Export history as CSV (Excel / Google Sheets) and back up / restore everything as JSON
- [ ] Progress charts and personal records (planned)

## Tech stack

| Concern | Choice |
|---|---|
| Framework | Flutter (Dart) |
| Database | `sqflite` (hand-written SQL) |
| State management | `ChangeNotifier` + `provider` (MVVM, per Flutter's architecture guide) |
| Preferences | `shared_preferences` |
| Fonts | Oswald + Inter, bundled (OFL) |

## Architecture

```
UI layer    View (Widget)  →  ViewModel (ChangeNotifier)
                                   │ depends only on the repository interface
Data layer  WorkoutRepository  →  SqliteWorkoutRepository  →  DatabaseService (sqflite)
```

The repository interface is the contract between layers. A shared **contract test suite**
([`workout_repository_contract.dart`](test/data/repositories/workout_repository_contract.dart)) runs against both
the SQLite implementation and an in-memory fake, so both are guaranteed to behave the same.

Details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · Design rules: [docs/DESIGN.md](docs/DESIGN.md)

## How this project is built (AI-assisted workflow)

This project is also my experiment in learning app development with AI agents:

- **Claude Opus** acts as architect and orchestrator: it designs the architecture with me, writes the contracts
  (models, interfaces, contract tests), splits the work and reviews every change.
- **Several Claude Haiku agents** write the implementation in parallel, each restricted to its own files.
  Their task briefs are in [docs/agent-briefs/](docs/agent-briefs/README.md).
- Every agent's output must pass `flutter analyze` and the shared tests before it is committed.

## Getting started

Requirements: Flutter 3.47+, Android SDK (an Android device with USB debugging, or an emulator).

```bash
git clone https://github.com/dogukanTufan00/exercise-tracking-app.git
cd exercise-tracking-app
flutter pub get
flutter test
flutter run
```

## License

[MIT](LICENSE). Fonts are licensed under the SIL Open Font License ([Oswald](assets/fonts/Oswald-OFL.txt),
[Inter](assets/fonts/Inter-OFL.txt)).

---

## Türkçe

Spor salonunda antrenman takibi için Flutter ile geliştirdiğim bir mobil uygulama. Hareketleri, setleri,
ağırlık ve tekrarları kaydediyor; her harekete "formum bozuldu", "kolay geldi" gibi notlar eklenebiliyor ve
aynı hareketi geçen sefer kaç kiloyla yaptığını gösteriyor.

Proje aynı zamanda yapay zekâ ajanlarıyla uygulama geliştirmeyi öğrenme deneyimim: mimariyi Claude Opus ile
birlikte tasarlıyorum, kodun bir kısmını paralel çalışan Claude Haiku ajanları yazıyor ve her değişiklik
testlerden geçmeden projeye girmiyor. Ayrıntılar: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
