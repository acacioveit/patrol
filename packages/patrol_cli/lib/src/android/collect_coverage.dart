import 'dart:async';
import 'dart:io';

import 'package:coverage/coverage.dart' as coverage;
import 'package:path/path.dart' as path;
import 'package:patrol_cli/src/base/logger.dart';
import 'package:patrol_cli/src/crossplatform/coverage_options.dart';
import 'package:process/process.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

class CoverageCollector { 
  factory CoverageCollector() => _instance;
  // Factory constructor to get the singleton instance
  CoverageCollector._internal();
  static final CoverageCollector _instance = CoverageCollector._internal();

  VmService? _service;
  final String _coverageDir = 'coverage';
  final String _mergedLcovFile = 'coverage/lcov.info';
  final String _tempDir = 'coverage/temp';
  late final ProcessManager _processManager;
  bool _isRunning = false;
  final _completer = Completer<void>();
  String? _currentObservatoryUrlWs;
  String? _currentObservatoryUrlHttp;
  bool _isInitialized = false;
  late final CoverageOptions _options;
  late final Logger _logger;

  Map<String, coverage.HitMap>? _globalHitmap;
  Set<String>? libraryNames;
  coverage.Resolver? resolver;

  Future<void> initialize({
    required Logger logger,
    required ProcessManager processManager,
    CoverageOptions? options,
  }) async {
    if (_isInitialized) {
      return;
    }
    _logger = logger;
    _processManager = processManager;
    _options = options ?? const CoverageOptions();
    _isInitialized = true;
    libraryNames = await _options.getCoveragePackages();
  }

  static Future<coverage.Resolver> getResolver(String? packagesPath) async {
    try {
      return await coverage.Resolver.create(packagesPath: packagesPath);
    } on FileSystemException {
      return coverage.Resolver.create();
    }
  }

