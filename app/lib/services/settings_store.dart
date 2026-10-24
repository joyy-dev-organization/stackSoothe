import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';
import 'notebook_store.dart';

/// Atomic local persistence for [AppSettings] (`settings.json`).
///
/// Explicitly excludes runtime bearer tokens (`serviceToken`) from disk storage.
class SettingsStore {
  static const String fileName = 'settings.json';
  final Directory storageDirectory;
  AppSettings _settings = const AppSettings();

  SettingsStore({Directory? storageDirectory})
      : storageDirectory =
            storageDirectory ?? NotebookStore.resolveDefaultStorageDirectory();

  File get settingsFile =>
      File('${storageDirectory.path}${Platform.pathSeparator}$fileName');

  AppSettings get settings => _settings;

  AppSettings load() {
    final file = settingsFile;
    if (!file.existsSync()) {
      _settings = const AppSettings();
      return _settings;
    }

    try {
      final raw = file.readAsStringSync();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final hadForbiddenToken = decoded.containsKey('service_token') ||
            decoded.containsKey('serviceToken') ||
            decoded.containsKey('token');
        _settings = AppSettings.fromJson(decoded);
        if (hadForbiddenToken) {
          // Immediately rewrite clean settings file without token
          save(_settings);
        }
        return _settings;
      }
    } catch (_) {
      // On malformed settings file, fall back to safe defaults
    }
    _settings = const AppSettings();
    return _settings;
  }

  void save(AppSettings updated) {
    _settings = updated;
    if (!storageDirectory.existsSync()) {
      storageDirectory.createSync(recursive: true);
    }

    final encoded =
        const JsonEncoder.withIndent('  ').convert(updated.toJson());
    final target = settingsFile;
    final tmp = File(
      '${target.path}.tmp.${DateTime.now().toUtc().microsecondsSinceEpoch}',
    );
    tmp.writeAsStringSync(encoded, flush: true);
    try {
      tmp.renameSync(target.path);
    } catch (_) {
      if (target.existsSync()) {
        target.deleteSync();
      }
      tmp.renameSync(target.path);
    }
  }
}
