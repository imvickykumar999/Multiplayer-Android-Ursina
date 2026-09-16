import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioPlayer _musicPlayer = AudioPlayer();
  static final AudioPlayer _sfxPlayer = AudioPlayer();
  static bool _musicPlaying = false;

  static Future<void> playMusic() async {
    try {
      if (_musicPlaying) return;
      _musicPlaying = true;
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.3);
      await _musicPlayer.play(AssetSource('music.mp3'));
    } catch (e) {
      debugPrint('[Audio] Failed to play music: $e');
    }
  }

  static Future<void> playGunSound() async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setVolume(1.0);
      await _sfxPlayer.play(AssetSource('bullet.mp3'));
    } catch (e) {
      debugPrint('[Audio] Failed to play gun sound: $e');
    }
  }

  static void stopMusic() {
    try {
      _musicPlayer.stop();
      _musicPlaying = false;
    } catch (_) {}
  }

  static void dispose() {
    try {
      _musicPlayer.dispose();
      _sfxPlayer.dispose();
    } catch (_) {}
  }
}
