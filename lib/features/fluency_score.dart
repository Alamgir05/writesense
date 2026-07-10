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
}) {
  // ── Normalisation reference values ─────────────────────────────────────
  // These are empirically chosen "worst-case" values used to scale each
  // raw feature into [0, 1]. A trained model would learn these from data.
  const double normJerk = 1e6;        // normalised_jerk upper bound
  const double normBaselineDev = 80.0; // pixels
  const double normVelVariance = 0.5;  // (px/ms)²
  const double normTremorAmp = 0.8;    // px/ms
  const double normDirectionChanges = 200.0;

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
  const double w1 = 0.25; // normalized_jerk       (smoothness)
  const double w2 = 0.20; // rhythm_irregularity   (temporal consistency)
  const double w3 = 0.20; // baseline_deviation    (spatial stability)
  const double w4 = 0.15; // velocity_variance     (speed consistency)
  const double w5 = 0.12; // tremor_amplitude      (tremor)
  const double w6 = 0.08; // direction_changes     (motor control)

  final raw = w1 * nj +
      w2 * rhythmIrregularity +
      w3 * bd +
      w4 * vv +
      w5 * ta +
      w6 * dc;

  final irregularityIndex = raw.clamp(0.0, 1.0);

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
