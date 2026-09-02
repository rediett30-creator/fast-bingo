class CardModel {
  final int id;
  final List<int?> grid;

  const CardModel({required this.id, required this.grid});

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] as int,
      grid: (json['grid'] as List).map((e) => e as int?).toList(),
    );
  }
}

class PaginatedCards {
  final List<CardModel> items;
  final int total;
  final int limit;
  final int offset;

  const PaginatedCards({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory PaginatedCards.fromJson(Map<String, dynamic> json) {
    return PaginatedCards(
      items: (json['items'] as List)
          .map((e) => CardModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }
}
