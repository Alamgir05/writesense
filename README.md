# WriteSense 📝

A Flutter mobile app for **handwriting irregularity detection** using spatial, temporal, and kinematic feature analysis. Built as a final-year project.

---

## Features

- 🖊️ **Live handwriting capture** — touch/stylus with pressure sensitivity via `Listener` + `CustomPainter`
- 📐 **Spatial features** — stroke length, bounding box, aspect ratio, slant, curvature, straightness, writing density, baseline deviation, center of mass
- ⏱️ **Temporal features** — total duration, pen-down ratio, pause count, writing tempo, rhythm regularity  
- ⚡ **Dynamic/Kinematic features** — velocity, acceleration, jerk, normalized jerk (smoothness index), tremor frequency/amplitude, direction changes
- 🎯 **Irregularity index** — weighted 5-factor formula (placeholder for TFLite model swap)
- 📊 **Results screen** — score gauge, classification badge, expandable per-category feature breakdown
- 📈 **History screen** — session list + `fl_chart` trend line with threshold markers
- 📄 **PDF export** — full A4 report via `printing` package
- 📋 **CSV export** — feature summary + raw stroke points
- 💾 **Local persistence** — SQLite on Android/desktop, in-memory on web

---

## Tech Stack

| Category | Package |
|---|---|
| State management | `flutter_riverpod` |
| Local database | `sqflite` + `sqflite_common_ffi` |
| PDF generation | `pdf` + `printing` |
| Charts | `fl_chart` |
| CSV | `csv` |
| Fonts | `google_fonts` |
| IDs | `uuid` |

---

## Project Structure

```
lib/
├── main.dart
├── screens/
│   ├── home_screen.dart
│   ├── draw_screen.dart          # Canvas capture
│   ├── results_screen.dart       # Feature breakdown + score
│   └── history_screen.dart       # Past sessions + trend chart
├── widgets/
│   ├── handwriting_canvas.dart   # CustomPainter + Listener
│   ├── feature_card.dart
│   └── session_tile.dart
├── features/
│   ├── spatial_features.dart
│   ├── temporal_features.dart
│   ├── dynamic_features.dart
│   └── fluency_score.dart        # irregularity_index formula
├── models/
│   ├── stroke_point.dart         # {x, y, t, pressure}
│   ├── stroke.dart
│   └── session.dart
├── services/
│   ├── session_repository.dart   # SQLite CRUD (web: in-memory)
│   ├── pdf_report_service.dart
│   └── csv_export_service.dart
└── providers/
    ├── session_provider.dart     # Drawing state notifier
    └── history_provider.dart
```

---

## Getting Started

### Prerequisites
- Flutter SDK ≥ 3.44.0 (stable)
- For Android: Android SDK + a device with USB debugging enabled

### Run

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/writesense.git
cd writesense

# Install dependencies
flutter pub get

# Run on Chrome (no setup needed)
flutter run -d chrome

# Run on Android (connect phone first)
flutter run
```

### Run tests

```bash
flutter test
```

---

## Irregularity Classification

| Score | Label |
|---|---|
| 0 – 34% | ✅ Regular |
| 35 – 59% | ⚠️ Mildly Irregular |
| 60 – 100% | ❌ Irregular |

> **Note:** The irregularity formula in `lib/features/fluency_score.dart` is a weighted placeholder. It is clearly marked with a `TODO` comment for replacement with a trained TFLite model.

---

## Roadmap

- [ ] TFLite model integration for ML-based classification
- [ ] Collect labelled dataset using CSV export
- [ ] Word/letter segmentation
- [ ] Multi-session comparison report

---

## License

MIT © Peter
