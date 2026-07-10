import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/session.dart';

/// Generates and shares a PDF report for a [Session].
class PdfReportService {
  static final _dateFmt = DateFormat('dd MMM yyyy, HH:mm');
  static final _numFmt = NumberFormat('0.0000');

  Future<void> exportPdf(Session session) async {
    final pdf = pw.Document();
    final scoreColor = _scoreColor(session.irregularityIndex);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('WriteSense Report',
                    style: pw.TextStyle(
                        fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text(_dateFmt.format(session.timestamp),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (context) => [
          // ── Score summary ────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(8),
              color: PdfColors.grey100,
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Irregularity Index',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    pw.Text(
                      '${(session.irregularityIndex * 100).toStringAsFixed(1)}%',
                      style: pw.TextStyle(
                          fontSize: 36,
                          fontWeight: pw.FontWeight.bold,
                          color: scoreColor),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: scoreColor,
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Text(
                    session.classification,
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Session metadata ─────────────────────────────────────────────
          _infoRow('Session ID', '${session.id.substring(0, 8)}…'),
          _infoRow('Stroke count', session.strokeCount.toString()),
          _infoRow('Total points', session.totalPoints.toString()),
          pw.SizedBox(height: 16),

          // ── Feature tables ───────────────────────────────────────────────
          ..._featureSection('Spatial Features', _spatialKeys, session.features),
          pw.SizedBox(height: 8),
          ..._featureSection('Temporal Features', _temporalKeys, session.features),
          pw.SizedBox(height: 8),
          ..._featureSection('Dynamic Features', _dynamicKeys, session.features),
          pw.SizedBox(height: 8),
          ..._featureSection('Fluency Scores', _fluencyKeys, session.features),

          pw.SizedBox(height: 16),
          pw.Text(
            'Note: Irregularity index uses a weighted placeholder formula. '
            'Classification threshold: <35% Regular, 35–60% Mildly Irregular, >60% Irregular.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'WriteSense_${DateFormat('yyyyMMdd_HHmm').format(session.timestamp)}.pdf',
    );
  }

  PdfColor _scoreColor(double idx) {
    if (idx < 0.35) return PdfColors.green700;
    if (idx < 0.60) return PdfColors.orange700;
    return PdfColors.red700;
  }

  pw.Widget _infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.Text('$label: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ]),
      );

  List<pw.Widget> _featureSection(
    String title,
    List<String> keys,
    Map<String, double> features,
  ) {
    final rows = keys
        .where((k) => features.containsKey(k))
        .map((k) => pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(_formatKey(k),
                    style: const pw.TextStyle(fontSize: 10)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(_numFmt.format(features[k]!),
                    style: const pw.TextStyle(fontSize: 10)),
              ),
            ]))
        .toList();

    if (rows.isEmpty) return [];

    return [
      pw.Text(title,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Feature',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Value',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            ],
          ),
          ...rows,
        ],
      ),
    ];
  }

  String _formatKey(String k) =>
      k.replaceAll('_', ' ').replaceFirstMapped(RegExp(r'\w'), (m) => '${m[0]?.toUpperCase()}');
}

const _spatialKeys = [
  'stroke_length', 'bounding_width', 'bounding_height', 'aspect_ratio',
  'mean_slant', 'mean_curvature', 'straightness', 'writing_density',
  'baseline_deviation', 'center_of_mass_x', 'center_of_mass_y',
];
const _temporalKeys = [
  'total_duration', 'pen_down_duration', 'pen_down_ratio',
  'pause_count', 'mean_pause_duration', 'writing_tempo', 'rhythm_regularity',
];
const _dynamicKeys = [
  'mean_velocity', 'max_velocity', 'velocity_variance',
  'mean_acceleration', 'mean_jerk', 'normalized_jerk',
  'direction_changes', 'tremor_frequency', 'tremor_amplitude',
];
const _fluencyKeys = ['irregularity_index', 'fluency_score', 'consistency_score'];
