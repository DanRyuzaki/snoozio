import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class MusicPlayerController extends ChangeNotifier {
  static final MusicPlayerController _instance =
      MusicPlayerController._internal();
  factory MusicPlayerController() => _instance;
  MusicPlayerController._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  double _volume = 0.5;
  String? _currentTrackId;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isFadingOut = false;

  bool get isPlaying => _isPlaying;
  double get volume => _volume;
  String? get currentTrackId => _currentTrackId;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get isFadingOut => _isFadingOut;

  final List<MusicTrack> tracks = [
    MusicTrack(
      id: 'white_noise',
      name: 'White Noise',
      description: 'Consistent sound for deep sleep',
      icon: Icons.contrast,
      assetPath: 'audio/white_noise_background.mp3',
    ),
    MusicTrack(
      id: 'relaxing_instrumental',
      name: 'Calming Instrumental',
      description: 'Gentle instrumental soundscape',
      icon: Icons.ac_unit,
      assetPath: 'audio/relaxing_instrumental.mp3',
    ),
    MusicTrack(
      id: 'ambient_music',
      name: 'Meditating',
      description: 'Calming meditating ambience',
      icon: Icons.fitbit,
      assetPath: 'audio/ambient_music.mp3',
    ),
    MusicTrack(
      id: 'nature_background',
      name: 'Nature',
      description: 'Peaceful forest ambience',
      icon: Icons.nature,
      assetPath: 'audio/nature_backgroud.mp3',
    ),
  ];

  void initialize() {
    _audioPlayer.onDurationChanged.listen((duration) {
      _duration = duration;
      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((position) {
      _position = position;
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _position = Duration.zero;
      notifyListeners();
    });
  }

  Future<void> playTrack(String trackId) async {
    try {
      final track = tracks.firstWhere((t) => t.id == trackId);

      if (_currentTrackId == trackId && _isPlaying) {
        return;
      }

      await _audioPlayer.stop();

      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource(track.assetPath));

      _currentTrackId = trackId;
      _isPlaying = true;
      _isFadingOut = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing track: $e');
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    await _audioPlayer.resume();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    _position = Duration.zero;
    _currentTrackId = null;
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
    notifyListeners();
  }

  Future<void> fadeOut({int durationSeconds = 10}) async {
    if (!_isPlaying || _isFadingOut) return;

    _isFadingOut = true;
    notifyListeners();

    final initialVolume = _volume;
    final steps = 20;
    final stepDuration = Duration(
      milliseconds: (durationSeconds * 1000) ~/ steps,
    );

    for (int i = 0; i < steps; i++) {
      if (!_isFadingOut) break;

      final newVolume = initialVolume * (1 - (i + 1) / steps);
      await setVolume(newVolume);
      await Future.delayed(stepDuration);
    }

    await stop();
    await setVolume(initialVolume);
    _isFadingOut = false;
    notifyListeners();
  }

  void cancelFadeOut() {
    _isFadingOut = false;
    notifyListeners();
  }

  MusicTrack? getCurrentTrack() {
    if (_currentTrackId == null) return null;
    try {
      return tracks.firstWhere((t) => t.id == _currentTrackId);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

class MusicTrack {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String assetPath;

  MusicTrack({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.assetPath,
  });
}
