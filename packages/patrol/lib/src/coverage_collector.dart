import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart' as coverage;
import 'package:path_provider/path_provider.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import './native/server_uri_processor.dart';
import 'coverage_options.dart';
import 'logger.dart';

/// A singleton class responsible for collecting and managing code coverage data.
class CoverageCollector {
  factory CoverageCollector() => _instance;
  CoverageCollector._internal();
  static final CoverageCollector _instance = CoverageCollector._internal();

  late final Logger _logger;
  late final CoverageOptions _options;

  VmService? _service;
  Map<String, coverage.HitMap>? _globalHitmap;
  Set<String>? _libraryNames;
  coverage.Resolver? _resolver;

  bool _isInitialized = false;
  bool _isRunning = false;
  final _completer = Completer<void>();

  String? _currentObservatoryUrlWs;
  String? _currentObservatoryUrlHttp;

  // Add ServerUriProcessor
  late ServerUriProcessor _serverUriProcessor;

 /// Initializes the CoverageCollector with required dependencies.
  Future<void> initialize({
    required Logger logger,
    CoverageOptions? options,
  }) async {
    if (_isInitialized) {
      return;
    }

    _logger = logger;
    _options = options ?? const CoverageOptions();
    _isInitialized = true;
    _libraryNames = await _options.getCoveragePackages();

    // Initialize ServerUriProcessor
    _serverUriProcessor = ServerUriProcessor(_handleServerUri);
  }

  /// Starts the coverage collection process in the background.
  Future<void> startInBackground() async {
    _ensureInitialized();
    _isRunning = true;

    unawaited(_serverUriProcessor.start());

    unawaited(_runCoverageCollection());
  }

