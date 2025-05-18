# openai_tts

A lightweight Flutter package that integrates with OpenAI's Text-to-Speech API. Supports both real-time streaming (via PCM) and downloadable audio (MP3), powered by OpenAI's latest voice models.

> 🎙️ Generate lifelike speech with minimal latency and stream it directly in your app.

## Features

- 🔊 Text-to-speech using OpenAI’s `tts-1` and `tts-1-hd` models
- 🎵 Supports both `mp3` and real-time `pcm` audio streaming
- 🚀 Built-in streaming playback via `flutter_sound`
- 🔁 Control over playback (pause, resume, stop)
- 🎭 Supports multiple realistic voices

---

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  openai_tts: ^<latest_version>
```

Then run:

```sh
flutter pub get
```

---

## Getting Started

Import the package:

```dart
import 'package:openai_tts/openai_tts.dart';
```

Create an instance:

```dart
final tts = OpenaiTTS(apiKey: 'sk-...'); // Use your OpenAI API key
```

### 1. Download and use MP3:

```dart
final audioData = await tts.createSpeak("Hello, world!");
// Save or play using your preferred audio player
```

### 2. Stream audio in real time:

```dart
await tts.streamSpeak("Streaming this sentence in real-time.");
```

### 3. Control playback:

```dart
await tts.pausePlayer();
await tts.resumePlayer();
await tts.stopPlayer();
```

---

## Configuration

### Change Voice:

```dart
tts.setVoice = OpenaiTTSVoice.shimmer;
```

Available voices:

- alloy
- echo
- fable
- onyx
- nova
- shimmer
- ash
- ballad
- coral
- verse
- sage

### Change Model:

```dart
tts.setModel = OpenaiTTSModel.tts1hd;
```

Models:

- `tts-1`
- `tts-1-hd`

---

## Requirements

- Flutter 3.10 or newer
- Valid OpenAI API key with TTS access
- Internet connection

---

## Example

Full example:

```dart
void main() async {
  final tts = OpenaiTTS(apiKey: 'sk-your-api-key');
  tts.setVoice = OpenaiTTSVoice.nova;
  tts.setModel = OpenaiTTSModel.tts1;

  await tts.streamSpeak("Welcome to OpenAI TTS with Flutter.");
}
```

---

## Troubleshooting

- Make sure your OpenAI API key is valid and has TTS access.
- Streaming works best on physical devices with low audio latency.
- Use the `createSpeak` method if you experience issues with real-time playback.

---

## License

MIT License © 2025 [Your Name or Organization]

---
