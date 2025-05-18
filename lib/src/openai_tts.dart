import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_sound/flutter_sound.dart';

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

enum OpenaiTTSModel {
  tts1('tts-1'),
  tts1hd('tts-1-hd');

  const OpenaiTTSModel(this.value);
  final String value;
}

/// A client for OpenAI's text-to-speech API with support for both
/// downloading audio and real-time streaming via PCM.
///
/// Requires a valid OpenAI API key and internet access.
///
/// Usage:
/// ```dart
/// final tts = OpenaiTTS(apiKey: 'sk-...');
/// await tts.streamSpeak("Hello world!");
/// final mp3Data = await tts.createSpeak("Download this.");
/// ```
class OpenaiTTS {
  OpenaiTTS({
    required this.apiKey,
  });

  /// Your OpenAI API key (e.g. starts with `sk-` or `sk-proj-`).
  final String apiKey;

  /// The voice to use for TTS output.
  ///
  /// Valid values include: `alloy`, `echo`, `fable`, `onyx`, `nova`, `shimmer`.
  OpenaiTTSVoice _voice = OpenaiTTSVoice.alloy;

  /// The model to use. Options: `tts-1` or `tts-1-hd`.
  OpenaiTTSModel _model = OpenaiTTSModel.tts1;

  set setVoice(OpenaiTTSVoice voice) {
    _voice = voice;
  }

  set setModel(OpenaiTTSModel model) {
    _model = model;
  }

  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  /// The buffer size for audio streaming.
  final int _bufferSize = 2048;

  /// The sample rate for audio streaming.
  /// Defaults to 24000Hz for PCM audio.
  final int _sampleRate = 24000;

  /// The number of channels for audio streaming.
  /// Defaults to 1 (mono).
  /// OpenAI TTS currently supports only mono audio.
  final int _numChannels = 1;

  /// Creates an instance of [OpenaiTTS].
  ///
  /// [apiKey] is required. Optional [voice] and [model] default to
  /// `"shimmer"` and `"tts-1"` respectively.

  /// Converts [text] to MP3 audio and returns it as a [Uint8List].
  ///
  /// This is a non-streaming method; the entire audio is generated
  /// server-side and downloaded as a single binary blob.
  ///
  /// Can be saved as `.mp3` or played via an audio player package.
  ///
  /// Throws an [Exception] if the request fails.
  Future<Uint8List> createSpeak(String text) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/audio/speech'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model.value,
        'input': text,
        'voice': _voice.toString(),
        'response_format': 'mp3',
      }),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception(
        'TTS API Error ${response.statusCode}: ${response.body}',
      );
    }
  }

  /// Streams PCM audio from OpenAI TTS and plays it directly using [flutter_sound].
  ///
  /// The playback begins as soon as audio data starts arriving, allowing
  /// for near real-time speech synthesis.
  ///
  /// This uses 16-bit PCM with 24000Hz sample rate and 1 channel (mono).
  ///
  /// Throws an [Exception] if the stream fails to load or decode.
  Future<void> streamSpeak(String text) async {
    final url = Uri.parse("https://api.openai.com/v1/audio/speech");

    final request = http.Request("POST", url)
      ..headers.addAll({
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      })
      ..body = jsonEncode({
        "model": _model.value,
        "input": text,
        "voice": _voice.toString(),
        "response_format": "pcm",
      });

    final response = await request.send();

    if (response.statusCode != 200) {
      final error = await response.stream.bytesToString();
      throw Exception("TTS Stream Error ${response.statusCode}: $error");
    }

    await _player.openPlayer();
    await _player.setSubscriptionDuration(const Duration(milliseconds: 100));

    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      sampleRate: _sampleRate,
      numChannels: _numChannels,
      interleaved: true,
      bufferSize: _bufferSize,
    );

    final List<int> pcmBuffer = [];
    try {
      await for (final chunk in response.stream) {
        pcmBuffer.addAll(chunk);
        while (pcmBuffer.length >= _bufferSize) {
          _player.uint8ListSink!
              .add(Uint8List.fromList(pcmBuffer.sublist(0, _bufferSize)));
          pcmBuffer.removeRange(0, _bufferSize);
        }
      }

      // Final flush
      if (pcmBuffer.isNotEmpty) {
        final remainder = pcmBuffer.length - (pcmBuffer.length % 2);
        if (remainder > 0) {
          _player.uint8ListSink!.add(Uint8List.fromList(
            pcmBuffer.sublist(0, remainder),
          ));
        }
      }
    } catch (e) {
      await _player.stopPlayer();
      await _player.closePlayer();
      throw Exception("TTS Stream Playback Error: $e");
    } finally {
      await _player.stopPlayer();
      await _player.closePlayer();
    }
  }

  Future<void> stopPlayer() {
    _player.closePlayer();
    return _player.stopPlayer();
  }

  Future<void> pausePlayer() {
    return _player.pausePlayer();
  }

  Future<void> resumePlayer() {
    return _player.resumePlayer();
  }

  /// Disposes the internal audio player.
  ///
  /// Call this when the instance is no longer needed to free up resources.
  void dispose() {
    _player.closePlayer();
  }
}