  Future<void> start(String currentObservatoryUrlHttp) async {
    if (!_isInitialized) {
      throw StateError('CoverageCollector not initialized. Call initialize() first.');
    }

    _currentObservatoryUrlHttp = currentObservatoryUrlHttp;
    _currentObservatoryUrlWs =
        _convertToWebSocketUrl(currentObservatoryUrlHttp);

    await _connectToVmService();
    _isRunning = true;

    _service?.onIsolateEvent.listen(_handleIsolateEvent);
    _service?.onDebugEvent.listen(_handleDebugEvent);

    await _service?.streamListen(EventStreams.kDebug);
    await _service?.streamListen(EventStreams.kIsolate);

    _logger.info('Listening for events...');

    final vm = await _service?.getVM();
    for (final isolateRef in vm?.isolates ?? []) {
      isolateRef as IsolateRef;
      await _setTestBreakpoints(isolateRef.id!);
    }

    await _completer.future;
  }

  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }
    _isRunning = false;
    await _service?.dispose();
    _completer.complete();
    final success = await collectCoverageData(_mergedLcovFile, mergeCoverageData: false);

    if (success) {
      _logger.info('Coverage data written to $_mergedLcovFile');
    } else {
      _logger.err('Failed to write coverage data to $_mergedLcovFile');
    }
  }

  Future<void> _connectToVmService() async {
    final wsUrl = _convertToWebSocketUrl(_currentObservatoryUrlWs!);
    _logger.info('Connecting to $wsUrl');

    try {
      _service = await vmServiceConnectUri(wsUrl);
      _logger.info('Connected to VM service');
    } catch (e) {
      _logger.err('Failed to connect to VM service: $e');
      _isRunning = false;
      _completer.complete();
      rethrow;
    }
  }

  Future<void> _handleIsolateEvent(Event event) async {
    if (!_isRunning) {
      return;
    }

    if (event.kind == EventKind.kIsolateRunnable) {
      _logger.info('New isolate detected. Setting breakpoints...');
      await _setTestBreakpoints(event.isolate!.id!);
    }
  }

  void _handleDebugEvent(Event event) {
    if (!_isRunning) {
      return;
    }

    if (event.kind == EventKind.kPauseBreakpoint) {
      _handleBreakpoint(event);
    }
  }

  Future<void> _setTestBreakpoints(String isolateId) async {
    if (_service == null) {
      _logger.warn('VM service is not available. Cannot set breakpoints.');
      return;
    }

    try {
      final scripts = await _service!.getScripts(isolateId);

      for (final scriptRef in scripts.scripts!) {
        if (scriptRef.uri!.contains('integration_test/') &&
            scriptRef.uri!.endsWith('_test.dart')) {
          _logger.info('Setting breakpoints in ${scriptRef.uri}');

          Script? script;
          try {
            script =
                await _service!.getObject(isolateId, scriptRef.id!) as Script?;
          } catch (e) {
            _logger.warn('Failed to get script object: $e');
            continue;
          }

          if (script == null) {
            _logger.warn('Script object is null for ${scriptRef.uri}');
            continue;
          }

          final lines = script.source!.split('\n');

          for (var i = 0; i < lines.length; i++) {
            if (lines[i].trim().startsWith('test(') ||
                lines[i].trim().startsWith('testWidgets(') ||
                lines[i].trim().startsWith('patrol(')) {
              final endLine = _findTestFunctionEnd(lines, i);
              _logger.info(
                  'Found test starting at line ${i + 1} and ending at line ${endLine + 1}');
              if (endLine != -1) {
                try {
                  final bp = await _service!.addBreakpointWithScriptUri(
                    isolateId,
                    scriptRef.uri!,
                    endLine,
                  );
                  _logger.info(
                      'Breakpoint added: ${bp.id} at line $endLine (end of test)');
                } catch (e) {
                  _logger.warn('Error adding breakpoint: $e');
                }
              } else {
                _logger.warn(
                    'Could not find end of test starting at line ${i + 1}');
              }
            }
          }
        }
      }
    } catch (e) {
      _logger.warn('Error setting breakpoints: $e');
    }
  }

  int _findTestFunctionEnd(List<String> lines, int startLine) {
    var bracketCount = 0;
    var foundOpeningBracket = false;
    for (var i = startLine; i < lines.length; i++) {
      if (!foundOpeningBracket && lines[i].contains('{')) {
        foundOpeningBracket = true;
      }
      if (foundOpeningBracket) {
        bracketCount += '{'.allMatches(lines[i]).length;
        bracketCount -= '}'.allMatches(lines[i]).length;
        if (bracketCount == 0) {
          return i; // Return the line with the closing bracket
        }
      }
    }
    return -1; // End not found
  }

  Future<void> _handleBreakpoint(Event event) async {
    if (!_isRunning || _service == null) {
      _logger
          .warn('TestMonitor is not running or VM service is not available.');
      return;
    }

    if (event.isolate?.id == null) {
      _logger.warn('Warning: Isolate ID is null');
      return;
    }
    final isolateId = event.isolate!.id!;

    _logger.info('Breakpoint hit in isolate: $isolateId');

    final breakpointId = event.breakpoint?.id ?? 'Unknown';
    _logger.info('Breakpoint ID: $breakpointId');

    try {
      if (event.topFrame?.location?.script == null) {
        _logger.warn('Warning: Script information is not available');
      } else {
        final scriptRef = event.topFrame!.location!.script!;
        final script =
            await _service!.getObject(isolateId, scriptRef.id!) as Script?;

        if (script != null) {
          final lineNumber = event.topFrame?.location?.line ?? 'Unknown';
          _logger.info('Paused at ${script.uri}:$lineNumber (end of test)');
        } else {
          _logger.warn('Warning: Unable to retrieve script information');
        }
      }

      _logger.info('Collecting coverage...');
      await collectCoverage(isolateId);
    } catch (e) {
      _logger.err('Error handling breakpoint: $e');
    }
  }

  Future<void> collectCoverage(String isolateId) async {
    _logger.info('Collecting coverage data from $_currentObservatoryUrlHttp...');
    final libraryNamesList = libraryNames?.toList();
    if (libraryNamesList == null) {
      _logger.err('No library names found. Coverage collection aborted.');
      return;
    }

    _logger
      ..detail('Library names: ${libraryNamesList.join(',')}')
      ..detail('branchCoverage: ${_options.branchCoverage}')
      ..detail('functionCoverage: ${_options.functionCoverage}');

    final data = await collect(
      Uri.parse(_currentObservatoryUrlHttp!),
      libraryNames,
      branchCoverage: _options.branchCoverage,
      functionCoverage: _options.functionCoverage,
    );

    _logger.info('Collected coverage data; merging...');
  
    _addHitmap(await coverage.HitMap.parseJson(
        data['coverage'] as List<Map<String, dynamic>>,
        packagePath: Directory.current.path,
        checkIgnoredLines: true,
      ),
    );
  
    _logger.info('Done merging coverage data into global coverage map.');
  }

  void _addHitmap(Map<String, coverage.HitMap> hitmap) {
    if (_globalHitmap == null) {
    _globalHitmap = hitmap;
    } else {
    _globalHitmap!.merge(hitmap);
    }
  }

  Future<String?> finalizeCoverage({
    String Function(Map<String, coverage.HitMap> hitmap)? formatter,
    coverage.Resolver? resolver,
    Directory? coverageDirectory,
    }) async {
    if (_globalHitmap == null) {
      return null;
    }
    if (formatter == null) {
    final usedResolver = resolver ?? this.resolver ?? await getResolver('.dart_tool/package_config.json');
    final packagePath = Directory.current.path;
    final libraryPaths = libraryNames
      ?.map((e) => usedResolver.resolve('package:$e'))
      .whereType<String>()
      .toList();

    final reportOn = coverageDirectory == null
      ? libraryPaths
      : <String>[coverageDirectory.path];

    _logger.detail("Coverage report on: ${reportOn!.join(', ')}");
    _logger.detail("Coverage package path: $packagePath");
    _logger.detail("Coverage resolver: $usedResolver");

    formatter = (hitmap) => hitmap
      .formatLcov(usedResolver, reportOn: reportOn, basePath: packagePath);
    }

    final result = formatter(_globalHitmap!);
    _globalHitmap = null;
    return result;
  }

