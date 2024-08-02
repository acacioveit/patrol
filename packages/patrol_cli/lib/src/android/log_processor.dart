import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:patrol_cli/src/base/logger.dart';

/// Processes logcat output, writing it to a file and looking for observatory
class LogProcessor {
  LogProcessor(
      this.deviceId, this.logFilePath, this.onObservatoryUri, this._logger);
  final String deviceId;
  final String logFilePath;
  final void Function(String) onObservatoryUri;
  final Logger _logger;

  StreamSubscription<dynamic>? _logSubscription;
  IOSink? _logSink;

  /// Starts the logcat stream and writes to a file
  Future<void> start() async {
    await _clearLogcatCache();
    await _startLogcatStream();
  }

  /// Stops the logcat stream
  Future<void> stop() async {
    await _logSubscription?.cancel();
    await _logSink?.close();
  }

  Future<void> _clearLogcatCache() async {
    try {
      final result = await Process.run('adb', ['-s', deviceId, 'logcat', '-c']);
      if (result.exitCode != 0) {
        _logger.err('Failed to clear logcat cache: ${result.stderr}');
      }
    } catch (e) {
      _logger.err('Error clearing logcat cache: $e');
    }
  }

  Future<void> _startLogcatStream() async {
    final logFile = File(logFilePath);
    _logSink = logFile.openWrite(mode: FileMode.writeOnly);

    final logcatProcess =
        await Process.start('adb', ['-s', deviceId, 'logcat']);

    _logSubscription = logcatProcess.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_processLogLine);

    logcatProcess.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _logger.err('Logcat error: $line'));
  }

  void _processLogLine(String line) {
    _logSink?.writeln(line);
    _checkForObservatoryUri(line);
  }

  void _checkForObservatoryUri(String line) {
    final match = RegExp(r'The Dart VM service is listening on (http://[^\s]+)')
        .firstMatch(line);
    if (match != null) {
      final observatoryUri = match.group(1);
      if (observatoryUri != null) {
        onObservatoryUri(observatoryUri);
      }
    }
  }
}
