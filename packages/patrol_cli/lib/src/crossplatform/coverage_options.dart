class CoverageOptions {
  const CoverageOptions({
    this.coverage = false,
    this.host = '127.0.0.1',
    this.port = 8181,
    this.out = 'coverage/lcov.info',
    this.connectTimeout = 10,
    this.scopeOutput = const [],
    this.waitPaused = false,
    this.resumeIsolates = true,
    this.includeDart = false,
    this.functionCoverage = true,
    this.branchCoverage = false,
  });

  final bool coverage;
  final String host;
  final int port;
  final String out;
  final int connectTimeout;
  final List<String> scopeOutput;
  final bool waitPaused;
  final bool resumeIsolates;
  final bool includeDart;
  final bool functionCoverage;
  final bool branchCoverage;
}
