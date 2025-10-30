import 'package:audioplayers/audioplayers.dart';

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
