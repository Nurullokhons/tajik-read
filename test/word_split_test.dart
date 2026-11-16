import 'package:flutter_test/flutter_test.dart';
import 'package:tajik_read/main.dart';

void main() {
  test('splits Tajik Cyrillic text into words', () {
    expect(splitWords('Салом  дунё!\nЧӣ хел?'),
        ['Салом', 'дунё!', 'Чӣ', 'хел?']);
  });

  test('joins wrapped lines inside one paragraph', () {
    expect(normalizeOcrParagraphs('Имрӯз ҳаво хуб аст ва мо\nба боғ рафтем.'),
        'Имрӯз ҳаво хуб аст ва мо ба боғ рафтем.');
  });

  test('preserves blank lines as paragraph boundaries', () {
    expect(
      normalizeOcrParagraphs('Абзаци якум\nсатри дуюм.\n\nАбзаци дуюм.'),
      'Абзаци якум сатри дуюм.\n\nАбзаци дуюм.',
    );
    expect(parseParagraphs('Абзаци якум сатри дуюм.\n\nАбзаци дуюм.'),
        ['Абзаци якум сатри дуюм.', 'Абзаци дуюм.']);
  });

  test('paragraph boundaries do not add reading words', () {
    expect(splitWords('Салом дунё.\n\nЧӣ хел?'),
        ['Салом', 'дунё.', 'Чӣ', 'хел?']);
  });
}
