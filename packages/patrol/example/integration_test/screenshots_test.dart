@Tags(['android', 'ios'])

import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'common.dart';

Future<void> main() async {
  late String mapsId;
  if (Platform.isIOS) {
    mapsId = 'com.apple.Maps';
  } else if (Platform.isAndroid) {
    mapsId = 'com.google.android.apps.maps';
  }

  patrol('takes a few screenshots', ($) async {
    await $.host.takeScreenshot(name: '1_before_run');

    await $.pumpWidgetAndSettle(ExampleApp());

    expect($(#counterText).text, '0');

    await $(FloatingActionButton).tap();

    await $.native.pressHome();
    await $.host.takeScreenshot(name: '2_after_press_home_1');

    await $.native.openApp(appId: mapsId);
    await $.host.takeScreenshot(name: '3_after_open_app_1');

    await $.native.pressHome();
    await $.host.takeScreenshot(name: '4_after_press_home_2');

    await $.native.openApp();
    await $.host.takeScreenshot(name: '5_after_open_app_2');

    expect($(#counterText).text, '1');
  });
}