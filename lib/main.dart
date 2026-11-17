import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'paragraph_detector.dart';
import 'statistics.dart';

void main() => runApp(const TajikReadApp());

class TajikReadApp extends StatelessWidget {
  const TajikReadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Тезхон',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B4B)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9F7),
      ),
      home: const ProfileSelectionScreen(),
    );
  }
}


class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  List<ReaderProfile> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await ProfileStore.load();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _loading = false;
    });

  }

  Future<void> _openProfile(ReaderProfile profile, {bool replace = false}) async {
    await ProfileStore.setActiveId(profile.id);
    if (!mounted) return;
    final page = MaterialPageRoute(
      builder: (_) => HomeScreen(profile: profile),
    );
    if (replace) {
      Navigator.of(context).pushReplacement(page);
    } else {
      Navigator.of(context).pushReplacement(page);
    }
  }

  Future<void> _addProfile() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новый профиль'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Имя',
            hintText: 'Введите имя ребёнка',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    controller.dispose();

    final cleanName = name?.trim() ?? '';
    if (cleanName.isEmpty) return;

    final id = _profiles.isEmpty ? 'default' : DateTime.now().microsecondsSinceEpoch.toString();
    final profile = ReaderProfile(id: id, name: cleanName);
    await ProfileStore.add(profile);
    if (!mounted) return;
    await _openProfile(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тезхон'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  const SizedBox(height: 18),
                  const Icon(Icons.menu_book_rounded,
                      size: 54, color: Color(0xFF176B4B)),
                  const SizedBox(height: 12),
                  const Text(
                    'Кӣ имрӯз мехонад?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Профилро интихоб кунед ё профили нав созед.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  ..._profiles.map((profile) => Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE5F3EA),
                            child: Text(
                              profile.name.isEmpty
                                  ? '?'
                                  : profile.name.characters.first.toUpperCase(),
                              style: const TextStyle(
                                  color: Color(0xFF176B4B),
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                          title: Text(profile.name,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openProfile(profile),
                        ),
                      )),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addProfile,
                    icon: const Icon(Icons.add),
                    label: const Text('Илова кардани профил'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                  ),
                ],
              ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.profile});
  final ReaderProfile profile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  final _textController = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _chooseImage(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 2600,
      );
      if (picked == null) return;

      final correctedPath = await _normalizeOrientation(picked.path);
      const ocrConfig = OCRConfig(
        language: 'tgk',
        engine: OCREngine.tesseract,
        options: {
          'preserve_interword_spaces': '1',
          'tessedit_pageseg_mode': '3',
        },
      );

      // hOCR preserves recognized line coordinates for paragraph detection.
      final hocr = await TesseractOcr.extractHocr(
        correctedPath,
        config: ocrConfig,
      );
      final detected = HocrParagraphDetector.detectFromHocr(hocr);

      // Plain-text fallback protects the existing flow if hOCR is empty.
      final recognizedText = detected.lines.isNotEmpty
          ? detected.text
          : _tidyOcrText(await TesseractOcr.extractText(
              correctedPath,
              config: ocrConfig,
            ));

      if (!mounted) return;
      _textController.text = recognizedText;
      if (_textController.text.trim().isEmpty) {
        setState(() => _error = 'Матнро шинохтан муяссар нашуд. Сурати дигар гиред.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'Хатои OCR. Санҷед, ки файли tgk.traineddata ба assets илова шудааст.\n$e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _normalizeOrientation(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return path;
    final oriented = img.bakeOrientation(decoded);
    final temp = await getTemporaryDirectory();
    final output = File('${temp.path}/tajik_read_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await output.writeAsBytes(img.encodeJpg(oriented, quality: 94));
    return output.path;
  }

  String _tidyOcrText(String input) {
    // Tesseract usually emits blank lines between layout paragraphs
    // and single newlines for line wraps.
    return normalizeOcrParagraphs(input);
  }

  void _startReading() {
    final words = splitWords(_textController.text);
    if (words.isEmpty) {
      setState(() => _error = 'Аввал матнро акс гиред ё ворид кунед.');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReadingScreen(words: words, profileId: widget.profile.id),
    ));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тезхон', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Иваз кардани профил',
            icon: const Icon(Icons.switch_account_outlined),
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
              (route) => false,
            ),
          ),
          IconButton(
            tooltip: 'Омори натиҷаҳо',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => StatisticsScreen(profileId: widget.profile.id)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE5F3EA),
                child: Text(
                  widget.profile.name.isEmpty
                      ? '?'
                      : widget.profile.name.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF176B4B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(
                widget.profile.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Профили фаъол'),
              trailing: TextButton.icon(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
                  (route) => false,
                ),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Иваз'),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFE5F3EA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Суръати хониши худро санҷед',
                      style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text('Китобро кушо, тезтар бихон ва суръати хониши худро дар 60 сония бисанҷ!'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _chooseImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Акс гирифтан'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _chooseImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Галерея'),
                  ),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(child: Text('Матн шинохта мешавад...')),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Матни шинохташуда',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(
                  'Калимаҳо: ${splitWords(_textController.text).length}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              onChanged: (_) => setState(() {}),
              minLines: 9,
              maxLines: 16,
              textAlign: TextAlign.justify,
              decoration: InputDecoration(
                hintText: 'Ин ҷо матни тоҷикӣ пайдо мешавад. Агар лозим бошад, хатоҳоро ислоҳ кунед...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _startReading,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              child: const Text('Оғози хониш · 60 сония',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Joins OCR line wraps but preserves blank lines as paragraph boundaries.
String normalizeOcrParagraphs(String input) {
  final normalized = input
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();
  if (normalized.isEmpty) return '';

  final dehyphenated = normalized.replaceAll(RegExp(r'-\\n[ \\t]*'), '');
  final blocks = dehyphenated
      .split(RegExp(r'\n[ \t]*\n+'))
      .map((block) => block
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .join(' '))
      .where((block) => block.isNotEmpty);

  return blocks.join('\n\n');
}

List<String> parseParagraphs(String text) => text
    .split(RegExp(r'\n[ \t]*\n+'))
    .map((paragraph) => paragraph.trim())
    .where((paragraph) => paragraph.isNotEmpty)
    .toList();

List<String> splitWords(String text) => text
    .trim()
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .toList();

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key, required this.profileId});
  final String profileId;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<List<ReadingResult>> _resultsFuture;

  @override
  void initState() {
    super.initState();
    _resultsFuture = StatisticsStore.load(profileId: widget.profileId);
  }

  String _dateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.${date.year} · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Омори хониш')),
      body: FutureBuilder<List<ReadingResult>>(
        future: _resultsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Омори натиҷаҳоро кушодан муяссар нашуд.'));
          }

          final results = snapshot.data ?? [];
          if (results.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_graph, size: 64, color: Color(0xFF176B4B)),
                    SizedBox(height: 16),
                    Text(
                      'Ҳоло натиҷа нест',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Пас аз анҷоми санҷиши аввал натиҷаҳо дар ин ҷо нигоҳ дошта мешаванд.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final speeds = results.map((item) => item.wordsPerMinute).toList();
          final best = speeds.reduce((a, b) => a > b ? a : b);
          final average = (speeds.reduce((a, b) => a + b) / speeds.length).round();
          final totalWords = results.fold<int>(0, (sum, item) => sum + item.wordsRead);
          final recent = results.take(7).toList();
          final chartMax = recent
              .map((item) => item.wordsPerMinute)
              .fold<int>(1, (a, b) => a > b ? a : b);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  _StatCard(title: 'Беҳтарин суръат', value: '$best', suffix: 'калима/дақ'),
                  _StatCard(title: 'Суръати миёна', value: '$average', suffix: 'калима/дақ'),
                  _StatCard(title: 'Санҷишҳо', value: '${results.length}', suffix: 'бор'),
                  _StatCard(title: 'Ҳамаи калимаҳо', value: '$totalWords', suffix: 'калима'),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Пешрафти охирин',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ...recent.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_dateLabel(item.date),
                                style: const TextStyle(color: Colors.black54, fontSize: 12)),
                            Text('${item.wordsPerMinute} калима/дақ',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: item.wordsPerMinute / chartMax,
                            minHeight: 9,
                            backgroundColor: const Color(0xFFE5EAE7),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              const Text(
                'Таърихи санҷишҳо',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...results.map((item) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.menu_book_outlined),
                      ),
                      title: Text('${item.wordsPerMinute} калима дар як дақиқа'),
                      subtitle: Text(
                        '${item.wordsRead} калима · ${item.durationSeconds} сония · ${_dateLabel(item.date)}',
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.suffix,
  });

  final String title;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F3EA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 5),
          Text(value,
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
          Text(suffix, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key, required this.words, required this.profileId});
  final List<String> words;
  final String profileId;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  Timer? _timer;
  late final DateTime _startedAt;
  bool _resultSaved = false;
  int _secondsLeft = 60;
  int _index = 0;
  int _readCount = 0;
  bool _finished = false;
  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    // The full minute starts as soon as the reading screen opens.
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _secondsLeft = 0);
          _finishReading();
        }
      } else if (mounted) {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _markRead() {
    if (_finished) return;
    if (_index >= widget.words.length - 1) {
      setState(() => _readCount++);
      _finishReading();
      return;
    }
    setState(() {
      _readCount++;
      _index++;
    });
  }

  Future<void> _finishReading() async {
    if (_resultSaved || _finished) return;
    _timer?.cancel();
    final elapsed = DateTime.now().difference(_startedAt).inSeconds;
    final duration = elapsed.clamp(1, 60).toInt();

    setState(() => _finished = true);
    _resultSaved = true;

    try {
      await StatisticsStore.add(ReadingResult(
        date: DateTime.now(),
        wordsRead: _readCount,
        durationSeconds: duration,
        profileId: widget.profileId,
      ));
    } catch (error) {
      debugPrint('Could not save reading result: $error');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeLabel {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return Scaffold(
        appBar: AppBar(title: const Text('Натиҷа')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_outlined, size: 64, color: Color(0xFF176B4B)),
                const SizedBox(height: 16),
                const Text('Шумо хондед', style: TextStyle(fontSize: 20)),
                Text('$_readCount',
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900)),
                const Text('калима хонда шуд',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'Суръат: ${( _readCount * 60 / DateTime.now().difference(_startedAt).inSeconds.clamp(1, 60)).round()} калима/дақиқа',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Ба матн баргаштан'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => StatisticsScreen(profileId: widget.profileId)),
                  ),
                  icon: const Icon(Icons.insights_outlined),
                  label: const Text('Омори натиҷаҳо'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Хониш')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ВАҚТ', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                  Text(_timeLabel,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, fontFeatures: [])),
                ],
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(value: _secondsLeft / 60, minHeight: 7),
              const Spacer(),
              Text(
                widget.words[_index],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              Text('Калимаи ${_index + 1} аз ${widget.words.length}',
                  style: const TextStyle(color: Colors.black54)),
              const Spacer(),
              Text('Хонда шуд: $_readCount',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton(
                  onPressed: _markRead,
                  child: const Text('ХОНДАМ  →',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _finishReading,
                child: const Text('Анҷом додан'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
