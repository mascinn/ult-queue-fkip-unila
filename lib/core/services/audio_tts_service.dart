import 'dart:developer' as developer;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

class AudioTtsService {
  static final AudioTtsService _instance = AudioTtsService._internal();
  factory AudioTtsService() => _instance;
  AudioTtsService._internal();

  FlutterTts? _flutterTts;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _flutterTts = FlutterTts();
      await _flutterTts?.setLanguage('id-ID');
      await _flutterTts?.setSpeechRate(0.48); // Kecepatan jelas dan ramah didengar
      await _flutterTts?.setVolume(1.0);
      await _flutterTts?.setPitch(1.0);
      _isInitialized = true;
    } catch (e) {
      developer.log('Error initializing TTS: $e', name: 'AudioTtsService');
    }
  }

  /// Memainkan getar dan ucapan suara pemanggilan
  /// Contoh teks: "Nomor antrean A-001, silakan menuju Loket 1"
  Future<void> playCallingAnnouncement({
    required String queueNumber,
    required String counterName,
  }) async {
    try {
      // 1. Getarkan perangkat jika didukung
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // Pola getar: Tunggu 0ms, getar 500ms, jeda 200ms, getar 800ms
        Vibration.vibrate(pattern: [0, 500, 200, 800]);
      }
    } catch (e) {
      developer.log('Vibration error: $e', name: 'AudioTtsService');
    }

    try {
      // 2. Mainkan Text-To-Speech
      await init();
      final speechText = 'Nomor antrean $queueNumber, silakan menuju $counterName.';
      await _flutterTts?.stop();
      await _flutterTts?.speak(speechText);
    } catch (e) {
      developer.log('TTS speak error: $e', name: 'AudioTtsService');
    }
  }

  /// Berhenti berbicara
  Future<void> stop() async {
    try {
      await _flutterTts?.stop();
    } catch (_) {}
  }
}
