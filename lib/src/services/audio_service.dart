import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Manages in-SDK audio playback: ringtone on incoming call and short
/// notification chimes for new messages.
///
/// Call [init] once before using — it configures the audio session so that:
/// - iOS: audio plays through the device speaker even when the ringer switch
///   is off (uses `AVAudioSessionCategoryPlayback`).
/// - Android: the correct audio focus is requested before playback.
///
/// **Host app setup:** ringtone/notification playback needs no extra
/// permissions. Microphone access is only required for WebRTC calls
/// (`NSMicrophoneUsageDescription` / `RECORD_AUDIO`) — see README.
class AudioService {
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final AudioPlayer _notificationPlayer = AudioPlayer();

  bool _ringtoneLoaded = false;
  bool _notificationLoaded = false;
  bool _sessionReady = false;

  // ── Session setup ─────────────────────────────────────────────────────────

  /// Configures the platform audio session. Must be called once before the
  /// first [playRingtone] or [playMessageNotification] invocation.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> init() async {
    if (_sessionReady) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        // iOS: AVAudioSessionCategoryPlayback lets audio play even when the
        // hardware ringer switch is flipped to silent.
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        // Android: use STREAM_RING / USAGE_NOTIFICATION_RINGTONE so the OS
        // routes through the ringer volume slider, not the media slider.
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          flags: AndroidAudioFlags.audibilityEnforced,
          usage: AndroidAudioUsage.notificationRingtone,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      _sessionReady = true;
      // debugPrint('[Covaone Audio] session configured');
    } catch (e) {
      // debugPrint('[Covaone Audio] init failed: $e');
    }
  }

  // ── Ringtone ──────────────────────────────────────────────────────────────

  /// Plays the incoming-call ringtone on loop until [stopRingtone] is called.
  Future<void> playRingtone() async {
    try {
      await init();
      if (!_ringtoneLoaded) {
        await _ringtonePlayer.setAsset(
          'packages/covaone_sdk/assets/audio/ringtone.mp3',
        );
        _ringtoneLoaded = true;
      }
      await _ringtonePlayer.setLoopMode(LoopMode.one);
      // Seek to the start in case a previous ring was stopped mid-play.
      await _ringtonePlayer.seek(Duration.zero);
      await _ringtonePlayer.play();
    } catch (e) {
      // debugPrint('[Covaone Audio] playRingtone failed: $e');
    }
  }

  Future<void> stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
    } catch (e) {
      // debugPrint('[Covaone Audio] stopRingtone: $e');
    }
  }

  // ── Message notification ──────────────────────────────────────────────────

  /// Plays a short chime when a new inbound message arrives and the panel
  /// is closed. Safe to call in rapid succession — restarts from the
  /// beginning each time.
  Future<void> playMessageNotification() async {
    try {
      await init();
      if (!_notificationLoaded) {
        await _notificationPlayer.setAsset(
          'packages/covaone_sdk/assets/audio/notification.mp3',
        );
        _notificationLoaded = true;
      }
      await _notificationPlayer.seek(Duration.zero);
      await _notificationPlayer.play();
    } catch (e) {
      // debugPrint('[Covaone Audio] playMessageNotification failed: $e');
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _ringtonePlayer.dispose();
    await _notificationPlayer.dispose();
  }
}
