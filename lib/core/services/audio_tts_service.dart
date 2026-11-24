import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
      // 1. Getarkan perangkat menggunakan getaran haptic bawaan Flutter SDK
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 250));
      await HapticFeedback.vibrate();
    } catch (e) {
      developer.log('Haptic vibration error: $e', name: 'AudioTtsService');
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
