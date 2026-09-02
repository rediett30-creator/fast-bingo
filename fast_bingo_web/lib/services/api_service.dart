import 'package:dio/dio.dart';
import '../config.dart';
import '../models/game.dart';
import '../models/card.dart';
import '../models/game_card.dart';

class ApiService {
  late final Dio dio;

  void Function()? onUnauthorized;

  ApiService() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    dio.options.headers.remove('Authorization');
  }

  Future<String> authenticateTelegram(String initData) async {
    final response = await dio.post(
      '/auth/telegram',
      data: {'init_data': initData},
    );
    return response.data['access_token'] as String;
  }

  Future<GameWithPattern?> getCurrentGame() async {
    try {
      final response = await dio.get('/games/current');
      return GameWithPattern.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<PaginatedCards> getAvailableCards(
    int gameId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await dio.get(
      '/cards',
      queryParameters: {'game_id': gameId, 'limit': limit, 'offset': offset},
    );
    return PaginatedCards.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<GameCardModel>> getMyCards(int gameId) async {
    final response = await dio.get('/games/$gameId/cards/mine');
    return (response.data as List)
        .map((e) => GameCardModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GameCardModel> buyCard(int gameId, int cardId) async {
    final response = await dio.post('/games/$gameId/cards/$cardId');
    return GameCardModel.fromJson(response.data as Map<String, dynamic>);
  }

  //Admin-only endpoints
  Future<GameModel> createGame({
    required int cardPrice,
    required int totalAward,
    required int patternId,
  }) async {
    final response = await dio.post(
      '/games',
      data: {
        'card_price': cardPrice,
        'total_award': totalAward,
        'pattern_id': patternId,
      },
    );
    return GameModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteGame(int gameId) async {
    await dio.delete('/games/$gameId');
  }

  Future<List<PatternModel>> getPatterns() async {
    final response = await dio.get('/patterns');
    return (response.data as List)
        .map((e) => PatternModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
