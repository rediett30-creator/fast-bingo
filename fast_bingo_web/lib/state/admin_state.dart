import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../models/ws_message.dart';
import '../services/api_service.dart';
import '../services/ws_service.dart';

class AdminState extends ChangeNotifier {
  final ApiService _apiService;
  final WsService _wsService;

  GameWithPattern? _currentGame;
  List<PatternModel> _patterns = [];

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Live monitor state
  GameStatus _status = GameStatus.pending;
  double? _countdownStartsAt;
  bool _isCountdownActive = false;
  final List<int> _calledNumbers = [];
  final Set<int> _calledNumbersSet = {};

  bool _isGameFinished = false;
  bool _isPoolExhausted = false;
  int? _winnerUserId;
  String? _winnerName;
  int? _winningCardId;
  List<int?>? _winningGrid;

  WsConnectionState _connectionState = WsConnectionState.disconnected;
  StreamSubscription<WsMessage>? _wsSubscription;
  StreamSubscription<WsConnectionState>? _connSubscription;

  AdminState({required ApiService apiService, required WsService wsService})
    : _apiService = apiService,
      _wsService = wsService;

  GameWithPattern? get currentGame => _currentGame;
  List<PatternModel> get patterns => _patterns;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  GameStatus get status => _status;
  double? get countdownStartsAt => _countdownStartsAt;
  bool get isCountdownActive => _isCountdownActive;
  List<int> get calledNumbers => List.unmodifiable(_calledNumbers);

  bool get isGameFinished => _isGameFinished;
  bool get isPoolExhausted => _isPoolExhausted;
  int? get winnerUserId => _winnerUserId;
  String? get winnerName => _winnerName;
  int? get winningCardId => _winningCardId;
  List<int?>? get winningGrid => _winningGrid;
  WsConnectionState get connectionState => _connectionState;

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadAdminData(String? token) async {
    _isLoading = true;
    _errorMessage = null;
    _resetMonitorState();
    notifyListeners();

    try {
      // 1. Fetch win patterns
      try {
        _patterns = await _apiService.getPatterns();
      } catch (e) {
        debugPrint('Error loading patterns: $e');
      }

      // 2. Fetch current game (null if 404)
      _currentGame = await _apiService.getCurrentGame();

      if (_currentGame != null) {
        _status = _currentGame!.status;
        if (token != null && token.isNotEmpty) {
          _connectWebSocket(_currentGame!.id, token);
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = _extractErrorMessage(e);
      notifyListeners();
    }
  }

  // ── Create Game ──────────────────────────────────────────────────────
  Future<bool> createGame({
    required int cardPrice,
    required int totalAward,
    required int patternId,
    required String? token,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.createGame(
        cardPrice: cardPrice,
        totalAward: totalAward,
        patternId: patternId,
      );

      // Refresh current game to get complete GameWithPattern structure
      _currentGame = await _apiService.getCurrentGame();
      if (_currentGame != null) {
        _status = _currentGame!.status;
        if (token != null && token.isNotEmpty) {
          _connectWebSocket(_currentGame!.id, token);
        }
      }

      _isSubmitting = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _isSubmitting = false;
      _errorMessage = _extractErrorMessage(e);

      // On 409 (a game already slipped in from elsewhere), refresh from server
      if (e.response?.statusCode == 409) {
        try {
          _currentGame = await _apiService.getCurrentGame();
          if (_currentGame != null) {
            _status = _currentGame!.status;
            if (token != null && token.isNotEmpty) {
              _connectWebSocket(_currentGame!.id, token);
            }
          }
        } catch (_) {}
      }

      notifyListeners();
      return false;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Delete Game ──────────────────────────────────────────────────────
  Future<bool> deleteGame(int gameId) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.deleteGame(gameId);
      _wsService.disconnect();
      _currentGame = null;
      _resetMonitorState();
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = _extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  // ── Start Game ───────────────────────────────────────────────────────
  void startGame({required int countdownSeconds, required String? token}) {
    if (_currentGame == null) return;
    // Client-side clamp: 10 - 120 seconds (saves round-trip on bad input)
    final clampedSeconds = countdownSeconds.clamp(10, 120);

    if (token != null && token.isNotEmpty) {
      _connectWebSocket(_currentGame!.id, token);
    }

    _wsService.sendStartGame(clampedSeconds);
  }

  // ── Reset to Create Game Form (After Finished / Exhausted) ────────────
  void resetToCreateForm() {
    _wsService.disconnect();
    _currentGame = null;
    _resetMonitorState();
    notifyListeners();
  }

  // ── WebSocket Management ─────────────────────────────────────────────
  void _connectWebSocket(int gameId, String token) {
    _wsSubscription?.cancel();
    _connSubscription?.cancel();

    _connSubscription = _wsService.connectionState.listen((state) {
      _connectionState = state;
      notifyListeners();
    });

    _wsSubscription = _wsService.messages.listen(_handleWsMessage);
    _wsService.connect(gameId, token);
  }

  void _handleWsMessage(WsMessage message) {
    switch (message) {
      case SyncMessage(:final status, :final calledNumbers):
        _status = GameStatus.fromString(status);
        _calledNumbers.clear();
        _calledNumbersSet.clear();
        for (final num in calledNumbers.reversed) {
          _calledNumbers.add(num);
          _calledNumbersSet.add(num);
        }
        notifyListeners();

      case GameStartingMessage(:final startsAt):
        _status = GameStatus.pending;
        _countdownStartsAt = startsAt;
        _isCountdownActive = true;
        notifyListeners();

      case GameStartedMessage():
        _status = GameStatus.active;
        _isCountdownActive = false;
        _countdownStartsAt = null;
        notifyListeners();

      case NumberCalledMessage(:final value):
        if (!_calledNumbersSet.contains(value)) {
          _calledNumbers.insert(0, value);
          _calledNumbersSet.add(value);
          notifyListeners();
        }

      case GameFinishedMessage(
        :final winnerUserId,
        :final winnerName,
        :final winningCardId,
        :final winningGrid,
      ):
        _status = GameStatus.finished;
        _isGameFinished = true;
        _winnerUserId = winnerUserId;
        _winnerName = winnerName;
        _winningCardId = winningCardId;
        _winningGrid = winningGrid;
        notifyListeners();

      case PoolExhaustedMessage():
        _status = GameStatus.finished;
        _isPoolExhausted = true;
        notifyListeners();

      case ErrorMessage(:final detail):
        _errorMessage = detail;
        notifyListeners();

      case BingoResultMessage():
        // Player-specific outcome, admin does not need special handling
        break;
    }
  }

  void _resetMonitorState() {
    _status = GameStatus.pending;
    _calledNumbers.clear();
    _calledNumbersSet.clear();
    _countdownStartsAt = null;
    _isCountdownActive = false;
    _isGameFinished = false;
    _isPoolExhausted = false;
    _winnerUserId = null;
    _winnerName = null;
    _winningCardId = null;
    _winningGrid = null;
  }

  String _extractErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.response?.data is Map &&
          error.response?.data['detail'] != null) {
        return error.response?.data['detail'].toString() ??
            error.message ??
            'Server error';
      }
      if (error.message != null && error.message!.isNotEmpty) {
        return error.message!;
      }
    }
    return error.toString();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _connSubscription?.cancel();
    _wsService.disconnect();
    super.dispose();
  }
}
