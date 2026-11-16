import 'package:flutter_test/flutter_test.dart';
import 'package:tajik_read/main.dart';

void main() {
  test('splits Tajik Cyrillic text into words', () {
    expect(splitWords('Салом  дунё!\nЧӣ хел?'),
        ['Салом', 'дунё!', 'Чӣ', 'хел?']);
  });
}
