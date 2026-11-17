import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ReadingResult {
  const ReadingResult({
    required this.date,
    required this.wordsRead,
    required this.durationSeconds,
  });

  final DateTime date;
  final int wordsRead;
  final int durationSeconds;

  int get wordsPerMinute =>
      durationSeconds <= 0 ? 0 : (wordsRead * 60 / durationSeconds).round();

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'wordsRead': wordsRead,
        'durationSeconds': durationSeconds,
      };

  factory ReadingResult.fromJson(Map<String, dynamic> json) {
    return ReadingResult(
      date: DateTime.parse(json['date'] as String),
      wordsRead: json['wordsRead'] as int,
      durationSeconds: json['durationSeconds'] as int,
    );
  }
}

class StatisticsStore {
  static Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/tajik_read_statistics.json');
  }

  static Future<List<ReadingResult>> load() async {
    final file = await _getFile();
    if (!await file.exists()) return [];

    final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
    final results = decoded
        .map((item) => ReadingResult.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
    results.sort((a, b) => b.date.compareTo(a.date));
    return results;
  }

  static Future<void> add(ReadingResult result) async {
    final results = await load();
    results.insert(0, result);
    final file = await _getFile();
    await file.writeAsString(
      jsonEncode(results.map((item) => item.toJson()).toList()),
      flush: true,
    );
  }
}
