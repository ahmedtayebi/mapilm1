import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum WsConnectionState { disconnected, connecting, connected, reconnecting }

final wsClientProvider = Provider<WebSocketClient>((ref) => WebSocketClient());

class WebSocketClient {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  String? _conversationId;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _pingInterval = Duration(seconds: 25);

  final _stateController =
      StreamController<WsConnectionState>.broadcast();

  Stream<WsConnectionState> get connectionState => _stateController.stream;
  Stream<Map<String, dynamic>> get messages =>
      _messageController?.stream ?? const Stream.empty();

  Future<void> connect(String conversationId) async {
    _conversationId = conversationId;
    _messageController = StreamController<Map<String, dynamic>>.broadcast();
    await _connect();
  }

  Future<void> _connect() async {
    _stateController.add(WsConnectionState.connecting);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final baseUrl = dotenv.env['WS_URL'] ?? '';
      final uri = Uri.parse(
        '$baseUrl/chat/$_conversationId/?token=$token',
      );

      _channel = WebSocketChannel.connect(uri);
      _stateController.add(WsConnectionState.connected);
      _reconnectAttempts = 0;
      _startPing();

      _channel!.stream.listen(
        (data) {
          final decoded = jsonDecode(data as String) as Map<String, dynamic>;
          _messageController?.add(decoded);
        },
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: false,
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void send(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void sendMessage({
    required String content,
    required String type,
    String? replyToId,
    String? mediaUrl,
  }) {
    send({
      'type': 'chat_message',
      'content': content,
      'message_type': type,
      if (replyToId != null) 'reply_to': replyToId,
      if (mediaUrl != null) 'media_url': mediaUrl,
    });
  }

  void sendTyping(bool isTyping) {
    send({'type': isTyping ? 'typing_start' : 'typing_stop'});
  }

  void markRead(String messageId) {
    send({'type': 'mark_read', 'message_id': messageId});
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      send({'type': 'ping'});
    });
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    _stateController.add(WsConnectionState.disconnected);
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _stateController.add(WsConnectionState.reconnecting);
      final delay = Duration(
        seconds: (2 * (_reconnectAttempts + 1)).clamp(2, 30),
      );
      _reconnectTimer = Timer(delay, () {
        _reconnectAttempts++;
        _connect();
      });
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    await _channel?.sink.close();
    await _messageController?.close();
    _channel = null;
    _messageController = null;
    _stateController.add(WsConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }
}
