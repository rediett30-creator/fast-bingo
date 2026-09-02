import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/card.dart';
import '../services/api_service.dart';

class PurchaseResultItem {
  final int cardId;
  final bool success;
  final String? errorMessage;

  const PurchaseResultItem({
    required this.cardId,
    required this.success,
    this.errorMessage,
  });
}

class BuyCardsState extends ChangeNotifier {
  final ApiService _apiService;

  List<CardModel> _cards = [];
  int _total = 0;
  int _offset = 0;
  static const int _pageSize = 20;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isPurchasing = false;
  String? _errorMessage;

  final Set<int> _selectedCardIds = {};
  List<PurchaseResultItem> _lastPurchaseResults = [];

  BuyCardsState({required ApiService apiService}) : _apiService = apiService;

  List<CardModel> get cards => _cards;
  int get total => _total;
  bool get hasMore => _cards.length < _total;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isPurchasing => _isPurchasing;
  String? get errorMessage => _errorMessage;

  Set<int> get selectedCardIds => _selectedCardIds;
  int get selectedCount => _selectedCardIds.length;
  List<PurchaseResultItem> get lastPurchaseResults => _lastPurchaseResults;

  /// Load first page of available cards for the given game.
  Future<void> loadCards(int gameId) async {
    _isLoading = true;
    _errorMessage = null;
    _offset = 0;
    _selectedCardIds.clear();
    _lastPurchaseResults = [];
    notifyListeners();

    try {
      final result = await _apiService.getAvailableCards(
        gameId,
        limit: _pageSize,
        offset: 0,
      );
      _cards = result.items;
      _total = result.total;
      _offset = _cards.length;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load cards: $e';
      notifyListeners();
    }
  }

  /// Load next page for pagination / infinite scroll.
  Future<void> loadMore(int gameId) async {
    if (_isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final result = await _apiService.getAvailableCards(
        gameId,
        limit: _pageSize,
        offset: _offset,
      );
      _cards.addAll(result.items);
      _total = result.total;
      _offset = _cards.length;
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isLoadingMore = false;
      debugPrint('Failed to load more cards: $e');
      notifyListeners();
    }
  }

  /// Toggle selection state of a card.
  void toggleSelection(int cardId) {
    if (_selectedCardIds.contains(cardId)) {
      _selectedCardIds.remove(cardId);
    } else {
      _selectedCardIds.add(cardId);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedCardIds.clear();
    notifyListeners();
  }

  /// Purchase all selected cards sequentially/in parallel.
  /// Handles partial failures (e.g. 409 race conditions) explicitly.
  /// Returns `true` if all purchases succeeded.
  Future<bool> purchaseSelected(int gameId) async {
    if (_selectedCardIds.isEmpty || _isPurchasing) return false;

    _isPurchasing = true;
    _errorMessage = null;
    _lastPurchaseResults = [];
    notifyListeners();

    final toPurchase = List<int>.from(_selectedCardIds);
    final results = <PurchaseResultItem>[];
    final failedCardIds = <int>{};

    for (final cardId in toPurchase) {
      try {
        await _apiService.buyCard(gameId, cardId);
        results.add(PurchaseResultItem(cardId: cardId, success: true));
        // Remove successfully purchased card from selection and catalog list
        _selectedCardIds.remove(cardId);
        _cards.removeWhere((c) => c.id == cardId);
        _total = (_total > 0) ? _total - 1 : 0;
      } on DioException catch (e) {
        String detail = 'Purchase failed';
        if (e.response?.statusCode == 409) {
          detail = 'Card was just bought by someone else';
        } else if (e.response?.data is Map && e.response?.data['detail'] != null) {
          detail = e.response?.data['detail'].toString() ?? detail;
        } else if (e.message != null) {
          detail = e.message!;
        }
        results.add(PurchaseResultItem(
          cardId: cardId,
          success: false,
          errorMessage: detail,
        ));
        failedCardIds.add(cardId);
      } catch (e) {
        results.add(PurchaseResultItem(
          cardId: cardId,
          success: false,
          errorMessage: e.toString(),
        ));
        failedCardIds.add(cardId);
      }
    }

    _lastPurchaseResults = results;
    _isPurchasing = false;
    notifyListeners();

    return failedCardIds.isEmpty;
  }
}
