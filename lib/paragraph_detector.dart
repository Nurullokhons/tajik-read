
class OcrLine {
  const OcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final int left, top, right, bottom;
}

class ParagraphDetectionResult {
  const ParagraphDetectionResult(this.paragraphs, this.lines);
  final List<String> paragraphs;
  final List<OcrLine> lines;
  String get text => paragraphs.join('\n\n');
}

class HocrParagraphDetector {
  static List<OcrLine> parseLines(String hocr) {
    // Find line opening tags first. hOCR nests word spans inside line spans,
    // so matching from one <span> to the first </span> would truncate words.
    final lineOpen = RegExp(
  r"""<span\b(?=[^>]*class=["'][^"']*\bocrx?_line\b[^"']*["'])[^>]*>""",
  caseSensitive: false,
);
    final bbox = RegExp(r'\bbbox\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)');
    final tags = RegExp(r'<[^>]+>');
    final matches = lineOpen.allMatches(hocr).toList();
    final lines = <OcrLine>[];

    for (var i = 0; i < matches.length; i++) {
      final opening = matches[i].group(0)!;
      final box = bbox.firstMatch(opening);
      if (box == null) continue;
      final contentStart = matches[i].end;
      final contentEnd = i + 1 < matches.length
          ? matches[i + 1].start
          : hocr.length;
      var text = hocr.substring(contentStart, contentEnd);
      // Remove closing tags and any enclosing block markup after this line.
      final nextClose = text.indexOf('</span>');
      if (nextClose >= 0) {
        // Keep nested word text; only trim at the first close when there are
        // no subsequent word spans. For standard Tesseract hOCR the next line
        // boundary above is the reliable delimiter.
        text = text.replaceAll('</span>', ' ');
      }
      text = text
          .replaceAll(tags, ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('&nbsp;', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (text.isEmpty) continue;
      lines.add(OcrLine(
        text: text,
        left: int.parse(box.group(1)!),
        top: int.parse(box.group(2)!),
        right: int.parse(box.group(3)!),
        bottom: int.parse(box.group(4)!),
      ));
    }
    lines.sort((a, b) {
      final byTop = a.top.compareTo(b.top);
      return byTop != 0 ? byTop : a.left.compareTo(b.left);
    });
    return lines;
  }

  static ParagraphDetectionResult detectFromHocr(String hocr) =>
      detect(parseLines(hocr));

  static ParagraphDetectionResult detect(List<OcrLine> lines) {
    if (lines.isEmpty) {
      return const ParagraphDetectionResult([], []);
    }

    final starts = lines.map((line) => line.left).toList()..sort();
    // Lower quartile estimates the body text's normal left margin.
    final baseline = starts[(starts.length * 0.25).floor()];
    final pageWidth = lines
        .map((line) => line.right)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final indentThreshold = (pageWidth * 0.012).round().clamp(8, 36);

    final paragraphs = <String>[];
    var current = lines.first.text;

    for (var i = 1; i < lines.length; i++) {
      final previous = lines[i - 1].text.trim();
      final next = lines[i];
      final endsSentence = RegExp(r'[.!?]["»”’)\]]*$').hasMatch(previous);
      final isIndented = next.left >= baseline + indentThreshold;
      final startsUppercase = _startsWithUppercase(next.text);

      if (endsSentence && isIndented && startsUppercase) {
        paragraphs.add(current.trim());
        current = next.text;
      } else {
        current = '$current ${next.text}';
      }
    }
    paragraphs.add(current.trim());

    return ParagraphDetectionResult(
      paragraphs.where((p) => p.isNotEmpty).toList(),
      List.unmodifiable(lines),
    );
  }

  static bool _startsWithUppercase(String text) {
    final value = text.trimLeft();
    if (value.isEmpty) return false;
    final first = String.fromCharCode(value.runes.first);
    return first.toUpperCase() == first &&
        first.toLowerCase() != first.toUpperCase();
  }
}
