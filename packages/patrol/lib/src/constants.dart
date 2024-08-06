import 'package:meta/meta.dart';

/// Whether Hot Restart is enabled.
@internal
const bool hotRestartEnabled = bool.fromEnvironment('PATROL_HOT_RESTART');
/// Whether coverage is enabled.
@internal
const bool coverage = bool.fromEnvironment('PATROL_COVERAGE');
/// Collect function coverage info
@internal
const bool functionCoverage = bool.fromEnvironment('PATROL_FUNCTION_COVERAGE');
/// A regular expression matching packages names to include in the coverage report.
@internal
const String coveragePackageList = String.fromEnvironment('PATROL_COVERAGE_PACKAGES');
/// The package config contents.
@internal
const String packageConfig = String.fromEnvironment('PATROL_PACKAGE_CONFIG');