import '../constants.dart' as constants;

/// Class representing coverage options for generating coverage reports.
class CoverageOptions {
  /// Creates an instance of [CoverageOptions] with the given parameters.
  const CoverageOptions({
    this.coverage = true,
    this.timeout = const Duration(minutes: 1),
    this.functionCoverage = false,
    this.branchCoverage = false,
    this.coveragePackageConfig = '',
  });

  /// Whether to include coverage information.
  final bool coverage;

  /// Timeout duration for connecting, in seconds.
  final Duration timeout;

  /// Whether to include function coverage.
  final bool functionCoverage;

  /// Whether to include branch coverage.
  final bool branchCoverage;

  /// Path to the coverage package configuration file.
  final String? coveragePackageConfig;

  /// Returns the coverage packages to include in the coverage report.
  Future<Set<String>> getCoveragePackages() async {
    final packagesToInclude = constants.coveragePackageList.split(',');
    return packagesToInclude.toSet();
  }
}
