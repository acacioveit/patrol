import 'dart:async';
import 'dart:io' show Process;
import 'dart:io' as io;
import 'dart:convert' show utf8;


import 'package:adb/adb.dart';
import 'package:dispose_scope/dispose_scope.dart';
import 'package:file/file.dart';
import 'package:patrol_cli/src/base/exceptions.dart';
import 'package:patrol_cli/src/base/logger.dart';
import 'package:patrol_cli/src/base/process.dart';
import 'package:patrol_cli/src/crossplatform/app_options.dart';
import 'package:patrol_cli/src/devices.dart';
import 'package:platform/platform.dart';
import 'package:process/process.dart';

import 'test_monitor.dart';

/// Provides functionality to build, install, run, and uninstall Android apps.
///
/// This class must be stateless.
class AndroidTestBackend {
  AndroidTestBackend({
    required Adb adb,
    required ProcessManager processManager,
    required Platform platform,
    required FileSystem fs,
    required DisposeScope parentDisposeScope,
    required Logger logger,
  })  : _adb = adb,
        _processManager = processManager,
        _fs = fs,
        _platform = platform,
        _disposeScope = DisposeScope(),
        _logger = logger {
    _disposeScope.disposedBy(parentDisposeScope);
  }

  final Adb _adb;
  final ProcessManager _processManager;
  final Platform _platform;
  final FileSystem _fs;
  final DisposeScope _disposeScope;
  final Logger _logger;

  TestMonitor? _testMonitor;
  final Completer<void> _testMonitorCompleter = Completer<void>();

  Future<void> build(AndroidAppOptions options) async {
    await _disposeScope.run((scope) async {
      final subject = options.description;
      final task = _logger.task('Building $subject');

      Process process;
      int exitCode;

      // :app:assembleDebug

      process = await _processManager.start(
        options.toGradleAssembleInvocation(isWindows: _platform.isWindows),
        runInShell: true,
        workingDirectory: _fs.currentDirectory.childDirectory('android').path,
      )
        ..disposedBy(scope);
      
      process.listenStdOut((l) => _logger.detail('\t: $l')).disposedBy(scope);
      process.listenStdErr((l) => _logger.err('\t$l')).disposedBy(scope);
      exitCode = await process.exitCode;
      if (exitCode == exitCodeInterrupted) {
        const cause = 'Gradle build interrupted';
        task.fail('Failed to build $subject ($cause)');
        throw Exception(cause);
      } else if (exitCode != 0) {
        final cause = 'Gradle build failed with code $exitCode';
        task.fail('Failed to build $subject ($cause)');
        throw Exception(cause);
      }

      // :app:assembleDebugAndroidTest

      process = await _processManager.start(
        options.toGradleAssembleTestInvocation(isWindows: _platform.isWindows),
        runInShell: true,
        workingDirectory: _fs.currentDirectory.childDirectory('android').path,
      )
        ..disposedBy(scope);
      process.listenStdOut((l) => _logger.detail('\t: $l')).disposedBy(scope);
      process.listenStdErr((l) => _logger.err('\t$l')).disposedBy(scope);
      exitCode = await process.exitCode;
      if (exitCode == 0) {
        task.complete('Completed building $subject');
      } else if (exitCode == exitCodeInterrupted) {
        const cause = 'Gradle build interrupted';
        task.fail('Failed to build $subject ($cause)');
        throw Exception(cause);
      } else {
        final cause = 'Gradle build failed with code $exitCode';
        task.fail('Failed to build $subject ($cause)');
        throw Exception(cause);
      }
    });
  }

