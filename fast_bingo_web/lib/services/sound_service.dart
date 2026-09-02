import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/ws_message.dart';
import 'ws_service.dart';

class SoundService {
  final WsService _wsService;
  StreamSubscription<WsMessage>? _messageSubscription;
  StreamSubscription<void>? _completionSubscription;

  // One shared cache so the preload below actually benefits both
  // players -- without assigning it explicitly, each AudioPlayer would
  // default to its own separate global cache reference and preloading
  // one wouldn't warm the other.
  final AudioCache _cache = AudioCache();
  late final AudioPlayer _letterPlayer = AudioPlayer()..audioCache = _cache;
  late final AudioPlayer _numberPlayer = AudioPlayer()..audioCache = _cache;

  bool _muted = false;
  bool _preloaded = false;

  SoundService({required WsService wsService}) : _wsService = wsService;

  bool get isMuted => _muted;
  void setMuted(bool muted) => _muted = muted;

  Future<void> start() async {
    _messageSubscription ??= _wsService.messages.listen(_handleMessage);
    await _preload();
  }

  Future<void> _preload() async {
    if (_preloaded) return;
    final fileNames = [
      'nums/b.mp3',
      'nums/i.mp3',
      'nums/n.mp3',
      'nums/g.mp3',
      'nums/o.mp3',
      for (var n = 1; n <= 75; n++) 'nums/en_num_$n.mp3',
    ];
    try {
      await _cache.loadAll(fileNames);
      _preloaded = true;
    } catch (e) {
      // Preload failing shouldn't block the app -- calls will just fall
      // back to fetching on demand, same as before this change.
      debugPrint(
        'SoundService: preload failed, falling back to on-demand fetch: $e',
      );
    }
  }

  void _handleMessage(WsMessage message) {
    if (message is NumberCalledMessage) {
      _announce(message.value);
    }
  }

  Future<void> _announce(int number) async {
    if (_muted) return;

    await _completionSubscription?.cancel();

    final letter = _letterFor(number);

    try {
      await _letterPlayer.stop();
      await _letterPlayer.play(AssetSource('nums/$letter.mp3'));

      _completionSubscription = _letterPlayer.onPlayerComplete.listen((
        _,
      ) async {
        await _numberPlayer.stop();
        await _numberPlayer.play(AssetSource('nums/en_num_$number.mp3'));
      });
    } catch (e) {
      debugPrint('SoundService: failed to play call-out for $number: $e');
    }
  }

  String _letterFor(int number) {
    if (number >= 1 && number <= 15) return 'b';
    if (number >= 16 && number <= 30) return 'i';
    if (number >= 31 && number <= 45) return 'n';
    if (number >= 46 && number <= 60) return 'g';
    if (number >= 61 && number <= 75) return 'o';
    throw ArgumentError('Number $number is outside the 1-75 bingo range');
  }

  void dispose() {
    _messageSubscription?.cancel();
    _completionSubscription?.cancel();
    _letterPlayer.dispose();
    _numberPlayer.dispose();
  }
}
