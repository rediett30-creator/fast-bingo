import 'card.dart';

class GameCardModel {
  final int id;
  final int gameId;
  final bool isWinner;
  final String purchasedAt;
  final CardModel card;

  const GameCardModel({
    required this.id,
    required this.gameId,
    required this.isWinner,
    required this.purchasedAt,
    required this.card,
  });

  factory GameCardModel.fromJson(Map<String, dynamic> json) {
    return GameCardModel(
      id: json['id'] as int,
      gameId: json['game_id'] as int,
      isWinner: json['is_winner'] as bool,
      purchasedAt: json['purchased_at'] as String,
      card: CardModel.fromJson(json['card'] as Map<String, dynamic>),
    );
  }
}
