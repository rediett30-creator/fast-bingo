import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';
import '../models/ws_message.dart';

/// Manages the WebSocket connection to the game server.
/// Provides a typed message stream and handles reconnection with
/// exponential backoff.
class WsService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<WsMessage>.broadcast();
  final _connectionStateController = StreamController<WsConnectionState>.broadcast();

  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  static const int _maxBackoffSeconds = 30;

  int? _currentGameId;
  String? _currentToken;
  bool _intentionalClose = false;

  /// Stream of parsed WebSocket messages.
  Stream<WsMessage> get messages => _messageController.stream;

  /// Stream of connection state changes (for showing reconnecting UI).
  Stream<WsConnectionState> get connectionState => _connectionStateController.stream;

  /// Connect to the game's WebSocket endpoint.
  void connect(int gameId, String token) {
    disconnect();
    _currentGameId = gameId;
    _currentToken = token;
    _intentionalClose = false;
    _reconnectAttempt = 0;
    _doConnect();
  }

  void _doConnect() {
    if (_currentGameId == null || _currentToken == null) return;

    _connectionStateController.add(WsConnectionState.connecting);

    final wsUrl = '${AppConfig.wsBaseUrl}/ws/games/$_currentGameId?token=$_currentToken';
    final uri = Uri.parse(wsUrl);

    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (data) {
        _reconnectAttempt = 0; // reset on successful message
        _connectionStateController.add(WsConnectionState.connected);
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          final message = WsMessage.fromJson(json);
          _messageController.add(message);
        } catch (e) {
          _messageController.add(ErrorMessage(detail: 'Failed to parse message: $e'));
        }
      },
      onError: (error) {
        _connectionStateController.add(WsConnectionState.disconnected);
        if (!_intentionalClose) {
          _scheduleReconnect();
        }
      },
      onDone: () {
        _connectionStateController.add(WsConnectionState.disconnected);
        if (!_intentionalClose) {
          _scheduleReconnect();
        }
      },
    );
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final backoff = min(pow(2, _reconnectAttempt).toInt(), _maxBackoffSeconds);
    _reconnectAttempt++;
    _connectionStateController.add(WsConnectionState.reconnecting);

    _reconnectTimer = Timer(Duration(seconds: backoff), () {
      _doConnect();
    });
  }

  /// Send a bingo claim for a specific card.
  void sendBingoClaim(int cardId) {
    _channel?.sink.add(jsonEncode({
      'type': 'bingo',
      'card_id': cardId,
    }));
  }

  /// Send start_game message (admin only).
  void sendStartGame(int countdownSeconds) {
    _channel?.sink.add(jsonEncode({
      'type': 'start_game',
      'countdown_seconds': countdownSeconds,
    }));
  }

  /// Cleanly close the connection (no auto-reconnect).
  void disconnect() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  /// Clean up all resources.
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionStateController.close();
  }
}

/// Connection state for UI feedback.
enum WsConnectionState {
  connecting,
  connected,
  disconnected,
  reconnecting,
}