Future<bool> collectCoverageData(String? coveragePath, {bool mergeCoverageData = false, Directory? coverageDirectory}) async {
    final coverageData = await finalizeCoverage(
      coverageDirectory: coverageDirectory,
    );
    _logger.info('Coverage information collection complete');
    if (coverageData == null) {
      return false;
    }

    final coverageFile = File(coveragePath!)
      ..createSync(recursive: true)
      ..writeAsStringSync(coverageData, flush: true);
    _logger.info('Wrote coverage data to $coveragePath (size=${coverageData.length})');

    const baseCoverageData = 'coverage/lcov.base.info';
    if (mergeCoverageData) {
      if (!File(baseCoverageData).existsSync()) {
        _logger.err('Missing "$baseCoverageData". Unable to merge coverage data.');
        return false;
      }

      final lcovResult = await _processManager.run(['which', 'lcov']);
      if (lcovResult.exitCode != 0) {
        var installMessage = 'Please install lcov.';
        if (Platform.isLinux) {
          installMessage = 'Consider running "sudo apt-get install lcov".';
        } else if (Platform.isMacOS) {
          installMessage = 'Consider running "brew install lcov".';
        }
        _logger.err('Missing "lcov" tool. Unable to merge coverage data.\n$installMessage');
        return false;
      }

      final tempDir = Directory.systemTemp.createTempSync('patrol_coverage.');
      try {
        final sourceFile = coverageFile.copySync(path.join(tempDir.path, 'lcov.source.info'));
        final result = await _processManager.run(<String>[
          'lcov',
          '--add-tracefile', baseCoverageData,
          '--add-tracefile', sourceFile.path,
          '--output-file', coverageFile.path,
        ]);
        if (result.exitCode != 0) {
          return false;
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    }
    return true;
  }

  Future<Map<String, dynamic>> collect(Uri serviceUri, Set<String>? libraryNames, {
    bool waitPaused = false,
    bool resume = true,
    String? debugName,
    bool forceSequential = false,
    bool branchCoverage = false,
    bool functionCoverage = false,
    }) {
    return coverage.collect(
      serviceUri, resume, waitPaused, false, libraryNames,
      branchCoverage: branchCoverage,
      functionCoverage: functionCoverage,
      timeout: const Duration(minutes: 5),
    );
  }

  String _convertToWebSocketUrl(String observatoryUri) {
    var observatoryUriWs = observatoryUri.replaceFirst('http://', 'ws://');
    if (!observatoryUriWs.endsWith('/ws')) {
      observatoryUriWs += 'ws';
    }
    return observatoryUriWs;
  }
}
