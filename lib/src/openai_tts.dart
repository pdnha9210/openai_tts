import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;

/// Enumeration of available OpenAI TTS voices.
enum OpenaiTTSVoice {
  alloy,
  ash,
  ballad,
  coral,
  echo,
  fable,
  onyx,
  nova,
  sage,
  shimmer,
  verse,
}

/// Enumeration of OpenAI TTS models.
enum OpenaiTTSModel {
  tts1('tts-1'),
  tts1hd('tts-1-hd');

  const OpenaiTTSModel(this.value);
  final String value;
}

/// Represents the current status of TTS playback.
enum OpenaiTTSStatus {
  fetching,
  playing,
  stopped,
  completed,
}

/// A client for OpenAI's Text-to-Speech API.
/// Supports both real-time PCM streaming playback and full MP3 playback.
class OpenaiTTS {
  OpenaiTTS({required this.apiKey});

  final String apiKey;

  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  // Configuration for PCM streaming
  final int _bufferSize = 2048;
  final int _sampleRate = 24000;
  final int _numChannels = 1;
  final Codec _pcmCodec = Codec.pcm16;
  final Codec _mp3Codec = Codec.mp3;

  bool _isCancelled = false;

  // Buffers to temporarily store streamed audio data
  final List<int> _pcmBuffer = [];
  final List<int> _audioBuffer = [];

  Timer? _bufferPumpTimer;

  // Stream to emit status updates (fetching, playing, stopped, etc.)
  final _statusController = StreamController<OpenaiTTSStatus>.broadcast();
  Stream<OpenaiTTSStatus> get ttsStatusStream => _statusController.stream;

  Timer? _timer;

  /// Streams and plays audio from OpenAI's TTS API using real-time PCM streaming.
  Future<void> streamSpeak(
    String text, {
    OpenaiTTSVoice voice = OpenaiTTSVoice.alloy,
    OpenaiTTSModel model = OpenaiTTSModel.tts1,
    String? instructions,
    void Function(Uint8List chunk)? onData,
  }) async {
    _isCancelled = false;
    _pcmBuffer.clear();

    final url = Uri.parse("https://api.openai.com/v1/audio/speech");
    final body = {
      "model": model.value,
      "input": text,
      "voice": voice.name,
      "response_format": "pcm", // PCM format for real-time playback
    };
    if (instructions != null) {
      body["instructions"] = instructions;
    }

    // Build the HTTP POST request
    final request = http.Request("POST", url)
      ..headers.addAll({
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      })
      ..body = jsonEncode(body);

    _statusController.add(OpenaiTTSStatus.fetching);
    final response = await request.send();

    // Check for errors in the response
    if (response.statusCode != 200) {
      final error = await response.stream.bytesToString();
      throw Exception("TTS Stream Error ${response.statusCode}: $error");
    }

    // Open player if not already open
    if (!_player.isOpen()) {
      await _player.openPlayer();
    }

    // Start the player with a stream-based PCM source
    await _player.startPlayerFromStream(
      codec: _pcmCodec,
      sampleRate: _sampleRate,
      numChannels: _numChannels,
      interleaved: true,
      bufferSize: _bufferSize,
    );

    _statusController.add(OpenaiTTSStatus.playing);
    _startBufferPump(); // Start pushing PCM chunks from buffer

    final DateTime startTime = DateTime.now();

    try {
      // Stream audio data in chunks from the response
      await for (final chunk in response.stream) {
        if (_isCancelled) break;

        _audioBuffer.addAll(chunk);
        _pcmBuffer.addAll(chunk);

        // Optional callback for real-time chunk data
        onData?.call(Uint8List.fromList(chunk));
      }

      // After stream ends, flush remaining buffer
      if (_pcmBuffer.isNotEmpty) {
        final flushLen = _pcmBuffer.length - (_pcmBuffer.length % 2);
        if (flushLen > 0) {
          _player.uint8ListSink?.add(
            Uint8List.fromList(_pcmBuffer.sublist(0, flushLen)),
          );
        }
      }
    } catch (e) {
      // Handle unexpected errors during streaming playback
      await stopPlayer();
      throw Exception("TTS Stream Playback Error: $e");
    } finally {
      _stopBufferPump();

      // Estimate how much time remains and notify completion accordingly
      final duration = _audioBuffer.length / (_sampleRate * _numChannels * 2);
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final remainingMs =
          ((duration * 1000).toInt() - elapsed).clamp(0, 1 << 31);
      if (remainingMs > 0) {
        _timer = Timer(Duration(milliseconds: remainingMs), () {
          if (!_isCancelled) {
            _statusController.add(OpenaiTTSStatus.completed);
          }
        });
      } else {
        _statusController.add(OpenaiTTSStatus.completed);
      }
    }
  }

  /// Downloads and plays a full MP3 file response from OpenAI's TTS API.
  Future<void> createSpeak(
    String text, {
    OpenaiTTSVoice voice = OpenaiTTSVoice.alloy,
    OpenaiTTSModel model = OpenaiTTSModel.tts1,
    String? instructions,
    void Function(Uint8List chunk)? onData,
  }) async {
    final url = Uri.parse("https://api.openai.com/v1/audio/speech");
    final body = {
      "model": model.value,
      "input": text,
      "voice": voice.name,
      "response_format": "mp3", // Full MP3 file format
    };
    if (instructions != null) {
      body["instructions"] = instructions;
    }

    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception("TTS MP3 Error ${response.statusCode}: ${response.body}");
    }

    final audioBytes = response.bodyBytes;

    onData?.call(audioBytes); // Optional callback with full MP3 data

    await _playMp3(audioBytes);
  }

  /// Plays back an MP3 file from memory.
  Future<void> _playMp3(Uint8List data) async {
    if (!_player.isOpen()) {
      await _player.openPlayer();
    }

    await _player.startPlayer(
      fromDataBuffer: data,
      codec: _mp3Codec,
    );

    _statusController.add(OpenaiTTSStatus.playing);
  }

  /// Stops playback and clears state.
  Future<void> stopPlayer() async {
    _statusController.add(OpenaiTTSStatus.stopped);
    _isCancelled = true;
    _pcmBuffer.clear();
    _stopBufferPump();
    await _player.stopPlayer();
    await _player.closePlayer();
  }

  /// Starts a periodic timer to send buffered PCM chunks to the audio player.
  void _startBufferPump() {
    _bufferPumpTimer =
        Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (_pcmBuffer.length >= _bufferSize) {
        final subChunk = Uint8List.fromList(_pcmBuffer.sublist(0, _bufferSize));
        _player.uint8ListSink?.add(subChunk);
        _pcmBuffer.removeRange(0, _bufferSize);
      }
    });
  }

  /// Stops the buffer pump timer.
  void _stopBufferPump() {
    _bufferPumpTimer?.cancel();
    _bufferPumpTimer = null;
  }

  /// Disposes all resources and cancels timers.
  void dispose() {
    _player.closePlayer();
    _statusController.close();
    _timer?.cancel();
    _stopBufferPump();
  }
}
