class PatternModel {
  final int id;
  final String name;
  final String description;
  final List<int> coveredCells;

  const PatternModel({
    required this.id,
    required this.name,
    required this.description,
    required this.coveredCells,
  });

  factory PatternModel.fromJson(Map<String, dynamic> json) {
    return PatternModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      coveredCells: (json['covered_cells'] as List).cast<int>(),
    );
  }
}

enum GameStatus {
  pending,
  active,
  finished;

  static GameStatus fromString(String s) {
    switch (s) {
      case 'pending':
        return GameStatus.pending;
      case 'active':
        return GameStatus.active;
      case 'finished':
        return GameStatus.finished;
      default:
        return GameStatus.pending;
    }
  }
}

class GameModel {
  final int id;
  final GameStatus status;
  final int cardPrice;
  final int totalAward;
  final int patternId;
  final int createdBy;
  final String? startedAt;
  final String createdAt;

  const GameModel({
    required this.id,
    required this.status,
    required this.cardPrice,
    required this.totalAward,
    required this.patternId,
    required this.createdBy,
    this.startedAt,
    required this.createdAt,
  });

  factory GameModel.fromJson(Map<String, dynamic> json) {
    return GameModel(
      id: json['id'] as int,
      status: GameStatus.fromString(json['status'] as String),
      cardPrice: json['card_price'] as int,
      totalAward: json['total_award'] as int,
      patternId: json['pattern_id'] as int,
      createdBy: json['created_by'] as int,
      startedAt: json['started_at'] as String?,
      createdAt: json['created_at'] as String,
    );
  }
}

/// Game + nested pattern, matching backend's GameWithPattern schema.
class GameWithPattern extends GameModel {
  final PatternModel pattern;

  const GameWithPattern({
    required super.id,
    required super.status,
    required super.cardPrice,
    required super.totalAward,
    required super.patternId,
    required super.createdBy,
    super.startedAt,
    required super.createdAt,
    required this.pattern,
  });

  factory GameWithPattern.fromJson(Map<String, dynamic> json) {
    return GameWithPattern(
      id: json['id'] as int,
      status: GameStatus.fromString(json['status'] as String),
      cardPrice: json['card_price'] as int,
      totalAward: json['total_award'] as int,
      patternId: json['pattern_id'] as int,
      createdBy: json['created_by'] as int,
      startedAt: json['started_at'] as String?,
      createdAt: json['created_at'] as String,
      pattern: PatternModel.fromJson(json['pattern'] as Map<String, dynamic>),
    );
  }
}
