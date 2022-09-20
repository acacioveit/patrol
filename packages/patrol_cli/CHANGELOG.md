## 0.6.5

- Fix `--targets` argument to `patrol drive` (#330)

## 0.6.4

- Add the `targets` alias for `target` option for `patrol drive` (#314)
- Add the `devices` alias for `device` option for `patrol drive` (#314)
- Add the `dart-defines` alias for `dart-define` option for `patrol drive`
  (#314)
- Remove support for the `patrol.toml` config file (#313)

## 0.6.3

- Don't require `host` and `port` to be defined in `patrol.toml` or passed in as
  command-line arguments (#301)
- Print cleaner, more readable logs when native action fails (#295)

## 0.6.2

- Restart `flutter drive` on connection failure (#280)
- Rename `--devices` to `--device` to be more consistent (#280)
- Populate `homepage` field in `pubspec.yaml` (#254)

## 0.6.1

- Fix handling native permissions on older Android API levels (#260)

## 0.6.0+1

- Fix URL of artifact storage (#259)

## 0.6.0

- **Rename to patrol_cli** (#258)

## 0.5.3

- Add new `--wait` argument which accepts the number of seconds to wait after
  the test finishes (#251)
- Make `maestro drive` run all tests (#253)

## 0.5.2

- Migrate iOS AutomatorServer to a more stable HTTP server, which doesn't crash
  randomly (#220)
- Add new `packageName` and `bundleId` fields to `maestro.toml`
- Add new arguments to the tool: `--package-name` and `--bundle-id`

## 0.5.1

- Add support for handling native permission requests on Android (#232)
- Fix Android AutomatorServer suppressing all accessibility services (#235)

## 0.5.0

- Now `maestro_cli` will clean up after itself, either when it exits normally or
  is stopped by the user (#209):
  - port forwarding is automatically stopped
  - artifacts are automatically uninstalled
- `pod install` is automatically run when iOS artifacts are downloaded (macOS
  only) (#206)

## 0.4.4+3

- Fix not working on Windows because of `flutter` command not being found

## 0.4.4+2

- Fix problem with project not building because of a breaking change in
  `package:mason_logger` dependency

## 0.4.4+1

- Fix issue with CI

## 0.4.4

- Add support for physical iOS devices

## 0.4.3

- Fix bug with APKs failing to force install when certificates don't match, this
  time once and for all

## 0.4.2

- Fix bug with APKs failing to force install when certificates don't match

## 0.4.1

- Rename `MAESTRO_ARTIFACT_PATH` environment variable to `MAESTRO_CACHE`
- Add `maestro devices` command
- Some work made under the hood to enable support for iOS

## 0.4.0

- Support [maestro_test
  0.4.0](https://pub.dev/packages/maestro_test/changelog#040)

## 0.3.5

- Fix dependency resolution problem

## 0.3.4

- Improve output of `maestro drive`

## 0.3.3

- Fix a crash which occured when ADB daemon was not initialized

## 0.3.2

- Fix a crash which occured when ADB daemon was not initialized
- Make it possible to add `--dart-define`s in `maestro.toml`
- Fix templates generated by `maestro bootstrap`

## 0.3.1

- Automatically inform about new version when it is available
- Add `maestro update` command to easily update the package

## 0.3.0

- Add support for new features in [maestro_test
  0.3.0](https://pub.dev/packages/maestro_test/changelog#030)

## 0.2.0

- Add support for new features in [maestro_test
  0.2.0](https://pub.dev/packages/maestro_test/changelog#020)

## 0.1.5

- Allow for running on many devices simultaneously
- A usual portion of smaller improvements and bug fixes

## 0.1.4

- Be more noisy when an error occurs
- Change waiting timeout for native widgets from 10s to 2s

## 0.1.3

- Fix a bug which made `flavor` option required
- Add `--debug` flag to `maestro drive`, which allows to use default,
  non-versioned artifacts from `$MAESTRO_ARTIFACT_PATH`

## 0.1.2

- Fix typo in generated `integration_test/app_test.dart`
- Depend on [package:adb](https://pub.dev/packages/adb)

## 0.1.1

- Set minimum Dart version to 2.16.
- Fix links to `package:leancode_lint` in README

## 0.1.0

- Add `--template` option for `maestro bootstrap`
- Add `--flavor` options for `maestro drive`
- Rename `maestro config` to `maestro doctor`

## 0.0.9

- Add `--device` option for `maestro drive`, which allows you to specify the
  device to use. Devices can be obtained using `adb devices`

## 0.0.8

- Fix `maestro drive` on Windows crashing with ProcessException

## 0.0.7

- Fix a few bugs

## 0.0.6

- Fix `maestro bootstrap` on Windows crashing with ProcessException

## 0.0.5

- Make versions match AutomatorServer

## 0.0.4

- Nothing

## 0.0.3

- Add support for `maestro.toml` config file

## 0.0.2

- Split `maestro` and `maestro_cli` into separate packages
- Add basic, working command line interface with

## 0.0.1

- Initial version