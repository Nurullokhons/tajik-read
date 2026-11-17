import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';


class ReaderProfile {
  const ReaderProfile({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory ReaderProfile.fromJson(Map<String, dynamic> json) => ReaderProfile(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

class ProfileStore {
  static Future<File> _profilesFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/tajik_read_profiles.json');
  }

  static Future<File> _activeFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/tajik_read_active_profile.txt');
  }

  static Future<List<ReaderProfile>> load() async {
    final file = await _profilesFile();
    if (!await file.exists()) return [];
    final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
    return decoded
        .map((item) => ReaderProfile.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  static Future<void> add(ReaderProfile profile) async {
    final profiles = await load();
    profiles.add(profile);
    final file = await _profilesFile();
    await file.writeAsString(
      jsonEncode(profiles.map((item) => item.toJson()).toList()),
      flush: true,
    );
  }

  static Future<String?> loadActiveId() async {
    final file = await _activeFile();
    if (!await file.exists()) return null;
    final value = (await file.readAsString()).trim();
    return value.isEmpty ? null : value;
  }

  static Future<void> setActiveId(String id) async {
    final file = await _activeFile();
    await file.writeAsString(id, flush: true);
  }
}

class ReadingResult {
  const ReadingResult({
    required this.date,
    required this.wordsRead,
    required this.durationSeconds,
    this.profileId = 'default',
  });

  final DateTime date;
  final int wordsRead;
  final int durationSeconds;
  final String profileId;

  int get wordsPerMinute =>
      durationSeconds <= 0 ? 0 : (wordsRead * 60 / durationSeconds).round();

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'wordsRead': wordsRead,
        'durationSeconds': durationSeconds,
        'profileId': profileId,
      };

  factory ReadingResult.fromJson(Map<String, dynamic> json) {
    return ReadingResult(
      date: DateTime.parse(json['date'] as String),
      wordsRead: json['wordsRead'] as int,
      durationSeconds: json['durationSeconds'] as int,
      profileId: json['profileId'] as String? ?? 'default',
    );
  }
}

class StatisticsStore {
  static Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/tajik_read_statistics.json');
  }

  static Future<List<ReadingResult>> load({String? profileId}) async {
    final file = await _getFile();
    if (!await file.exists()) return [];

    final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
    final results = decoded
        .map((item) => ReadingResult.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
    results.sort((a, b) => b.date.compareTo(a.date));
    if (profileId != null) {
      return results.where((item) => item.profileId == profileId).toList();
    }
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

