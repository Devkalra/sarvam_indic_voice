import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'cart_model.dart';

const String kBackendBaseUrl = 'http://192.168.1.2:8000'; // Depends on User-User Network My Own IPV4 Address

enum RecordingState { idle, recording, processing, success, error }

class VoiceController extends ChangeNotifier {
  final CartModel _cart;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  bool _recorderInitialized = false;
  RecordingState _state = RecordingState.idle;
  String _statusMessage = 'Tap mic to order in Hindi';
  String? _errorMessage;
  String? _recordingPath;

  VoiceController(this._cart) {
    _initRecorder();
  }

  RecordingState get state => _state;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  bool get isRecording => _state == RecordingState.recording;
  bool get isProcessing => _state == RecordingState.processing;

  // ── Init recorder (called once at startup) ──────────────────────────────
  Future<void> _initRecorder() async {
    try {
      // Request mic permission explicitly before opening recorder
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _setError(
          'Microphone permission denied.\nGo to phone Settings → Apps → Sarvam Eats → Permissions → Allow Microphone.',
        );
        return;
      }

      await _recorder.openRecorder();
      _recorderInitialized = true;
    } catch (e) {
      _setError('Could not initialise recorder: $e');
    }
  }

  // ── Toggle: start if idle, stop+process if recording ────────────────────
  Future<void> toggleRecording() async {
    if (_state == RecordingState.recording) {
      await _stopAndProcess();
    } else if (_state == RecordingState.idle ||
        _state == RecordingState.success ||
        _state == RecordingState.error) {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    // Re-check permission every time in case user revoked it
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        _setError(
          'Microphone permission denied.\nGo to phone Settings → Apps → Sarvam Eats → Permissions → Allow Microphone.',
        );
        return;
      }
    }

    // Re-init recorder if needed
    if (!_recorderInitialized) {
      await _initRecorder();
      if (!_recorderInitialized) return;
    }

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/voice_order_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );

      _state = RecordingState.recording;
      _statusMessage = 'Bol raha hoon... (Listening)';
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _setError('Could not start recording: $e');
    }
  }

  Future<void> _stopAndProcess() async {
    try {
      await _recorder.stopRecorder();
    } catch (e) {
      _setError('Could not stop recording: $e');
      return;
    }

    if (_recordingPath == null) {
      _setError('No audio captured.');
      return;
    }

    _state = RecordingState.processing;
    _statusMessage = 'Sarvam AI processing...';
    notifyListeners();

    await _sendToBackend(File(_recordingPath!));
  }

  Future<void> _sendToBackend(File audioFile) async {
    try {
      final uri = Uri.parse('$kBackendBaseUrl/process-voice');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          audioFile.path,
          filename: 'order.wav',
        ),
      );

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await streamedResponse.stream.bytesToString();
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      _cart.addLog({
        'timestamp': DateTime.now().toIso8601String(),
        'status_code': streamedResponse.statusCode,
        'response': json,
      });

      if (streamedResponse.statusCode == 200 && json['success'] == true) {
        final allItems = (json['all_detected_items'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];

        if (allItems.isNotEmpty) {
          _cart.applyAllVoiceOrders(allItems);
        } else {
          _cart.applyVoiceOrder(
            detectedName: json['detected_item'] as String? ?? '',
            quantity: json['quantity'] as int? ?? 1,
          );
        }

        final transcript = json['raw_transcript'] as String? ?? '';
        _state = RecordingState.success;
        _statusMessage = '"$transcript"';
      } else {
        _setError(
          json['message'] as String? ?? 'Backend returned an error.',
          keepLog: true,
        );
      }
    } on SocketException {
      _setError(
        'Cannot reach backend.\nMake sure:\n1. Backend server is running\n2. Phone & laptop on same WiFi\n3. kBackendBaseUrl has correct IP',
      );
    } catch (e) {
      _setError('Error: $e');
    }

    notifyListeners();

    await Future.delayed(const Duration(seconds: 3));
    if (_state != RecordingState.recording) {
      _state = RecordingState.idle;
      _statusMessage = 'Tap mic to order in Hindi';
      notifyListeners();
    }
  }

  void _setError(String message, {bool keepLog = false}) {
    _state = RecordingState.error;
    _errorMessage = message;
    _statusMessage = 'Error — see below';
    if (!keepLog) {
      _cart.addLog({
        'timestamp': DateTime.now().toIso8601String(),
        'error': message,
      });
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }
}