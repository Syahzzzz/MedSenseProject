import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsManager {
  static final TtsManager _instance = TtsManager._internal();
  factory TtsManager() => _instance;
  TtsManager._internal();

  FlutterTts? _flutterTts;
  bool _isEnabled = false;

  Future<void> init() async {
    _flutterTts = FlutterTts();
    await _flutterTts?.setLanguage("en-US");
    await _flutterTts?.setSpeechRate(0.5);
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      stop();
    }
  }

  Future<void> speak(String text) async {
    if (!_isEnabled || text.isEmpty) return;
    
    debugPrint("TTS Speaking: $text");
    
    await _flutterTts?.stop(); 
    await _flutterTts?.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts?.stop();
  }
}