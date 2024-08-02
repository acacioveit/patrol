import 'dart:async';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'dart:developer' as developer;
import 'dart:io';

class ServerUriProcessor {
  ServerUriProcessor(this.onServerUri);
  final void Function(Uri) onServerUri;
  final Logger _logger = Logger('ServerUriProcessor');
  Timer? _checkTimer;

  Future<void> start() async {
    _startListening();
  }

  Future<void> stop() async {
    _checkTimer?.cancel();
  }

  void _startListening() {
    _checkTimer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      _checkForServerUri();
    });
  }

  Future<void> _checkForServerUri() async {
    try {
      final info = await developer.Service.getInfo();
      if (info.serverUri != null) {
        onServerUri(info.serverUri!);
        await stop();
      }
    } catch (e) {
      _logger.warning('Error getting serverUri: $e');
    }
  }
}
