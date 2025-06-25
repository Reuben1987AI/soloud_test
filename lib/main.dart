import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

void main() {
  runApp(const MaterialApp(home: HandleEventTest()));
}

class HandleEventTest extends StatefulWidget {
  const HandleEventTest({super.key});

  @override
  State<HandleEventTest> createState() => _HandleEventTestState();
}

class _HandleEventTestState extends State<HandleEventTest> {
  late SoLoud soloud;
  SoundHandle? _handle;
  AudioSource? _source;
  final List<String> _logs = [];
  StreamSubscription? _eventSubscription;
  Timer? _positionTimer;

  @override
  void initState() {
    super.initState();
    soloud = SoLoud.instance;
    _initSoLoud();
  }

  Future<void> _initSoLoud() async {
    try {
      await soloud.init();
      _log('SoLoud initialized');
    } catch (e) {
      _log('Failed to initialize: $e');
    }
  }

  void _log(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().split('.')[0]}] $message');
      if (_logs.length > 15) _logs.removeAt(0);
    });
  }

  void _onVoicePlaybackFinished() {
    _log('✅ handleIsNoMoreValid event received!');
    _log('Voice playback finished callback executed');
  }

  Uint8List _createWavFile(double duration, int sampleRate) {
    final samples = (sampleRate * duration).toInt();
    final dataSize = samples * 2; // 16-bit mono
    final fileSize = 44 + dataSize - 8;
    
    final buffer = Uint8List(44 + dataSize);
    final data = ByteData.sublistView(buffer);
    
    // WAV header
    buffer.setRange(0, 4, 'RIFF'.codeUnits);
    data.setUint32(4, fileSize, Endian.little);
    buffer.setRange(8, 12, 'WAVE'.codeUnits);
    buffer.setRange(12, 16, 'fmt '.codeUnits);
    data.setUint32(16, 16, Endian.little); // fmt chunk size
    data.setUint16(20, 1, Endian.little); // PCM format
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    data.setUint16(32, 2, Endian.little); // block align
    data.setUint16(34, 16, Endian.little); // bits per sample
    buffer.setRange(36, 40, 'data'.codeUnits);
    data.setUint32(40, dataSize, Endian.little);
    
    // Generate audio data (fade in)
    for (int i = 0; i < samples; i++) {
      final value = (32767 * 0.3 * (i / samples)).toInt();
      data.setInt16(44 + i * 2, value, Endian.little);
    }
    
    return buffer;
  }

  Future<void> _testShortSound() async {
    _log('--- Testing with short sound ---');
    
    try {
      // Create a very short sound (0.5 seconds)
      final buffer = _createWavFile(0.5, 44100);
      
      _source = await soloud.loadMem('short_test.wav', buffer);
      _log('Sound loaded');
      
      // Listen for events
      _eventSubscription?.cancel();
      _eventSubscription = _source!.soundEvents.listen((eventData) {
        _log('Event received: ${eventData.event}');
        if (eventData.handle == _handle && eventData.event == SoundEventType.handleIsNoMoreValid) {
          _onVoicePlaybackFinished();
        }
      });
      
      _handle = await soloud.play(_source!);
      _log('Sound playing with handle: $_handle');
      
    } catch (e) {
      _log('Error: $e');
    }
  }


  Future<void> _testStreamingSound() async {
    _log('--- Testing streaming with unknown length ---');
    
    AudioSource? streamSource;
    
    try {
      // Create stream as per your configuration
      streamSource = await soloud.setBufferStream(
        maxBufferSizeBytes: 1024 * 1024 * 40, // 40MB
        bufferingType: BufferingType.preserved,
        bufferingTimeNeeds: 0.5,
        sampleRate: 16000,
        channels: Channels.mono,
        format: BufferType.s16le, // 16-bit signed little-endian
      );
      _log('Stream source created');
      
      // Listen for events
      _eventSubscription?.cancel();
      _eventSubscription = streamSource.soundEvents.listen((eventData) {
        _log('Event received: ${eventData.event}');
        if (eventData.handle == _handle && eventData.event == SoundEventType.handleIsNoMoreValid) {
          _onVoicePlaybackFinished();
        }
      });
      
      // Start playback BEFORE generating data
      _handle = await soloud.play(streamSource);
      _log('Playback started with handle: $_handle');
      
      // Start position logging timer
      _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        if (_handle != null) {
          try {
            final position = soloud.getPosition(_handle!);
            _log('Position: ${position.inMilliseconds / 1000.0}s');
          } catch (e) {
            _log('Position error: $e');
          }
        }
      });
      
      // Generate and stream data in chunks
      const chunkDurationMs = 500; // 500ms chunks
      const sampleRate = 16000;
      const samplesPerChunk = sampleRate * chunkDurationMs ~/ 1000;
      const bytesPerChunk = samplesPerChunk * 2; // 16-bit = 2 bytes
      const totalChunks = 20; // 10 seconds total
      
      for (int i = 0; i < totalChunks; i++) {
        // Generate audio chunk (simple tone)
        final chunk = Uint8List(bytesPerChunk);
        final frequency = 440.0 + (i * 20); // Varying frequency
        
        for (int j = 0; j < samplesPerChunk; j++) {
          final t = j / sampleRate;
          final value = (32767 * 0.3 * sin(2 * pi * frequency * t)).toInt();
          chunk[j * 2] = value & 0xFF;
          chunk[j * 2 + 1] = (value >> 8) & 0xFF;
        }
        
        // Add chunk to stream
        soloud.addAudioDataStream(streamSource, chunk);
        
        if (i % 4 == 0) {
          _log('Streamed chunk ${i + 1}/$totalChunks (${(i + 1) * 0.5}s)');
        }
        
        // Simulate real-time streaming
        await Future.delayed(Duration(milliseconds: chunkDurationMs));
      }
      
      // Signal end of stream
      _log('Calling setDataIsEnded()...');
      soloud.setDataIsEnded(streamSource);
      
      // Wait for playback to finish
      _log('Waiting for handleIsNoMoreValid event...');
      await Future.delayed(const Duration(seconds: 3));
      
      // Stop position timer
      _positionTimer?.cancel();
      _positionTimer = null;
      
      // Cleanup stream source
      if (streamSource != null) {
        await soloud.disposeSource(streamSource);
      }
      
    } catch (e) {
      _log('Error: $e');
      _positionTimer?.cancel();
      _positionTimer = null;
      if (streamSource != null) {
        await soloud.disposeSource(streamSource);
      }
    }
  }

  Future<void> _cleanup() async {
    _eventSubscription?.cancel();
    _positionTimer?.cancel();
    _positionTimer = null;
    if (_source != null) {
      await soloud.disposeSource(_source!);
      _source = null;
    }
    _handle = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Handle Event Test')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await _cleanup();
                    await _testShortSound();
                  },
                  child: const Text('Test Short Sound (0.5s)'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    await _cleanup();
                    await _testStreamingSound();
                  },
                  child: const Text('Test Streaming (10s)'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _cleanup,
                  child: const Text('Cleanup'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black12,
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  final isSuccess = log.contains('✅');
                  return Text(
                    log,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isSuccess ? Colors.green : null,
                      fontWeight: isSuccess ? FontWeight.bold : null,
                    ),
                  );
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
    _cleanup();
    soloud.deinit();
    super.dispose();
  }
}
