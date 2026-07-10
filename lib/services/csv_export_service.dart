import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';

// Native-only imports loaded conditionally
import 'csv_export_native.dart'
    if (dart.library.html) 'csv_export_web.dart' as platform_csv;

/// Exports session data as CSV and shares or downloads it.
/// On web: triggers a browser file download.
/// On native: shares via share_plus.
class CsvExportService {
  static final _dateFmt = DateFormat('yyyyMMdd_HHmm');

  Future<void> exportFeaturesCSV(Session session) async {
    final rows = <List<dynamic>>[];
    rows.add([
      'session_id', 'timestamp', 'classification', 'irregularity_index',
      ...session.features.keys
    ]);
    rows.add([
      session.id,
      session.timestamp.toIso8601String(),
      session.classification,
      session.irregularityIndex,
      ...session.features.values,
    ]);

    final csv = const ListToCsvConverter().convert(rows);
    final filename =
        'WriteSense_features_${_dateFmt.format(session.timestamp)}.csv';

    await platform_csv.saveAndShare(csv, filename, 'WriteSense Feature Data');
  }

  Future<void> exportRawPointsCSV(Session session) async {
    final rows = <List<dynamic>>[];
    rows.add(
        ['stroke_index', 'point_index', 'x', 'y', 'timestamp', 'pressure']);

    for (int si = 0; si < session.strokes.length; si++) {
      final stroke = session.strokes[si];
      for (int pi = 0; pi < stroke.points.length; pi++) {
        final p = stroke.points[pi];
        rows.add([si, pi, p.x, p.y, p.timestamp, p.pressure]);
      }
    }

    final csv = const ListToCsvConverter().convert(rows);
    final filename =
        'WriteSense_raw_${_dateFmt.format(session.timestamp)}.csv';

    await platform_csv.saveAndShare(csv, filename, 'WriteSense Raw Stroke Data');
  }
}
