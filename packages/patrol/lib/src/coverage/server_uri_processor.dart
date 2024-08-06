import 'dart:async';
import 'dart:developer' as developer;

/// A class that processes the server URI by periodically checking for it.
class ServerUriProcessor {
  /// Creates an instance of [ServerUriProcessor] with a callback function to handle the server URI.
  ServerUriProcessor(this.onServerUri);

  /// A callback function that handles the server URI when it's found.
  final void Function(Uri) onServerUri;

  Timer? _checkTimer;

  /// Starts the server URI processing by initiating periodic checks.
  Future<void> start() async {
    _startListening();
  }

  /// Stops the server URI processing by cancelling the periodic checks.
  Future<void> stop() async {
    _checkTimer?.cancel();
  }

  void _startListening() {
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
      developer.log('Error checking for server URI: $e');
    }
  }
}
