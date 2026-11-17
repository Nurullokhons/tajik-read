
import 'package:flutter_test/flutter_test.dart';
import 'package:tajik_read/paragraph_detector.dart';

void main() {
  test('splits only when all three conditions are true', () {
    final result = HocrParagraphDetector.detect([
      const OcrLine(text: 'Аввали матн тамом шуд.', left: 100, top: 10, right: 900, bottom: 40),
      const OcrLine(text: 'Нав сар мешавад.', left: 150, top: 55, right: 900, bottom: 85),
      const OcrLine(text: 'давоми сатр аст.', left: 100, top: 100, right: 900, bottom: 130),
    ]);
    expect(result.paragraphs, [
      'Аввали матн тамом шуд.',
      'Нав сар мешавад. давоми сатр аст.',
    ]);
  });

  test('does not split without punctuation', () {
    final result = HocrParagraphDetector.detect([
      const OcrLine(text: 'Ин ҷумла идома дорад,', left: 100, top: 10, right: 900, bottom: 40),
      const OcrLine(text: 'Ва ин идомаи он аст.', left: 150, top: 55, right: 900, bottom: 85),
    ]);
    expect(result.paragraphs, ['Ин ҷумла идома дорад, Ва ин идомаи он аст.']);
  });

  test('does not split without indent', () {
    final result = HocrParagraphDetector.detect([
      const OcrLine(text: 'Ҷумла ба охир расид.', left: 100, top: 10, right: 900, bottom: 40),
      const OcrLine(text: 'Давоми матн аст.', left: 100, top: 55, right: 900, bottom: 85),
    ]);
    expect(result.paragraphs, ['Ҷумла ба охир расид. Давоми матн аст.']);
  });

  test('does not split when next line starts lowercase', () {
    final result = HocrParagraphDetector.detect([
      const OcrLine(text: 'Ҷумла ба охир расид.', left: 100, top: 10, right: 900, bottom: 40),
      const OcrLine(text: 'давоми матн аст.', left: 150, top: 55, right: 900, bottom: 85),
    ]);
    expect(result.paragraphs, ['Ҷумла ба охир расид. давоми матн аст.']);
  });

  test('recognizes Tajik uppercase letters', () {
    for (final letter in ['Ғ', 'Ӣ', 'Қ', 'Ӯ', 'Ҳ', 'Ҷ']) {
      final result = HocrParagraphDetector.detect([
        const OcrLine(text: 'Анҷом.', left: 100, top: 10, right: 900, bottom: 40),
        OcrLine(text: '$letter оғоз мешавад.', left: 150, top: 55, right: 900, bottom: 85),
      ]);
      expect(result.paragraphs.length, 2);
    }
  });

  test('parses hOCR line boxes and text', () {
    const hocr = '<span class="ocr_line" title="bbox 100 10 900 40">'
        '<span class="ocrx_word">Салом</span> '
        '<span class="ocrx_word">дунё.</span></span>';
    final lines = HocrParagraphDetector.parseLines(hocr);
    expect(lines, hasLength(1));
    expect(lines.first.text, 'Салом дунё.');
    expect(lines.first.left, 100);
  });
}
