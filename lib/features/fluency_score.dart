// Derives fluency/quality scores from extracted feature maps.
//
// ─────────────────────────────────────────────────────────────────────────
// PLACEHOLDER: The [computeIrregularityIndex] formula below is a manually
// tuned, weighted combination of selected features. It is designed to be
// swapped for a trained TFLite inference call when a labelled dataset
// becomes available (see TODO comments below).
// ─────────────────────────────────────────────────────────────────────────
// Returns a Map<String, double> with keys:
//   irregularity_index, fluency_score, consistency_score

Map<String, double> computeFluencyScores({
  required Map<String, double> spatial,
  required Map<String, double> temporal,
  required Map<String, double> dynamic_,
  int? strokeCount,
}) {
  // Determine actual stroke count
  int actualStrokes = strokeCount ?? 1;
  if (strokeCount == null) {
    final tempo = temporal['writing_tempo'] ?? 0.0;
    final durSec = (temporal['total_duration'] ?? 0.0) / 1000.0;
    actualStrokes = (tempo * durSec).round();
    if (actualStrokes < 1) actualStrokes = 1;
  }

  // ── Normalisation reference values ─────────────────────────────────────
  // NOTE: These values are a first-pass calibration based on synthetic test cases,
  // not a clinically validated dataset, and should be recalibrated against real
  // labeled handwriting samples before any clinical-adjacent claim is made.
  final double normJerk;
  final double normBaselineDev;
  final double normVelVariance;
  final double normTremorAmp;
  final double normDirectionChanges;

  if (actualStrokes >= 2) {
    // Multi-stroke normalization constants (suitable for full writing sessions)
    normJerk = 1e6;
    normBaselineDev = 80.0;
    normVelVariance = 0.5;
    normTremorAmp = 0.8;
    normDirectionChanges = 200.0;
  } else {
    // Single-stroke normalization constants (tuned in Experiment 4 for individual strokes)
    normJerk = 1.5;
    normBaselineDev = 80.0;
    normVelVariance = 0.05;
    normTremorAmp = 0.25;
    normDirectionChanges = 30.0;
  }

  // ── Raw feature extraction ──────────────────────────────────────────────
  final nj = (dynamic_['normalized_jerk'] ?? 0).clamp(0, normJerk) / normJerk;
  final rhythmIrregularity =
      1.0 - (temporal['rhythm_regularity'] ?? 1.0).clamp(0, 1);
  final bd = (spatial['baseline_deviation'] ?? 0).clamp(0, normBaselineDev) /
      normBaselineDev;
  final vv =
      (dynamic_['velocity_variance'] ?? 0).clamp(0, normVelVariance) / normVelVariance;
  final ta = (dynamic_['tremor_amplitude'] ?? 0).clamp(0, normTremorAmp) /
      normTremorAmp;
  final dc = (dynamic_['direction_changes'] ?? 0).clamp(0, normDirectionChanges) /
      normDirectionChanges;

  // ── Weighted irregularity index ─────────────────────────────────────────
  // TODO: Replace this formula with TFLite model inference:
  //   final interpreter = await Interpreter.fromAsset('writesense_model.tflite');
  //   final output = <double>[0];
  //   interpreter.run(inputVector, output);
  //   final irregularityIndex = output[0];
  final double irregularityIndex;
  if (actualStrokes >= 2) {
    // Multi-stroke path weights
    const double wJerk = 0.25; // smoothness
    const double wRhythm = 0.20; // temporal consistency
    const double wBaseline = 0.20; // spatial stability
    const double wVelVar = 0.15; // speed consistency
    const double wTremor = 0.12; // tremor
    const double wDirChan = 0.08; // motor control

    final raw = wJerk * nj +
        wRhythm * rhythmIrregularity +
        wBaseline * bd +
        wVelVar * vv +
        wTremor * ta +
        wDirChan * dc;
    irregularityIndex = raw.clamp(0.0, 1.0);
  } else {
    // Single-stroke path weights (Experiment 4)
    const double wJerk = 0.20;
    const double wVelVar = 0.30;
    const double wTremor = 0.40;
    const double wDirChan = 0.10;

    final raw = wJerk * nj +
        wVelVar * vv +
        wTremor * ta +
        wDirChan * dc;
    irregularityIndex = raw.clamp(0.0, 1.0);
  }

  // ── Fluency score: inverse of irregularity (higher = smoother writing) ──
  final fluencyScore = 1.0 - irregularityIndex;

  // ── Consistency score: based on pen-down ratio + rhythm ─────────────────
  final penDownRatio = (temporal['pen_down_ratio'] ?? 0.5).clamp(0, 1);
  final rhythmReg = (temporal['rhythm_regularity'] ?? 1.0).clamp(0, 1);
  final consistencyScore = (penDownRatio * 0.5 + rhythmReg * 0.5).clamp(0.0, 1.0);

  return {
    'irregularity_index': _safe(irregularityIndex),
    'fluency_score': _safe(fluencyScore),
    'consistency_score': _safe(consistencyScore),
  };
}

/// Classify based on [irregularityIndex].
/// Threshold of 0.35 is a heuristic placeholder — tune with labelled data.
String classify(double irregularityIndex) {
  if (irregularityIndex < 0.35) return 'Regular';
  if (irregularityIndex < 0.60) return 'Mildly Irregular';
  return 'Irregular';
}

double _safe(double v) => (v.isNaN || v.isInfinite) ? 0.0 : v;
