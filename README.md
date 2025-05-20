# openai_tts

[![pub package](https://img.shields.io/pub/v/openai_tts.svg)](https://pub.dev/packages/openai_tts)

A Flutter package for streaming and playing OpenAI Text-to-Speech (TTS) audio with real-time PCM playback or full MP3 playback support using `flutter_sound`.  
Supports various voices and models from OpenAI's TTS API.

---

## Features

- Stream TTS audio directly from OpenAI API with low-latency PCM playback.
- Download and play full MP3 audio response.
- Multiple voices and models supported.
- Playback status streaming to track progress.
- Optional callbacks for real-time audio chunk handling.
- Easy to use Flutter API built on top of `flutter_sound`.

---

## Getting Started

### Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  openai_tts: ^1.0.0
  flutter_sound: ^9.2.13 # Ensure compatibility with flutter_sound version you want
  http: ^0.13.0
```

Run:

```bash
flutter pub get
```

### Usage

Import the package:

```dart
import 'package:openai_tts/openai_tts.dart';
```

Initialize the TTS client:

```dart
final tts = OpenaiTTS(apiKey: 'YOUR_OPENAI_API_KEY');
```

#### Stream and play TTS audio (PCM streaming):

```dart
await tts.streamSpeak(
  "Hello from OpenAI TTS!",
  voice: OpenaiTTSVoice.alloy,
  model: OpenaiTTSModel.tts1,
  onData: (chunk) {
    // Optional: handle raw PCM chunk bytes for visualization or custom processing
  },
);
```

#### Download and play full MP3 audio:

```dart
await tts.createSpeak(
  "Hello from OpenAI TTS!",
  voice: OpenaiTTSVoice.nova,
  model: OpenaiTTSModel.tts1hd,
  onData: (bytes) {
    // Optional: do something with full MP3 bytes (e.g. save to file)
  },
);
```

#### Listen to playback status changes:

```dart
tts.ttsStatusStream.listen((status) {
  switch (status) {
    case OpenaiTTSStatus.fetching:
      print('Fetching audio...');
      break;
    case OpenaiTTSStatus.playing:
      print('Playing audio...');
      break;
    case OpenaiTTSStatus.stopped:
      print('Playback stopped.');
      break;
    case OpenaiTTSStatus.completed:
      print('Playback completed.');
      break;
  }
});
```

#### Stop playback manually:

```dart
await tts.stopPlayer();
```

---

## API Reference

### Class: `OpenaiTTS`

- `OpenaiTTS({required String apiKey})`  
  Creates a new TTS client with the given OpenAI API key.

- `Future<void> streamSpeak(String text, {OpenaiTTSVoice voice, OpenaiTTSModel model, String? instructions, void Function(Uint8List chunk)? onData})`  
  Streams TTS audio using real-time PCM playback.

- `Future<void> createSpeak(String text, {OpenaiTTSVoice voice, OpenaiTTSModel model, String? instructions, void Function(Uint8List chunk)? onData})`  
  Downloads and plays full MP3 audio.

- `Stream<OpenaiTTSStatus> get ttsStatusStream`  
  Stream emitting playback status updates.

- `Future<void> stopPlayer()`  
  Stops current playback.

- `void dispose()`  
  Releases resources.

### Enums

- `OpenaiTTSVoice` — Available TTS voices like `alloy`, `nova`, `shimmer`, etc.
- `OpenaiTTSModel` — Available models: `tts1`, `tts1hd`.
- `OpenaiTTSStatus` — Playback states: `fetching`, `playing`, `stopped`, `completed`.

---

## Example

```dart
void main() async {
  final tts = OpenaiTTS(apiKey: 'YOUR_OPENAI_API_KEY');

  tts.ttsStatusStream.listen((status) {
    print('Status: $status');
  });

  try {
    await tts.streamSpeak(
      "Hello, this is a streaming test!",
      voice: OpenaiTTSVoice.onyx,
    );
  } catch (e) {
    print('Error: $e');
  }
}
```

---

## Troubleshooting

- Ensure your OpenAI API key is valid and has TTS access.
- This package depends on `flutter_sound` — check platform setup instructions for iOS/Android.
- Network connectivity is required for streaming or downloading audio.

---

## License

Copyright 2025 © PdNha  
[BDS 3 License](https://opensource.org/license/BSD-3-Clause)
