import 'package:flutter/material.dart';
import 'package:openai_tts/openai_tts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  OpenaiTTS openaiTTS = OpenaiTTS(apiKey: 'YOUR_API_KEY');

  TextEditingController textController = TextEditingController();

  bool isPlaying = false;
  bool isFetched = false;

  @override
  void initState() {
    super.initState();
    openaiTTS.ttsStatusStream.listen((status) {
      switch (status) {
        case OpenaiTTSStatus.fetching:
          isFetched = true;
          break;
        case OpenaiTTSStatus.playing:
          setState(() {
            isPlaying = true;
          });
        case OpenaiTTSStatus.stopped:
          setState(() {
            isPlaying = false;
          });
        case OpenaiTTSStatus.completed:
          setState(() {
            isPlaying = false;
          });
      }
    });
  }

  Future<void> _speak() async {
    try {
      isFetched = false;
      await openaiTTS.speak(textController.text);
    } catch (e) {
      throw Exception('Error while speaking: $e');
    }
  }

  @override
  void dispose() {
    openaiTTS.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter your text',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _speak();
                  },
                  child: Text(
                    isPlaying ? 'Pause' : 'Speak',
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    if (isPlaying) {
                      openaiTTS.stopPlayer();
                    }
                  },
                  child: const Text('Stop'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
