import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:patrol_cli/src/base/logger.dart';
import 'package:patrol_cli/src/devices.dart';

/// Abstract class defining common behavior for log processors
abstract class BaseLogProcessor {
  BaseLogProcessor(this.device, this.logFilePath, this.onObservatoryUri, this._logger, );
  
  final Device device;
  final String logFilePath;
  final void Function(String) onObservatoryUri;
  final Logger _logger;

  StreamSubscription<dynamic>? _logSubscription;
  IOSink? _logSink;

  Future<void> start();
  Future<void> stop();

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

/// Unified log processor for both iOS and Android platforms
class LogProcessor extends BaseLogProcessor {
  LogProcessor(
      super.device, super.logFilePath, super.onObservatoryUri, super.logger,
    );

  @override
  Future<void> start() async {
    _logger.info('Starting log processor');
    
    if (device.targetPlatform == TargetPlatform.iOS) {
      await _startIOSLogStream();
    } else {
      await _clearLogcatCache();
      await _startLogcatStream();
    }
    
    _logger.info('log processor started');
  }

  @override
  Future<void> stop() async {
    await _logSubscription?.cancel();
    await _logSink?.close();
  }

  Future<void> _startIOSLogStream() async {
    final logFile = File(logFilePath);
    _logSink = logFile.openWrite(mode: FileMode.writeOnly);

    late Process logProcess;
    if (device.real) {
      logProcess = await Process.start('idevicesyslog', ['-u', device.id]);
    } else {
      logProcess = await Process.start('xcrun', ['simctl', 'spawn', device.id, 'log', 'stream', '--style', 'syslog']);
    }

    _logSubscription = logProcess.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_processLogLine);

    logProcess.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _logger.err('Log error: $line'));
  }

  Future<void> _clearLogcatCache() async {
    try {
      final result = await Process.run('adb', ['-s', device.id, 'logcat', '-c']);
      if (result.exitCode != 0) {
        _logger.err('Failed to clear logcat cache: ${result.stderr}');
      }
    } catch (err) {
      _logger.err('Error clearing logcat cache: $err');
    }
  }

  Future<void> _startLogcatStream() async {
    final logFile = File(logFilePath);
    _logSink = logFile.openWrite(mode: FileMode.writeOnly);

    final logcatProcess =
        await Process.start('adb', ['-s', device.id, 'logcat']);

    _logSubscription = logcatProcess.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_processLogLine);

    logcatProcess.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _logger.err('Logcat error: $line'));
  }
}