  /// Executes the tests of the given [options] on the given [device].
  ///
  /// [build] must be called before this method.
  ///
  /// If [interruptible] is true, then no exception is thrown on SIGINT. This is
  /// used for Hot Restart.
Future<void> execute(
  AndroidAppOptions options,
  Device device, {
  bool interruptible = false,
}) async {
  Uri? observatoryUri;
  final logFile = io.File('/Users/jonathanferreira-mba/Documents/github-public/patrol/packages/patrol/example/adb_log.txt');

  if (!await logFile.parent.exists()) {
    await logFile.parent.create(recursive: true);
  }

  final logSink = logFile.openWrite();

  // Limpar o cache do adb logcat
  await _clearLogcatCache(device);

  final coverageCompleter = Completer<void>();
  final logcatProcess = await _startLogcat(logSink, device, coverageCompleter);

  await _disposeScope.run((scope) async {
    final subject = '${options.description} on ${device.description}';
    final task = _logger.task('Executing tests of $subject');

    final process = await _processManager.start(
      options.toGradleConnectedTestInvocation(isWindows: _platform.isWindows),
      runInShell: true,
      environment: {'ANDROID_SERIAL': device.id},
      workingDirectory: _fs.currentDirectory.childDirectory('android').path,
    )
      ..disposedBy(scope);

    process.listenStdOut((l) {
      _logger.detail('\t: $l');
    }).disposedBy(scope);

    process.listenStdErr((l) {
      const prefix = 'There were failing tests. ';
      if (l.contains(prefix)) {
        final msg = l.substring(prefix.length + 2);
        _logger.err('\t$msg');
      } else {
        _logger.detail('\t$l');
      }
    }).disposedBy(scope);

    final exitCode = await process.exitCode;
    if (exitCode == 0) {
      task.complete('Completed executing $subject');
    } else if (exitCode != 0 && interruptible) {
      task.complete('App shut down on request');
    } else if (exitCode == exitCodeInterrupted) {
      const cause = 'Gradle test execution interrupted';
      task.fail('Failed to execute tests of $subject ($cause)');
      throw Exception(cause);
    } else {
      final cause = 'Gradle test execution failed with code $exitCode';
      task.fail('Failed to execute tests of $subject ($cause)');
      throw Exception(cause);
    }

    await logSink.close();
    logcatProcess?.kill();

    await _testMonitor!.stop();

    if (!_testMonitorCompleter.isCompleted) {
      await _testMonitorCompleter.future;
    }

  });
}

Future<void> uninstall(String appId, Device device) async {
  _logger.detail('Uninstalling $appId from ${device.name}');
  await _adb.uninstall(appId, device: device.id);
  _logger.detail('Uninstalling $appId.test from ${device.name}');
  await _adb.uninstall('$appId.test', device: device.id);
}

Future<Process?> _startLogcat(IOSink logSink, Device device, Completer<void> coverageCompleter) async {
  try {
    final logcatProcess = await Process.start(
      'adb',
      ['-s', device.id, 'logcat'],
    );

    logcatProcess.stdout.transform(utf8.decoder).listen((data) {
      logSink.writeln(data);
      _checkForObservatoryUri(data, device, coverageCompleter);
    });

    logcatProcess.stderr.transform(utf8.decoder).listen((data) {
      logSink.writeln(data);
      _checkForObservatoryUri(data, device, coverageCompleter);
    });

    return logcatProcess;
  } catch (e) {
    _logger.err('Failed to start logcat process: $e');
    return null;
  }
}

Future<void> _clearLogcatCache(Device device) async {
  try {
    final clearLogcatProcess = await Process.run(
      'adb',
      ['-s', device.id, 'logcat', '-c'],
    );
    if (clearLogcatProcess.exitCode != 0) {
      _logger.err('Failed to clear logcat cache: ${clearLogcatProcess.stderr}');
    }
  } catch (e) {
    _logger.err('Error clearing logcat cache: $e');
  }
}

  Future<void> _checkForObservatoryUri(String data, Device device,  Completer<void> coverageCompleter) async {
    final match = RegExp(r'The Dart VM service is listening on (http://[^\s]+)').firstMatch(data);
    if (match != null) {
      final observatoryUri = match.group(1);
      _logger.info('Observatory URI found: $observatoryUri');

      if (observatoryUri != null) {
        // Inicie o TestMonitor
        await _portForwarding(Uri.parse(observatoryUri), device);
        _testMonitor = TestMonitor(observatoryUri);
        await _testMonitor!.start().then((_) {
          _testMonitorCompleter.complete();
        }).catchError((error) {
          _logger.err('Error in TestMonitor: $error');
          // _testMonitorCompleter.completeError(error as );
        });

        // Colete a cobertura
        await _collectCoverage(Uri.parse(observatoryUri), coverageCompleter);
      }
    }
  }

  Future<void> _collectCoverage(Uri observatoryUri, Completer<void> coverageCompleter) async {
    final coverageDir = io.Directory('coverage');
    if (!await coverageDir.exists()) {
      await coverageDir.create(recursive: true);
    }
    try {
      final process = await Process.run(
        'dart',
        [
          'pub',
          'global',
          'run',
          'coverage:collect_coverage',
          '--uri=$observatoryUri',
          '-o',
          'coverage/coverage.json',
          '--resume-isolates',
        ],
      );

      if (process.exitCode != 0) {
        _logger.err('Failed to collect coverage: ${process.stderr}');
      } else {
        _logger.info('Coverage collected successfully.');
      }
      } catch (e) {
      _logger.err('Error during coverage collection: $e');
      }
  }

  Future<void> _portForwarding(Uri observatoryUri, Device device) async {
      final processAdbForward = await Process.run(
        'adb',
        ['-s', device.id ,'forward', '--remove-all'],
      );

      if (processAdbForward.exitCode != 0) {
        _logger.err('Failed to remove all adb forwards: ${processAdbForward.stderr}');
      }
      
      final port = observatoryUri.port;

      final processAdbForwardPort = await Process.run(
        'adb',
        ['-s', device.id, 'forward', 'tcp:$port', 'tcp:$port'],
      );

      if (processAdbForwardPort.exitCode != 0) {
        _logger.err('Failed to forward port $port: ${processAdbForwardPort.stderr}');
      }
  }
}
