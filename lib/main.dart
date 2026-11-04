import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const Tx800App());
}

class Tx800App extends StatelessWidget {
  const Tx800App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tx 800 Mini',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF040a10),
      ),
      home: const TxInterface(),
    );
  }
}

class TxInterface extends StatefulWidget {
  const TxInterface({super.key});

  @override
  State<TxInterface> createState() => _TxInterfaceState();
}

class _TxInterfaceState extends State<TxInterface> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool isRecording = false;
  String statusText = "TAP TO START";
  String botReply = "SYSTEM READY";

  // আপনার Vercel API লিংক
  final String apiUrl = "https://tx800-backend.vercel.app/api";

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initTts();
  }

  // পারমিশন চাওয়া
  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  // বাংলা TTS সেটআপ
  Future<void> _initTts() async {
    await _flutterTts.setLanguage("bn-BD");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  // মাইক অন/অফ এবং সার্ভারে পাঠানো
  Future<void> _toggleRecording() async {
    if (await _audioRecorder.hasPermission()) {
      if (!isRecording) {
        try {
          final Directory tempDir = await getTemporaryDirectory();
          final String filePath = '${tempDir.path}/tx_input.m4a';

          await _audioRecorder.start(const RecordConfig(), path: filePath);
          
          setState(() {
            isRecording = true;
            statusText = "LISTENING...";
            botReply = "Tx is listening to you...";
          });

          // ৫ সেকেন্ড পর অটো স্টপ
          await Future.delayed(const Duration(seconds: 5));
          if (isRecording) await _stopAndSend();
        } catch (e) {
          setState(() {
            botReply = "রেকর্ডিং এরর: $e";
            statusText = "ERROR";
          });
        }
      }
    }
  }

  Future<void> _stopAndSend() async {
    final path = await _audioRecorder.stop();
    setState(() {
      isRecording = false;
      statusText = "PROCESSING...";
    });

    if (path != null) {
      File file = File(path);
      if (await file.exists()) {
        List<int> bytes = await file.readAsBytes();
        String base64Audio = base64Encode(bytes);

        try {
          final response = await http.post(
            Uri.parse(apiUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"user_id": "android_user", "audio": base64Audio}),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            setState(() {
              botReply = data['reply'];
              statusText = "TAP TO TALK";
            });
            // TTS দিয়ে ভয়েস প্লে করা
            await _flutterTts.speak(data['reply']);
          } else {
            setState(() {
              botReply = "সার্ভার এরর: ${response.statusCode}";
              statusText = "ERROR";
            });
          }
        } catch (e) {
          setState(() {
            botReply = "নেটওয়ার্ক সমস্যা: $e";
            statusText = "ERROR";
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // টপ বার
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBadge("HEARING", Colors.cyanAccent),
                  _buildBadge("BG: ACTIVE", Colors.greenAccent),
                  _buildBadge("FACE LOCK", Colors.blueAccent),
                ],
              ),
            ),
            
            // মেইন মাইক স্ক্রিন
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _toggleRecording,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: isRecording ? Colors.greenAccent : Colors.cyanAccent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: isRecording ? Colors.greenAccent.withOpacity(0.5) : Colors.cyanAccent.withOpacity(0.5),
                          blurRadius: 40,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isRecording ? Icons.mic : Icons.mic_none, 
                        size: 80, 
                        color: isRecording ? Colors.greenAccent : Colors.cyanAccent
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // স্ট্যাটাস টেক্সট
            Text(
              statusText,
              style: TextStyle(
                color: isRecording ? Colors.greenAccent : Colors.cyanAccent,
                letterSpacing: 4,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),

            // রেসপন্স বক্স
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0A151E),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("RESPONSE SYNTHESIS", style: TextStyle(color: Colors.cyanAccent, fontSize: 10, letterSpacing: 1)),
                      Text("UPLINK: OK", style: TextStyle(color: Colors.cyanAccent.withOpacity(0.5), fontSize: 10)),
                    ],
                  ),
                  const Divider(color: Colors.cyanAccent),
                  Text(
                    botReply,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // ভলিউম স্লাইডার (ডেমো)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.volume_up, color: Colors.cyanAccent),
                  Expanded(
                    child: Slider(
                      value: 1.0,
                      onChanged: (val) {},
                      activeColor: Colors.cyanAccent,
                      inactiveColor: Colors.cyanAccent.withOpacity(0.2),
                    ),
                  ),
                  const Text("100%", style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 3, backgroundColor: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontSize: 10, letterSpacing: 1)),
        ],
      ),
    );
  }
}
