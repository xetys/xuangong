import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class AudioService {
  // Singleton pattern
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _initialize();
  }

  // Separate players for each sound to allow parallel playback
  AudioPlayer? _startPlayer;
  AudioPlayer? _halfPlayer;
  AudioPlayer? _lastTwoPlayer;
  AudioPlayer? _longGongPlayer;

  bool _initialized = false;

  Future<void> _initialize() async {
    if (_initialized) return;

    _startPlayer = AudioPlayer();
    _halfPlayer = AudioPlayer();
    _lastTwoPlayer = AudioPlayer();
    _longGongPlayer = AudioPlayer();

    // Configure audio context for background playback on iOS
    if (!kIsWeb && Platform.isIOS) {
      final audioContext = AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      );
      AudioPlayer.global.setAudioContext(audioContext);
    }

    // Set release mode to allow sounds to overlap
    await _startPlayer!.setReleaseMode(ReleaseMode.stop);
    await _halfPlayer!.setReleaseMode(ReleaseMode.stop);
    await _lastTwoPlayer!.setReleaseMode(ReleaseMode.stop);
    await _longGongPlayer!.setReleaseMode(ReleaseMode.stop);

    // Pre-cache audio files for instant playback
    await _startPlayer!.setSource(AssetSource('sounds/start.wav'));
    await _halfPlayer!.setSource(AssetSource('sounds/half.wav'));
    await _lastTwoPlayer!.setSource(AssetSource('sounds/last_two.wav'));
    await _longGongPlayer!.setSource(AssetSource('sounds/longgong.wav'));

    _initialized = true;
  }

  Future<void> initialize() async {
    await _initialize();
  }

  // Convert volume from 0/25/50/75/100 to 0.0-1.0 range
  double _convertVolume(int volume) {
    return volume / 100.0;
  }

  Future<void> setCountdownVolume(int volume) async {
    await _ensureInitialized();
    await _lastTwoPlayer?.setVolume(_convertVolume(volume));
  }

  Future<void> setStartVolume(int volume) async {
    await _ensureInitialized();
    await _startPlayer?.setVolume(_convertVolume(volume));
  }

  Future<void> setHalfwayVolume(int volume) async {
    await _ensureInitialized();
    await _halfPlayer?.setVolume(_convertVolume(volume));
  }

  Future<void> setFinishVolume(int volume) async {
    await _ensureInitialized();
    await _longGongPlayer?.setVolume(_convertVolume(volume));
  }

  // Set all volumes at once
  Future<void> setAllVolumes({
    required int countdown,
    required int start,
    required int halfway,
    required int finish,
  }) async {
    await _ensureInitialized();
    await _lastTwoPlayer?.setVolume(_convertVolume(countdown));
    await _startPlayer?.setVolume(_convertVolume(start));
    await _halfPlayer?.setVolume(_convertVolume(halfway));
    await _longGongPlayer?.setVolume(_convertVolume(finish));
  }

  Future<void> playStart() async {
    await _ensureInitialized();
    try {
      await _startPlayer?.seek(Duration.zero);
      await _startPlayer?.resume();
    } catch (e) {
      print('Error playing start sound: $e');
    }
  }

  Future<void> playHalf() async {
    await _ensureInitialized();
    try {
      await _halfPlayer?.seek(Duration.zero);
      await _halfPlayer?.resume();
    } catch (e) {
      print('Error playing half sound: $e');
    }
  }

  Future<void> playLastTwo() async {
    await _ensureInitialized();
    try {
      await _lastTwoPlayer?.seek(Duration.zero);
      await _lastTwoPlayer?.resume();
    } catch (e) {
      print('Error playing last two sound: $e');
    }
  }

  Future<void> playLongGong() async {
    await _ensureInitialized();
    try {
      await _longGongPlayer?.seek(Duration.zero);
      await _longGongPlayer?.resume();
    } catch (e) {
      print('Error playing long gong sound: $e');
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _initialize();
    }
  }

  void dispose() {
    _startPlayer?.dispose();
    _halfPlayer?.dispose();
    _lastTwoPlayer?.dispose();
    _longGongPlayer?.dispose();
    _initialized = false;
  }
}
