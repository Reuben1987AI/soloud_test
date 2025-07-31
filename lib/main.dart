import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

void main() {
  runApp(const MaterialApp(home: PositionTestApp()));
}

class PositionTestApp extends StatefulWidget {
  const PositionTestApp({super.key});

  @override
  State<PositionTestApp> createState() => _PositionTestAppState();
}

class _PositionTestAppState extends State<PositionTestApp> {
  late SoLoud soloud;
  SoundHandle? _handle;
  AudioSource? _streamSource;

  final List<TimingResult> _timingResults = [];
  Timer? _startDetectionTimer;
  Timer? _positionTimer;
  int _playbackStartMicros = 0;
  bool _hasStarted = false;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    soloud = SoLoud.instance;
    _initSoLoud();
  }

  Future<void> _initSoLoud() async {
    try {
      await soloud.init();
      setState(() {});
    } catch (e) {
      print('Failed to initialize SoLoud: $e');
      rethrow;
    }
  }

  Future<void> _startPositionTest() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _hasStarted = false;
      _timingResults.clear();
      _playbackStartMicros = 0;
    });

    try {
      // Create streaming audio source
      _streamSource = await soloud.setBufferStream(
        maxBufferSizeBytes: 1024 * 1024 * 10,
        bufferingType: BufferingType.preserved,
        bufferingTimeNeeds: 0.5,
        sampleRate: 16000,
        channels: Channels.mono,
        format: BufferType.s16le,
      );

      // Start playback immediately
      _handle = await soloud.play(_streamSource!);

      // Start 2ms timer to detect when playback begins
      _startDetectionTimer = Timer.periodic(Duration(milliseconds: 2), (timer) async {
        if (_handle == null) {
          timer.cancel();
          return;
        }

        final position = soloud.getPosition(_handle!);

        if (!_hasStarted && position > Duration.zero) {
          _hasStarted = true;
          _playbackStartMicros = DateTime.now().microsecondsSinceEpoch;
          _onPlaybackStarted();
          timer.cancel();
        }
      });

      // Start generating and streaming audio data
      _generateAudioStream();
    } catch (e) {
      setState(() {
        _isRunning = false;
      });
      print('Error starting test: $e');
    }
  }

  void _onPlaybackStarted() {
    // Start precise 10ms position polling
    _scheduleNextPositionCall();
  }

  void _scheduleNextPositionCall() {
    if (_handle == null || !_isRunning) return;

    Timer(Duration(milliseconds: 10), () async {
      if (_handle == null || !_isRunning) return;

      final callStartMicros = DateTime.now().microsecondsSinceEpoch;
      final position = soloud.getPosition(_handle!);
      final callEndMicros = DateTime.now().microsecondsSinceEpoch;

      final result = TimingResult(
        wallClockTime: (callStartMicros - _playbackStartMicros) / 1000.0,
        position: position,
        callDurationMicros: callEndMicros - callStartMicros,
      );

      setState(() {
        _timingResults.add(result);
      });

      // Stop after 5 seconds of measurements
      if (result.wallClockTime > 5000) {
        _stopTest();
        return;
      }

      // Schedule next call immediately to maintain consistent timing
      _scheduleNextPositionCall();
    });
  }

  Future<void> _generateAudioStream() async {
    const chunkDurationMs = 100;
    const sampleRate = 16000;
    const samplesPerChunk = sampleRate * chunkDurationMs ~/ 1000;
    const bytesPerChunk = samplesPerChunk * 2;
    const frequency = 440.0;

    for (int i = 0; i < 60 && _isRunning; i++) {
      final chunk = Uint8List(bytesPerChunk);

      for (int j = 0; j < samplesPerChunk; j++) {
        final t = (i * samplesPerChunk + j) / sampleRate;
        final value = (32767 * 0.3 * sin(2 * pi * frequency * t)).toInt();
        chunk[j * 2] = value & 0xFF;
        chunk[j * 2 + 1] = (value >> 8) & 0xFF;
      }

      if (_streamSource != null) {
        soloud.addAudioDataStream(_streamSource!, chunk);
      }

      await Future.delayed(Duration(milliseconds: chunkDurationMs));
    }

    if (_streamSource != null) {
      soloud.setDataIsEnded(_streamSource!);
    }
  }

  void _stopTest() {
    _startDetectionTimer?.cancel();
    _positionTimer?.cancel();

    setState(() {
      _isRunning = false;
    });

    _cleanup();
  }

  Future<void> _cleanup() async {
    _startDetectionTimer?.cancel();
    _positionTimer?.cancel();

    if (_streamSource != null) {
      await soloud.disposeSource(_streamSource!);
      _streamSource = null;
    }
    _handle = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('getPosition() Timing Test'), backgroundColor: Colors.blue.shade100),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _isRunning ? null : _startPositionTest,
                  child: Text(_isRunning ? 'Test Running...' : 'Start Position Test'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _isRunning ? _stopTest : null, child: const Text('Stop Test')),
                const SizedBox(height: 16),
                if (_timingResults.isNotEmpty) ...[
                  Text(
                    'Results (${_timingResults.length} measurements)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text('Wall Time (ms)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Position (ms)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Call Time (μs)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text('Delta', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _timingResults.length,
              itemBuilder: (context, index) {
                final result = _timingResults[index];
                final prevResult = index > 0 ? _timingResults[index - 1] : null;
                final timeDelta = prevResult != null ? result.wallClockTime - prevResult.wallClockTime : 0.0;

                final positionDelta = prevResult != null
                    ? result.position.inMilliseconds - prevResult.position.inMilliseconds
                    : 0;

                final isSlowCall = result.callDurationMicros > 5000;
                final isSuspiciousTiming = timeDelta < 8 || timeDelta > 12;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: (isSlowCall || isSuspiciousTiming) ? Colors.red.shade50 : null,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          result.wallClockTime.toStringAsFixed(1),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          result.position.inMilliseconds.toString(),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          result.callDurationMicros.toString(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: isSlowCall ? Colors.red : null,
                            fontWeight: isSlowCall ? FontWeight.bold : null,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${timeDelta.toStringAsFixed(1)}ms',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: isSuspiciousTiming ? Colors.red : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
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

class TimingResult {
  final double wallClockTime; // milliseconds since playback started
  final Duration position; // position returned by getPosition
  final int callDurationMicros; // how long getPosition call took

  TimingResult({required this.wallClockTime, required this.position, required this.callDurationMicros});
}
