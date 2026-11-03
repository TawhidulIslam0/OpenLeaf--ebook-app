import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:iridium_reader_widget/views/viewers/epub_screen.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_ebook_app/src/features/library/data/persistent_reader_annotations.dart';
import 'package:flutter_ebook_app/src/features/library/data/reading_shelf.dart';

class EpubReaderScreen extends StatefulWidget {
  const EpubReaderScreen({
    super.key,
    required this.bookId,
    required this.filePath,
  });

  final String bookId;
  final String filePath;

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  static const _settingsKey = 'openleaf.reader.settings.v1';
  final FlutterTts _textToSpeech = FlutterTts();
  Map<String, dynamic> _savedSettings = {
    'fontSize': 100,
    'theme': null,
    'landscape': false,
    'brightness': 1.0,
    'speechRate': 0.5,
  };
  String? _selectedText;
  String? _speechText;
  int _speechOffset = 0;
  int _speechBaseOffset = 0;
  bool _isSpeaking = false;
  bool _isPaused = false;
  final Stopwatch _readingSession = Stopwatch();
  late final Future<Map<String, dynamic>> _settings = _loadSettings();

  Future<Map<String, dynamic>> _loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_settingsKey);
    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['fontSize'] is! int) {
        throw const FormatException('Saved reader settings are invalid.');
      }
      if (decoded['theme'] != null && decoded['theme'] is! Map) {
        throw const FormatException('Saved reader theme is invalid.');
      }
      _savedSettings = {
        ..._savedSettings,
        ...Map<String, dynamic>.from(decoded),
      };
    }
    await _applyReaderPreferences();
    return Map<String, dynamic>.from(_savedSettings);
  }

  void _saveSettings(Map<String, dynamic> settings) {
    _savedSettings = {..._savedSettings, ...settings};
    unawaited(
      _persistSettings().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Could not save reading settings: $error\n$stackTrace');
      }),
    );
  }

  Future<void> _persistSettings() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_settingsKey, jsonEncode(_savedSettings));
  }

  Future<void> _applyReaderPreferences() async {
    final landscape = _savedSettings['landscape'] == true;
    await SystemChrome.setPreferredOrientations(
      landscape
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
    await ScreenBrightness.instance.setApplicationScreenBrightness(
      (_savedSettings['brightness'] as num).toDouble(),
    );
  }

  Future<void> _setLandscape(bool landscape) async {
    _savedSettings['landscape'] = landscape;
    await _applyReaderPreferences();
    await _persistSettings();
  }

  Future<void> _setBrightness(double brightness) async {
    _savedSettings['brightness'] = brightness;
    await ScreenBrightness.instance.setApplicationScreenBrightness(brightness);
    await _persistSettings();
  }

  Future<void> _speak(String text, {int offset = 0}) async {
    final startOffset = offset.clamp(0, text.length);
    _speechText = text;
    _speechOffset = startOffset;
    _speechBaseOffset = startOffset;
    await _textToSpeech.setSpeechRate(
      (_savedSettings['speechRate'] as num).toDouble(),
    );
    await _textToSpeech.speak(text.substring(startOffset));
    if (mounted) {
      setState(() {
        _isSpeaking = true;
        _isPaused = false;
      });
    }
  }

  Future<void> _pauseSpeech() async {
    await _textToSpeech.pause();
    if (mounted) setState(() => _isPaused = true);
  }

  Future<void> _stopSpeech() async {
    await _textToSpeech.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
      });
    }
  }

  Future<void> _showReaderTools() async {
    var brightness = (_savedSettings['brightness'] as num).toDouble();
    var landscape = _savedSettings['landscape'] == true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reader settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.brightness_6_outlined),
                  Expanded(
                    child: Slider(
                      label: '${(brightness * 100).round()}%',
                      value: brightness,
                      onChanged: (value) {
                        setDialogState(() => brightness = value);
                        unawaited(
                            _saveToolSetting(() => _setBrightness(value)));
                      },
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Landscape reading'),
                value: landscape,
                onChanged: (value) {
                  setDialogState(() => landscape = value);
                  unawaited(_saveToolSetting(() => _setLandscape(value)));
                },
              ),
              Slider(
                label:
                    'Speech rate ${(_savedSettings['speechRate'] as num).toStringAsFixed(1)}',
                min: 0.2,
                max: 0.8,
                value: (_savedSettings['speechRate'] as num).toDouble(),
                onChanged: (value) {
                  setDialogState(() => _savedSettings['speechRate'] = value);
                  unawaited(_saveToolSetting(_persistSettings));
                },
              ),
              const Text('Text-to-speech speed'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToolSetting(Future<void> Function() save) async {
    try {
      await save();
    } catch (error, stackTrace) {
      debugPrint('Could not apply reader setting: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save this reader setting: $error')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _readingSession.start();
    _textToSpeech.setProgressHandler(
      (String text, int start, int end, String word) {
        _speechOffset = _speechBaseOffset + start;
      },
    );
    _textToSpeech.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isPaused = false;
          _speechOffset = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _readingSession.stop();
    unawaited(
      ReadingShelf.addReadingTime(
        id: widget.bookId,
        seconds: _readingSession.elapsed.inSeconds,
      ).catchError((Object error, StackTrace stackTrace) {
        debugPrint('Could not save reading time: $error\n$stackTrace');
      }),
    );
    unawaited(_textToSpeech.stop());
    unawaited(ScreenBrightness.instance.resetApplicationScreenBrightness());
    unawaited(SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp],
    ));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _settings,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Reader settings error')),
              body: Center(
                child: Text(
                  'Could not load your saved reading settings: '
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final settings = snapshot.data!;
          return Stack(
            children: [
              EpubScreen.fromPath(
                filePath: widget.filePath,
                readerAnnotationRepository:
                    PersistentReaderAnnotationRepository(widget.bookId),
                paginationCallback: (pagination) {
                  unawaited(
                    ReadingShelf.updateProgress(
                      id: widget.bookId,
                      progress: pagination.percent,
                      position: pagination.locator.json,
                    ).catchError((Object error, StackTrace stackTrace) {
                      debugPrint(
                        'Could not save reading progress: $error\n$stackTrace',
                      );
                    }),
                  );
                },
                settings: '${settings['fontSize']}',
                theme: jsonEncode(settings['theme']),
                onSettingsChanged: _saveSettings,
                onTextSelected: (text) => setState(() {
                  _selectedText = text;
                  _speechText = text;
                  _speechOffset = 0;
                }),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    tooltip: 'Reader tools',
                    onPressed: _showReaderTools,
                    icon: const Icon(Icons.tune),
                  ),
                ),
              ),
              if (_selectedText != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 72,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.record_voice_over_outlined),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedText!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip:
                                _isPaused ? 'Resume reading' : 'Read aloud',
                            onPressed: _isSpeaking && !_isPaused
                                ? null
                                : () => unawaited(
                                      _speak(
                                        _speechText ?? _selectedText!,
                                        offset: _isPaused ? _speechOffset : 0,
                                      ),
                                    ),
                            icon: Icon(
                                _isPaused ? Icons.play_arrow : Icons.volume_up),
                          ),
                          if (_isSpeaking && !_isPaused)
                            IconButton(
                              tooltip: 'Pause reading',
                              onPressed: () => unawaited(_pauseSpeech()),
                              icon: const Icon(Icons.pause),
                            ),
                          IconButton(
                            tooltip: 'Stop reading',
                            onPressed: () => unawaited(_stopSpeech()),
                            icon: const Icon(Icons.stop),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}
