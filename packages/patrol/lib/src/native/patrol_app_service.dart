// ignore_for_file: avoid_print

// TODO: Use a logger instead of print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:patrol/src/common.dart';
import 'package:patrol/src/coverage_options.dart';
import 'package:patrol/src/logger.dart';
import 'package:patrol/src/native/contracts/contracts.dart';
import 'package:patrol/src/native/contracts/patrol_app_service_server.dart';
import 'package:path_provider/path_provider.dart';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import '../coverage_collector.dart';
import '../constants.dart' as constans;

const _port = 8082;
const _idleTimeout = Duration(hours: 2);

int  _countTest = 0;

class _TestExecutionResult {
  const _TestExecutionResult({required this.passed, required this.details});

  final bool passed;
  final String? details;
}

/// Starts the gRPC server that runs the [PatrolAppService].
Future<void> runAppService(PatrolAppService service) async {
  print("RunAppService: $_countTest");
  print("coverage: ${constans.coverage}");
  print("functionCoverage: ${constans.functionCoverage}");
  print("coveragePackages: ${constans.coveragePackageList}");

  // convert to string from base64
  final packageConfig = utf8.decode(base64.decode(constans.packageConfig));
  final coverageOptions = CoverageOptions(
    coverage: constans.coverage,
    functionCoverage:  constans.functionCoverage,
    coveragePackageConfig: packageConfig,
  );

  await CoverageCollector().initialize(logger: Logger(), options: coverageOptions);
  await CoverageCollector().startInBackground();
  final pipeline = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler(service.handle);

  final server = await shelf_io.serve(
    pipeline,
    InternetAddress.anyIPv4,
    _port,
    poweredByHeader: null,
  );

  server.idleTimeout = _idleTimeout;

  final address = server.address;

  print(
    'PatrolAppService started, address: ${address.address}, host: ${address.host}, port: ${server.port}',
  );
}

/// Implements a stateful gRPC service for querying and executing Dart tests.
///
/// This is an internal class and you don't want to use it. It's public so that
/// the generated code can access it.
class PatrolAppService extends PatrolAppServiceServer {
  /// Creates a new [PatrolAppService].
  PatrolAppService({required this.topLevelDartTestGroup});

  /// The ambient test group that wraps all the other groups and tests in the
  /// bundled Dart test file.
  final DartGroupEntry topLevelDartTestGroup;

  /// A completer that completes with the name of the Dart test file that was
  /// requested to execute by the native side.
  final _testExecutionRequested = Completer<String>();

  /// A future that completes with the name of the Dart test file that was
  /// requested to execute by the native side.
  Future<String> get testExecutionRequested => _testExecutionRequested.future;

  final _testExecutionCompleted = Completer<_TestExecutionResult>();

  /// A future that completes when the Dart test file (whose execution was
  /// requested by the native side) completes.
  ///
  /// Returns true if the test passed, false otherwise.
  Future<_TestExecutionResult> get testExecutionCompleted {
    return _testExecutionCompleted.future;
  }

  /// Marks [dartFileName] as completed with the given [passed] status.
  ///
  /// If an exception was thrown during the test, [details] should contain the
  /// useful information.
  Future<void> markDartTestAsCompleted({
    required String dartFileName,
    required bool passed,
    required String? details,
  }) async {
    print('PatrolAppService.markDartTestAsCompleted(): $dartFileName');
    _countTest++;
    print("MarkDartTestAsCompleted: $_countTest");
    assert(
      _testExecutionRequested.isCompleted,
      'Tried to mark a test as completed, but no tests were requested to run',
    );

    final requestedDartTestName = await testExecutionRequested;
    assert(
      requestedDartTestName == dartFileName,
      'Tried to mark test $dartFileName as completed, but the test '
      'that was most recently requested to run was $requestedDartTestName',
    );

     await CoverageCollector().handleTestCompletion(dartFileName);

    _testExecutionCompleted.complete(
      _TestExecutionResult(passed: passed, details: details),
    );
  }

  /// Returns when the native side requests execution of a Dart test. If the
  /// native side requsted execution of [dartTest], returns true. Otherwise
  /// returns false.
  ///
  /// It's used inside of [patrolTest] to halt execution of test body until
  /// [runDartTest] is called.
  ///
  /// The native side requests execution by RPC-ing [runDartTest] and providing
  /// name of a Dart test that it wants to currently execute [dartTest].
  Future<bool> waitForExecutionRequest(String dartTest) async {
    print('PatrolAppService: registered "$dartTest"');

    final requestedDartTest = await testExecutionRequested;
    if (requestedDartTest != dartTest) {
      // If the requested Dart test is not the one we're waiting for now, it
      // means that dartTest was already executed. Return false so that callers
      // can skip the already executed test.

      print(
        'PatrolAppService: registered test "$dartTest" was not matched by requested test "$requestedDartTest"',
      );

      return false;
    }

    print('PatrolAppService: requested execution of test "$dartTest"');

    return true;
  }

  @override
  Future<ListDartTestsResponse> listDartTests() async {
    print('PatrolAppService.listDartTests() called');
    return ListDartTestsResponse(group: topLevelDartTestGroup);
  }

  @override
  Future<RunDartTestResponse> runDartTest(RunDartTestRequest request) async {
    assert(_testExecutionCompleted.isCompleted == false);
    // patrolTest() always calls this method.

    print('PatrolAppService.runDartTest(${request.name}) called');
    _testExecutionRequested.complete(request.name);

    final testExecutionResult = await testExecutionCompleted;
    return RunDartTestResponse(
      result: testExecutionResult.passed
          ? RunDartTestResponseResult.success
          : RunDartTestResponseResult.failure,
      details: testExecutionResult.details,
    );
  }
}
