sealed class WsMessage {
  const WsMessage();

  factory WsMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'sync':
        return SyncMessage(
          status: json['status'] as String,
          calledNumbers: (json['called_numbers'] as List).cast<int>(),
        );
      case 'game_starting':
        return GameStartingMessage(
          startsInSeconds: (json['starts_in_seconds'] as num).toDouble(),
          startsAt: (json['starts_at'] as num).toDouble(),
        );
      case 'game_started':
        return const GameStartedMessage();
      case 'number_called':
        return NumberCalledMessage(
          value: json['value'] as int,
          callIndex: json['call_index'] as int,
        );
      case 'bingo_result':
        return BingoResultMessage(
          outcome: json['outcome'] as String,
          reason: json['reason'] as String,
        );
      case 'game_finished':
        return GameFinishedMessage(
          winnerUserId: json['winner_user_id'] as int,
          winnerName: json['winner_name'] as String,
          winningCardId: json['winning_card_id'] as int,
          winningGrid: (json['winning_grid'] as List)
              .map((e) => e as int?)
              .toList(),
        );
      case 'pool_exhausted':
        return const PoolExhaustedMessage();
      case 'error':
        return ErrorMessage(detail: json['detail'] as String);
      default:
        return ErrorMessage(detail: 'Unknown message type: $type');
    }
  }
}

class SyncMessage extends WsMessage {
  final String status;
  final List<int> calledNumbers;
  const SyncMessage({required this.status, required this.calledNumbers});
}

class GameStartingMessage extends WsMessage {
  final double startsInSeconds;
  final double startsAt;
  const GameStartingMessage({
    required this.startsInSeconds,
    required this.startsAt,
  });
}

class GameStartedMessage extends WsMessage {
  const GameStartedMessage();
}

class NumberCalledMessage extends WsMessage {
  final int value;
  final int callIndex;
  const NumberCalledMessage({required this.value, required this.callIndex});
}

class BingoResultMessage extends WsMessage {
  final String outcome;
  final String reason;
  const BingoResultMessage({required this.outcome, required this.reason});
}

class GameFinishedMessage extends WsMessage {
  final int winnerUserId;
  final String winnerName;
  final int winningCardId;
  final List<int?> winningGrid;
  const GameFinishedMessage({
    required this.winnerUserId,
    required this.winnerName,
    required this.winningCardId,
    required this.winningGrid,
  });
}

class PoolExhaustedMessage extends WsMessage {
  const PoolExhaustedMessage();
}

class ErrorMessage extends WsMessage {
  final String detail;
  const ErrorMessage({required this.detail});
}
