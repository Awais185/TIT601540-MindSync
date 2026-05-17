import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a simple multi-page PDF for the in-app 7-day report (plain text).
class WeekReportPdfBuilder {
  static Future<Uint8List> build({
    required String name,
    required String email,
    required String? dynamicTitle,
    required String? dynamicBody,
    required int sleepQualityScore,
    required double dayScreenHours,
    required int lateNightWeekSeconds,
    required int lateNightOpensWeek,
    required List<int> lateNightByDaySeconds,
    required List<String> lateNightAppLines,
    required List<double> dailyScreenHours,
    required List<double> moodSeries,
    required int wellbeingScore,
    required int moodStability,
  }) async {
    final doc = pw.Document();
    final generated = '${DateTime.now().toUtc().toIso8601String().split('.').first}Z';

    String fmtHm(int sec) {
      if (sec <= 0) return '0m';
      final h = sec ~/ 3600;
      final m = (sec % 3600) ~/ 60;
      if (h <= 0) return '${m}m';
      return '${h}h ${m}m';
    }

    final lines = <String>[
      'MindSync — 7-day wellbeing report',
      'Generated (UTC): $generated',
      '',
      'User: $name',
      'Email: $email',
      '',
      'Summary KPIs',
      '- Wellbeing score (estimate): $wellbeingScore',
      '- Mood stability (estimate): $moodStability',
      '- Sleep quality score (from late-night usage): $sleepQualityScore / 100',
      '- Today screen time (approx): ${dayScreenHours.toStringAsFixed(1)} h',
      '',
      'Late night phone use (10 PM – 5 AM, last 7 local days)',
      '- Total: ${fmtHm(lateNightWeekSeconds)}',
      '- Foreground opens / switches (approx): $lateNightOpensWeek',
      '- By day (oldest → newest, seconds in window): ${lateNightByDaySeconds.join(", ")}',
      if (lateNightAppLines.isNotEmpty) ...<String>[
        '',
        'Top late-night apps:',
        ...lateNightAppLines.map((s) => '- $s'),
      ],
      '',
      'Daily screen (h) — Mon→Sun chart data',
      dailyScreenHours.map((e) => e.toStringAsFixed(2)).join(', '),
      '',
      'Mood series (same order)',
      moodSeries.map((e) => e.toStringAsFixed(1)).join(', '),
      '',
      if (dynamicTitle != null && dynamicTitle.trim().isNotEmpty) ...<String>[
        'AI / server summary — title',
        dynamicTitle.trim(),
        '',
      ],
      if (dynamicBody != null && dynamicBody.trim().isNotEmpty) ...<String>[
        'AI / server summary — body',
        dynamicBody.trim(),
      ],
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          pw.Text(
            lines.join('\n'),
            style: pw.TextStyle(fontSize: 10, height: 1.35),
          ),
        ],
      ),
    );

    final out = await doc.save();
    return Uint8List.fromList(out);
  }
}
