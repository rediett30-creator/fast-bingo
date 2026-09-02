import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../models/game_card.dart';
import '../models/ws_message.dart';
import '../services/api_service.dart';
import '../services/ws_service.dart';

class GameState extends ChangeNotifier {
  final ApiService _apiService;
  final WsService _wsService;

  GameWithPattern? _currentGame;
  List<GameCardModel> _myCards = [];
  final List<int> _calledNumbers = []; // Recent numbers, newest first at index 0
  final Set<int> _calledNumbersSet = {}; // For fast O(1) membership check

  // Interactive user-marked cells per card: Map<cardId, Set<cellIndex>>
  final Map<int, Set<int>> _userMarkedCells = {};

  // Lost / Invalidated cards: Map<cardId, reason>
  final Map<int, String> _lostCards = {};

  bool _isLoading = false;
  bool _hasNoGame = false;
  String? _errorMessage;

  // Countdown & game status
  double? _countdownStartsAt;
  bool _isCountdownActive = false;
  GameStatus _status = GameStatus.pending;

  // Game resolution
  bool _isGameFinished = false;
  bool _isPoolExhausted = false;
  int? _winnerUserId;
  String? _winnerName;
  int? _winningCardId;
  List<int?>? _winningGrid;

  // Bingo claim state
  final Set<int> _pendingBingoCardIds = {};
  int? _lastClaimedCardId;
  String? _bingoToastMessage;
  String? _wsToastMessage;

  // Connection state
  WsConnectionState _connectionState = WsConnectionState.disconnected;

  StreamSubscription<WsMessage>? _wsSubscription;
  StreamSubscription<WsConnectionState>? _connSubscription;

  GameState({required ApiService apiService, required WsService wsService})
      : _apiService = apiService,
        _wsService = wsService;

  // ── Getters ──────────────────────────────────────────────────────────
  GameWithPattern? get currentGame => _currentGame;
  List<GameCardModel> get myCards => _myCards;
  List<int> get calledNumbers => List.unmodifiable(_calledNumbers);
  bool get isLoading => _isLoading;
  bool get hasNoGame => _hasNoGame;
  String? get errorMessage => _errorMessage;

  double? get countdownStartsAt => _countdownStartsAt;
  bool get isCountdownActive => _isCountdownActive;
  GameStatus get status => _status;

  bool get isGameFinished => _isGameFinished;
  bool get isPoolExhausted => _isPoolExhausted;
  int? get winnerUserId => _winnerUserId;
  String? get winnerName => _winnerName;
  int? get winningCardId => _winningCardId;
  List<int?>? get winningGrid => _winningGrid;

  Set<int> get pendingBingoCardIds => _pendingBingoCardIds;
  String? get bingoToastMessage => _bingoToastMessage;
  String? get wsToastMessage => _wsToastMessage;
  WsConnectionState get connectionState => _connectionState;

  bool isCardBingoPending(int cardId) => _pendingBingoCardIds.contains(cardId);
  bool isCardLost(int cardId) => _lostCards.containsKey(cardId);
  String? getCardLostReason(int cardId) => _lostCards[cardId];
  Map<int, String> get lostCards => _lostCards;

  /// True if the user owned cards and all of them were invalidated/lost
  bool get isAllCardsLost =>
      _myCards.isNotEmpty && _myCards.every((c) => _lostCards.containsKey(c.card.id));

  void clearToasts() {
    _bingoToastMessage = null;
    _wsToastMessage = null;
    notifyListeners();
  }

  // ── Interactive Cell Selection / Deselection ─────────────────────────
  Set<int> getCardMarks(int cardId) {
    return _userMarkedCells[cardId] ?? {12}; // Index 12 is always free space
  }

  /// Toggle marking on a specific card cell by index (0-24)
  void toggleCellMark(int cardId, int cellIndex) {
    if (_isGameFinished || _isPoolExhausted || isCardLost(cardId)) return;

    final currentMarks = _userMarkedCells.putIfAbsent(cardId, () => {12});
    if (cellIndex == 12) {
      // Free space stays marked
      currentMarks.add(12);
    } else if (currentMarks.contains(cellIndex)) {
      currentMarks.remove(cellIndex);
    } else {
      currentMarks.add(cellIndex);
    }
    notifyListeners();
  }

  // ── Load / Refresh Game ──────────────────────────────────────────────
  Future<void> loadCurrentGame(String? token) async {
    _isLoading = true;
    _hasNoGame = false;
    _errorMessage = null;
    _resetGamePlayState();
    notifyListeners();

    try {
      final game = await _apiService.getCurrentGame();
      if (game == null) {
        _hasNoGame = true;
        _isLoading = false;
        notifyListeners();
        return;
      }

      _currentGame = game;
      _status = game.status;

      // Fetch user's cards for this game
      await _fetchMyCards(game.id);

      // Connect WebSocket if token is available
      if (token != null && token.isNotEmpty) {
        _connectWebSocket(game.id, token);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load game: $e';
      notifyListeners();
    }
  }

  Future<void> _fetchMyCards(int gameId) async {
    try {
      _myCards = await _apiService.getMyCards(gameId);
      for (final card in _myCards) {
        _userMarkedCells.putIfAbsent(card.card.id, () => {12});
      }
    } catch (e) {
      debugPrint('Failed to load my cards: $e');
    }
  }

  /// Reload user's cards (e.g. after returning from Buy Cards screen)
  Future<void> refreshMyCards() async {
    if (_currentGame == null) return;
    await _fetchMyCards(_currentGame!.id);
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
        // Server sends called numbers in chronological order; reverse for newest-first display
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
          _calledNumbers.insert(0, value); // Prepend to show most recent at start of row
          _calledNumbersSet.add(value);
          notifyListeners();
        }

      case BingoResultMessage(:final outcome, :final reason):
        final claimedId = _lastClaimedCardId ?? _pendingBingoCardIds.firstOrNull;
        if (claimedId != null && (outcome == 'lost' || outcome == 'late')) {
          _lostCards[claimedId] = reason;
        }
        _pendingBingoCardIds.clear();
        _bingoToastMessage = '$outcome: $reason';
        notifyListeners();

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
        _pendingBingoCardIds.clear();
        notifyListeners();

      case PoolExhaustedMessage():
        _status = GameStatus.finished;
        _isPoolExhausted = true;
        _pendingBingoCardIds.clear();
        notifyListeners();

      case ErrorMessage(:final detail):
        _wsToastMessage = detail;
        _pendingBingoCardIds.clear();
        notifyListeners();
    }
  }

  // ── Bingo Claim ──────────────────────────────────────────────────────
  void claimBingo(int cardId) {
    if (_status != GameStatus.active || _isGameFinished || isCardLost(cardId)) return;
    _lastClaimedCardId = cardId;
    _pendingBingoCardIds.add(cardId);
    notifyListeners();
    _wsService.sendBingoClaim(cardId);
  }

  void _resetGamePlayState() {
    _calledNumbers.clear();
    _calledNumbersSet.clear();
    _userMarkedCells.clear();
    _lostCards.clear();
    _countdownStartsAt = null;
    _isCountdownActive = false;
    _isGameFinished = false;
    _isPoolExhausted = false;
    _winnerUserId = null;
    _winnerName = null;
    _winningCardId = null;
    _winningGrid = null;
    _pendingBingoCardIds.clear();
    _lastClaimedCardId = null;
    _bingoToastMessage = null;
    _wsToastMessage = null;
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _connSubscription?.cancel();
    _wsService.disconnect();
    super.dispose();
  }
}
