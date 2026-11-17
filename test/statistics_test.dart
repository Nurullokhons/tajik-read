import 'package:flutter_test/flutter_test.dart';
import 'package:tajik_read/statistics.dart';

void main() {
  test('calculates words per minute for a full minute', () {
    final result = ReadingResult(
      date: DateTime(2026, 11, 17),
      wordsRead: 85,
      durationSeconds: 60,
    );
    expect(result.wordsPerMinute, 85);
  });

  test('normalizes an early finish to words per minute', () {
    final result = ReadingResult(
      date: DateTime(2026, 11, 17),
      wordsRead: 30,
      durationSeconds: 20,
    );
    expect(result.wordsPerMinute, 90);
  });

  test('does not divide by zero', () {
    final result = ReadingResult(
      date: DateTime(2026, 11, 17),
      wordsRead: 10,
      durationSeconds: 0,
    );
    expect(result.wordsPerMinute, 0);
  });

  test('serializes and restores a result', () {
    final original = ReadingResult(
      date: DateTime(2026, 11, 17, 12, 30),
      wordsRead: 42,
      durationSeconds: 30,
    );
    final restored = ReadingResult.fromJson(original.toJson());
    expect(restored.date, original.date);
    expect(restored.wordsRead, original.wordsRead);
    expect(restored.durationSeconds, original.durationSeconds);
    expect(restored.wordsPerMinute, 84);
  });
}
