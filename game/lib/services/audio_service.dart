import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioPlayer _musicPlayer = AudioPlayer();
  static bool _initialized = false;
  static bool _musicPlaying = false;
  static bool _appInForeground = true;
  static Timer? _watchdogTimer;

  // Audio settings
  static bool isMusicEnabled = true;
  static bool isSfxEnabled = true;
  static double musicVolume = 0.40;
  static double sfxVolume = 0.85;

  // Pre-allocated SFX Player Pool for zero-latency concurrent gunshots & hits
  static const int _poolSize = 6;
  static final List<AudioPlayer> _sfxPool = [];
  static int _sfxPoolIndex = 0;

  static final ValueNotifier<bool> musicNotifier = ValueNotifier(true);
  static final ValueNotifier<bool> sfxNotifier = ValueNotifier(true);

  /// Initializes audio system with optimized Android audio focus configuration.
  /// Configures music & SFX pipelines to coexist without ducking or sudden stops.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
          ),
        ),
      );

      // Pre-warm SFX audio players
      for (int i = 0; i < _poolSize; i++) {
        final player = AudioPlayer();
        try {
          await player.setPlayerMode(PlayerMode.lowLatency);
          await player.setReleaseMode(ReleaseMode.stop);
          await player.setVolume(sfxVolume);
          _sfxPool.add(player);
        } catch (e) {
          debugPrint('[Audio] Pool player $i init notice: $e');
        }
      }

      // Configure background music player
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(musicVolume);

      // 1. Explicit loop completion listener for Android MediaPlayer consistency
      _musicPlayer.onPlayerComplete.listen((_) async {
        if (isMusicEnabled && _appInForeground) {
          try {
            await _musicPlayer.seek(Duration.zero);
            await _musicPlayer.resume();
            _musicPlaying = true;
          } catch (_) {
            await playMusic();
          }
        }
      });

      // 2. Keep loop consistency and auto-recover if audio focus or state changes
      _musicPlayer.onPlayerStateChanged.listen((state) async {
        if (state == PlayerState.playing) {
          _musicPlaying = true;
        } else if (state == PlayerState.stopped || state == PlayerState.completed) {
          _musicPlaying = false;
          if (isMusicEnabled && _appInForeground) {
            try {
              await _musicPlayer.seek(Duration.zero);
              await _musicPlayer.resume();
              _musicPlaying = true;
            } catch (_) {
              await playMusic();
            }
          }
        }
      });

      // 3. Periodic Background Sound Watchdog
      // Checks every 2.5 seconds to guarantee background music stays consistently alive
      // across audio interruptions, Bluetooth connects/disconnects, or notification sounds.
      _watchdogTimer?.cancel();
      _watchdogTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        if (isMusicEnabled && _appInForeground && !_musicPlaying) {
          playMusic();
        }
      });
    } catch (e) {
      debugPrint('[Audio] Audio initialization error: $e');
    }
  }

  /// Start or restart background music seamlessly
  static Future<void> playMusic() async {
    if (!isMusicEnabled || !_appInForeground) return;

    try {
      if (!_initialized) {
        await initialize();
      }

      if (_musicPlaying && _musicPlayer.state == PlayerState.playing) {
        return;
      }

      await _musicPlayer.setVolume(musicVolume);
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.play(AssetSource('music.mp3'));
      _musicPlaying = true;
    } catch (e) {
      debugPrint('[Audio] Failed to play music: $e');
    }
  }

  /// Pause music when app goes to background or is minimized
  static Future<void> pauseMusic() async {
    _appInForeground = false;
    try {
      await _musicPlayer.pause();
      _musicPlaying = false;
    } catch (_) {}
  }

  /// Resume music when app returns to foreground
  static Future<void> resumeMusic() async {
    _appInForeground = true;
    if (!isMusicEnabled) return;
    try {
      if (_musicPlayer.state == PlayerState.paused) {
        await _musicPlayer.resume();
        _musicPlaying = true;
      } else if (_musicPlayer.state != PlayerState.playing) {
        await playMusic();
      }
    } catch (_) {
      await playMusic();
    }
  }

  /// Stop music completely
  static void stopMusic() {
    try {
      _musicPlayer.stop();
      _musicPlaying = false;
    } catch (_) {}
  }

  /// Play gunshot sound using pooled low-latency players without stalling audio thread
  static Future<void> playGunSound() async {
    if (!isSfxEnabled) return;

    try {
      if (!_initialized) {
        await initialize();
      }
      if (_sfxPool.isEmpty) return;

      final player = _sfxPool[_sfxPoolIndex];
      _sfxPoolIndex = (_sfxPoolIndex + 1) % _sfxPool.length;

      await player.stop();
      await player.setVolume(sfxVolume);
      await player.play(AssetSource('bullet.mp3'), mode: PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('[Audio] Failed to play gun sound: $e');
    }
  }

  /// Adjust background music volume
  static void setMusicVolume(double vol) {
    musicVolume = vol.clamp(0.0, 1.0);
    _musicPlayer.setVolume(isMusicEnabled ? musicVolume : 0.0);
  }

  /// Adjust sound effects volume
  static void setSfxVolume(double vol) {
    sfxVolume = vol.clamp(0.0, 1.0);
    for (final p in _sfxPool) {
      p.setVolume(isSfxEnabled ? sfxVolume : 0.0);
    }
  }

  /// Toggle background music on/off
  static void toggleMusic() {
    isMusicEnabled = !isMusicEnabled;
    musicNotifier.value = isMusicEnabled;
    if (isMusicEnabled) {
      playMusic();
    } else {
      pauseMusic();
    }
  }

  /// Toggle SFX on/off
  static void toggleSfx() {
    isSfxEnabled = !isSfxEnabled;
    sfxNotifier.value = isSfxEnabled;
  }

  /// Clean up audio resources
  static void dispose() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    try {
      _musicPlayer.dispose();
      for (final p in _sfxPool) {
        p.dispose();
      }
      _sfxPool.clear();
      _musicPlaying = false;
      _initialized = false;
    } catch (_) {}
  }
}