   /// Stops the coverage collection process and writes the collected data.
  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    _isRunning = false;
    await _serverUriProcessor.stop();
    await _service?.dispose();
    _completer.complete();
  }

    /// Collects coverage data for a completed test.
  Future<void> handleTestCompletion(String testName) async {
    if (!_isRunning || _service == null) {
      print('Not running or service is null');
      return;
    }

    final vm = await _service!.getVM();
    final isolateId = vm.isolates!.first.id!;
    print('Isolate ID: $isolateId');
    print('Starting Collect coverage for test: $testName');
    await collectCoverage(isolateId);
    await stop();
    print('Collecting coverage for test: $testName');
  }



  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('CoverageCollector is not initialized');
    }
  }

  Future<void> _runCoverageCollection() async {
    try {
      await _completer.future;
    } catch (e) {
      print('Error running coverage collection: $e');
    } finally {
      // await stop();
    }
  }

  /// Handles the server URI when it becomes available
  void _handleServerUri(Uri serverUri) {
    _currentObservatoryUrlHttp = serverUri.toString();
    _currentObservatoryUrlWs = _convertToWebSocketUrl(_currentObservatoryUrlHttp!);
    _connectToVmService();
  }

  Future<void> _writeCoverageDataToFile(String coverageData) async {
    try {
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      print("coverageData: $coverageData");
      final file =  File('${downloadsDir.path}/lcov_${DateTime.now().millisecondsSinceEpoch}.info')
        ..createSync(recursive: true)
        ..writeAsStringSync(coverageData, flush: true);

      print('Wrote raw coverage data to ${file.path}');
    } catch (e) {
      print('Error writing coverage data: $e');
    }
  }

  Future<void> __writeCoverageDataToJsonFile(String coverageJsonData) async {
    try {
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/sdcard/Download');
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final file =  File('${downloadsDir.path}/coverage_${DateTime.now().millisecondsSinceEpoch}.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(coverageJsonData, flush: true);

      print('Wrote coverage data to ${file.path}');
    } catch (e) {
      print('Error writing coverage data: $e');
    }
  }

  /// Collects coverage data for a specific isolate.
  Future<void> collectCoverage(String isolateId) async {
    _logger.detail('Collecting coverage data from $_currentObservatoryUrlHttp...');

    final libraryNamesList = _libraryNames?.toList();
    print('Library names list: $libraryNamesList');
    if (libraryNamesList == null || libraryNamesList.isEmpty) {
      print('libraryNamesList is empty');
      return;
    }

    final data = await _collectCoverageData(libraryNamesList);
    print("Data: $data");
    await __writeCoverageDataToJsonFile(jsonEncode(data));
  }


  Future<void> _connectToVmService() async {
    final wsUrl = _convertToWebSocketUrl(_currentObservatoryUrlWs!);
    _logger.info('Connecting to $wsUrl');

    try {
      _service = await vmServiceConnectUri(wsUrl);
      _logger.info('Connected to VM service');
    } catch (e) {
      print('Error connecting to VM service: $e');
      _isRunning = false;
      _completer.complete();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _collectCoverageData(
      List<String> libraryNamesList,) async {

    print('Collecting coverage data for libraries: $libraryNamesList');
    print('Current observatory URL: $_currentObservatoryUrlHttp');
    return coverage.collect(
      Uri.parse(_currentObservatoryUrlHttp!),
      true,
      false,
      false,
      libraryNamesList.toSet(),
      branchCoverage: _options.branchCoverage,
      functionCoverage: _options.functionCoverage,
      timeout: const Duration(minutes: 5),
    );
  }

  Future<String?> finalizeCoverage({
    String Function(Map<String, coverage.HitMap> hitmap)? formatter,
    coverage.Resolver? resolver,
    Directory? coverageDirectory,
  }) async {
    if (_globalHitmap == null) {
      return null;
    }

    formatter ??= _createDefaultFormatter(
        await _getResolver(resolver), coverageDirectory,);

    print("globalHitmap: $_globalHitmap");

    final result = formatter(_globalHitmap!);
    _globalHitmap = null;
    return result;
  }

  String Function(Map<String, coverage.HitMap>) _createDefaultFormatter(
    coverage.Resolver resolver,
    Directory? coverageDirectory,
  ) {
    return (hitmap) {
      final packagePath = Directory.current.path;
      print("libraryNames: $_libraryNames");

      final libraryPaths = _libraryNames
          ?.map((e) => resolver.resolve('package:$e'))
          .whereType<String>()
          .toList();

      final reportOn = coverageDirectory == null
          ? libraryPaths
          : <String>[coverageDirectory.path];

      print("reportOn: $reportOn");
      print("packagePath: $packagePath");

      print("hitmap: $hitmap");

      return hitmap.formatLcov(resolver,
          reportOn: reportOn, basePath: packagePath,);
    };
  }

  Future<coverage.Resolver> _getResolver(
      coverage.Resolver? providedResolver,) async {
    if (providedResolver != null) {
      return providedResolver;
    }
    if (_resolver != null) {
      return _resolver!;
    }
    
    try {

      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/sdcard/Download');
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final file = File('${downloadsDir.path}/package_config.json');
      
      final packageConfigData = _options.coveragePackageConfig;
      print("packageConfigData: $packageConfigData");
      await file.writeAsString(packageConfigData!, flush: true);

      _resolver = await coverage.Resolver.create(
        packagesPath: file.path,);

      print("Wrote package_config.json to ${file.path}");
    } catch (e) {
      print('Error writing coverage data: $e');
    }
     

    return _resolver!;
  }

  Future<void> _mergeCoverageData(Map<String, dynamic> data) async {
    print('Collected coverage data; merging...');

    _addHitmap(
      await coverage.HitMap.parseJson(
        data['coverage'] as List<Map<String, dynamic>>,
        // packagesPath: '/storage/emulated/0/Download/package_config.json',
        checkIgnoredLines: true,
      ),
    );

    print('Done merging coverage data into global coverage map.');
  }

  void _addHitmap(Map<String, coverage.HitMap> hitmap) {
    if (_globalHitmap == null) {
      _globalHitmap = hitmap;
    } else {
      _globalHitmap!.merge(hitmap);
    }
  }

  String _convertToWebSocketUrl(String observatoryUri) {
    var observatoryUriWs = observatoryUri.replaceFirst('http://', 'ws://');
    if (!observatoryUriWs.endsWith('/ws')) {
      observatoryUriWs += 'ws';
    }
    return observatoryUriWs;
  }
}
