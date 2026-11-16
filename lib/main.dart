import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

void main() => runApp(const TajikReadApp());

class TajikReadApp extends StatelessWidget {
  const TajikReadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tajik Read',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF16845B)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8F7),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
      final text = await TesseractOcr.extractText(
        correctedPath,
        config: OCRConfig(
          language: 'tgk',
          engine: OCREngine.tesseract,
          options: const {
            'preserve_interword_spaces': '1',
            'tessedit_pageseg_mode': '3',
          },
        ),
      );
      if (!mounted) return;
      _textController.text = _tidyOcrText(text);
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
    return input
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  void _startReading() {
    final words = splitWords(_textController.text);
    if (words.isEmpty) {
      setState(() => _error = 'Аввал матнро акс гиред ё ворид кунед.');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReadingScreen(words: words),
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
        title: const Text('Tajik Read', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F4ED),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Суръати хониши худро санҷед',
                      style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text('Саҳифаро акс гиред, матнро санҷед ва дар 60 сония чанд калима хонданатонро муайян кунед.'),
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
            const Text('Матни шинохташуда',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
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
            const SizedBox(height: 12),
            const Text(
              'Эзоҳ: ҳоло OCR танҳо бо модели тоҷикӣ кор мекунад. Барои сохтани APK модели tgk.traineddata бояд ба assets/tessdata гузошта шавад.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

List<String> splitWords(String text) => text
    .trim()
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .toList();

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key, required this.words});
  final List<String> words;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  Timer? _timer;
  int _secondsLeft = 60;
  int _index = 0;
  int _readCount = 0;
  bool _finished = false;
  @override
  void initState() {
    super.initState();
    // The full minute starts as soon as the reading screen opens.
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _secondsLeft = 0;
            _finished = true;
          });
        }
      } else if (mounted) {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _markRead() {
    if (_finished) return;
    setState(() {
      _readCount++;
      if (_index < widget.words.length - 1) {
        _index++;
      } else {
        _finished = true;
        _timer?.cancel();
      }
    });
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
                const Icon(Icons.emoji_events_outlined, size: 64, color: Color(0xFF16845B)),
                const SizedBox(height: 16),
                const Text('Шумо хондед', style: TextStyle(fontSize: 20)),
                Text('$_readCount',
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900)),
                const Text('калима дар як дақиқа',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Ба матн баргаштан'),
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
                onPressed: () {
                  _timer?.cancel();
                  setState(() => _finished = true);
                },
                child: const Text('Анҷом додан'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
