import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class WSClient {
  final String uri;
  final String token;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Function(String)? onMessage;
  Function(String)? onStatus;

  bool get isConnected => _channel != null;

  WSClient({required this.uri, required this.token});

  Future<void> connect() async {
    _setStatus('Opening WebSocket...');
    _channel = IOWebSocketChannel.connect(Uri.parse(uri));
    _sub = _channel!.stream.listen((event) {
      if (onMessage != null) onMessage!(event);
    }, onDone: () {
      _setStatus('Disconnected');
    }, onError: (e) {
      _setStatus('WS error: \$e');
    });
    _setStatus('Connected');
  }

  void send(String message) {
    if (_channel != null) {
      _channel!.sink.add(message);
    }
  }

  void _setStatus(String s) {
    if (onStatus != null) onStatus!(s);
  }

  void dispose() {
    _sub?.cancel();
    _channel?.sink.close();
  }
}