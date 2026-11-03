import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:iridium_reader_widget/views/viewers/epub_screen.dart';
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
  late final Future<Map<String, dynamic>> _settings = _loadSettings();

  Future<Map<String, dynamic>> _loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_settingsKey);
    if (raw == null) return {'fontSize': 100, 'theme': null};

    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['fontSize'] is! int ||
        decoded['theme'] is! Map) {
      throw const FormatException('Saved reader settings are invalid.');
    }
    return {
      'fontSize': decoded['fontSize'],
      'theme': Map<String, dynamic>.from(decoded['theme'] as Map),
    };
  }

  void _saveSettings(Map<String, dynamic> settings) {
    unawaited(
      _persistSettings(settings)
          .catchError((Object error, StackTrace stackTrace) {
        debugPrint('Could not save reading settings: $error\n$stackTrace');
      }),
    );
  }

  Future<void> _persistSettings(Map<String, dynamic> settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_settingsKey, jsonEncode(settings));
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
          return EpubScreen.fromPath(
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
          );
        },
      );
}
