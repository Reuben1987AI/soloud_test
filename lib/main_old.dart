import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MaterialApp(home: SoLoudPositionTest()));
}

class SoLoudPositionTest extends StatefulWidget {
  const SoLoudPositionTest({super.key});

  @override
  State<SoLoudPositionTest> createState() => _SoLoudPositionTestState();
}

class _SoLoudPositionTestState extends State<SoLoudPositionTest> {
  late SoLoud soloud;
  List<String> logs = [];
  bool isRunning = false;

  @override
  void initState() {
    super.initState();
    soloud = SoLoud.instance;
    initSoLoud();
  }

  Future<void> initSoLoud() async {
    try {
      await soloud.init(sampleRate: 16000, bufferSize: 1024, channels: Channels.mono);
      addLog('SoLoud initialized successfully');
    } catch (e) {
      addLog('Failed to initialize SoLoud: $e');
    }
  }

  void addLog(String message) {
    setState(() {
      logs.add('[${DateTime.now().toString().split('.')[0]}] $message');
      // Keep only last 20 logs
      if (logs.length > 20) {
        logs.removeAt(0);
      }
    });
    debugPrint(message);
  }

  Future<void> runPositionTest() async {
    if (isRunning) return;

    setState(() {
      isRunning = true;
      logs.clear();
    });

    try {
      addLog('Creating buffer stream...');

      // Create buffer stream
      final streamSource = soloud.setBufferStream(
        maxBufferSizeBytes: 1024 * 1024 * 2, // 2MB
        bufferingType: BufferingType.preserved,
        bufferingTimeNeeds: 0.5,
        sampleRate: 16000,
        channels: Channels.mono,
        format: BufferType.s16le,
      );

      addLog('Starting playback...');

      // Start playback
      final handle = await soloud.play(streamSource);

      // Generate and feed white noise
      final random = Random();
      const chunkDurationMs = 100;
      const samplesPerChunk = 16000 * chunkDurationMs ~/ 1000;
      const bytesPerChunk = samplesPerChunk * 2;

      // Position tracking
      final positionHistory = <Duration>[];
      Timer? positionTimer;

      // Track position manually
      int totalBytesStreamed = 0;
      final startTime = DateTime.now();

      // Start position monitoring
      int positionCheckCount = 0;
      positionTimer = Timer.periodic(Duration(milliseconds: 100), (timer) async {
        try {
          final position = soloud.getPosition(handle);
          positionHistory.add(position);
          positionCheckCount++;

          // Calculate manual position based on bytes streamed
          // final manualPositionMs = (totalBytesStreamed / 2 / 16000 * 1000).round();
          final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;

          final pause = soloud.getPause(handle);

          // Log every 5th position check
          if (positionCheckCount % 5 == 0) {
            addLog('SoLoud pos: ${position.inMilliseconds}ms | Pause: $pause | Elapsed: ${elapsedMs}ms');
          }

          // Also check buffer size and if sound is still playing
          final bufferSize = soloud.getBufferSize(streamSource);
          final isPlaying = soloud.getIsValidVoiceHandle(handle);
          if (positionCheckCount % 5 == 0) {
            addLog('Buffer: $bufferSize bytes | Playing: $isPlaying');
          }
        } catch (e) {
          addLog('Error getting position: $e');
        }
      });

      // Feed audio chunks
      for (int i = 0; i < 20; i++) {
        // Generate white noise chunk
        final chunk = Uint8List(bytesPerChunk);
        for (int j = 0; j < chunk.length; j += 2) {
          final sample = (random.nextDouble() * 65536 - 32768).toInt();
          chunk[j] = sample & 0xFF;
          chunk[j + 1] = (sample >> 8) & 0xFF;
        }

        // Add chunk to stream
        soloud.addAudioDataStream(streamSource, chunk);
        totalBytesStreamed += chunk.length;

        if (i % 5 == 0) {
          addLog('Added chunk ${i + 1}/20 (Total: $totalBytesStreamed bytes)');
        }

        await Future.delayed(Duration(milliseconds: chunkDurationMs));
      }

      // Signal that streaming is complete
      addLog('Calling setDataIsEnded()...');
      soloud.setDataIsEnded(streamSource);

      // Wait a bit more
      await Future.delayed(Duration(seconds: 2));

      // Stop monitoring
      positionTimer.cancel();

      // Analyze results
      addLog('=== Analysis ===');
      final nonZeroPositions = positionHistory.where((p) => p > Duration.zero).toList();
      addLog('Total readings: ${positionHistory.length}');
      addLog('Non-zero positions: ${nonZeroPositions.length}');

      if (nonZeroPositions.isEmpty) {
        addLog('⚠️ All positions were zero!');
      } else {
        final maxPosition = positionHistory.fold<Duration>(Duration.zero, (max, p) => p > max ? p : max);
        addLog('✅ Max position: ${maxPosition.inMilliseconds}ms');
      }

      // Clean up
      await soloud.stop(handle);
      await soloud.disposeSource(streamSource);
    } catch (e) {
      addLog('Test error: $e');
    } finally {
      setState(() {
        isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('SoLoud Position Test')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: isRunning ? null : runPositionTest,
              child: Text(isRunning ? 'Running...' : 'Run Position Test'),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black12,
              child: ListView.builder(
                padding: EdgeInsets.all(8),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  return Text(logs[index], style: TextStyle(fontFamily: 'monospace', fontSize: 12));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    soloud.deinit();
    super.dispose();
  }
}

