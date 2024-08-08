// ignore_for_file: avoid_print

// TODO: Use a logger instead of print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart' as coverage;
import 'package:path_provider/path_provider.dart';
import 'package:patrol/src/coverage/coverage_options.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'server_uri_processor.dart';

/// A singleton class responsible for collecting and managing code coverage data.
class CoverageCollector {

  /// Returns the singleton instance of [CoverageCollector].
  factory CoverageCollector() => _instance;
  CoverageCollector._internal();
  static final CoverageCollector _instance = CoverageCollector._internal();

  late final CoverageOptions _options;

  VmService? _service;
  Set<String>? _libraryNames;

  bool _isInitialized = false;
  bool _isRunning = false;
  final _completer = Completer<void>();

  String? _currentObservatoryUrlWs;
  String? _currentObservatoryUrlHttp;

  late ServerUriProcessor _serverUriProcessor;

  /// Initializes the CoverageCollector with required dependencies.
  Future<void> initialize({CoverageOptions? options}) async {
    if (_isInitialized) {
      return;
    }
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
    }
  }

  /// Handles the server URI when it becomes available.
  void _handleServerUri(Uri serverUri) {
    _currentObservatoryUrlHttp = serverUri.toString();
    _currentObservatoryUrlWs = _convertToWebSocketUrl(_currentObservatoryUrlHttp!);
    _connectToVmService();
  }

  Future<void> _writeCoverageDataToJsonFile(String coverageJsonData) async {
    try {
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/sdcard/Download');
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      final file = File('${downloadsDir!.path}/coverage_${DateTime.now().millisecondsSinceEpoch}.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(coverageJsonData, flush: true);

      print('Wrote coverage data to ${file.path}');
    } catch (err) {
      print('Error writing coverage data: $err');
    }
  }

  /// Collects coverage data for a specific isolate.
  Future<void> collectCoverage(String isolateId) async {
    final libraryNamesList = _libraryNames?.toList();
    if (libraryNamesList == null || libraryNamesList.isEmpty) {
      return;
    }
    print('Collecting coverage data for libraries: $libraryNamesList');
    final data = await _collectCoverageData(libraryNamesList);
    await _writeCoverageDataToJsonFile(jsonEncode(data));
  }

  Future<void> _connectToVmService() async {
    final wsUrl = _convertToWebSocketUrl(_currentObservatoryUrlWs!);

    try {
      _service = await vmServiceConnectUri(wsUrl);
    } catch (e) {
      _isRunning = false;
      _completer.complete();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _collectCoverageData(List<String> libraryNamesList) async {
    return coverage.collect(
      Uri.parse(_currentObservatoryUrlHttp!),
      true,
      false,
      false,
      libraryNamesList.toSet(),
      branchCoverage: _options.branchCoverage,
      functionCoverage: _options.functionCoverage,
      timeout: _options.timeout,
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
