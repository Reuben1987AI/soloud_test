# SoLoud getPosition() Timing Resolution Test

A Flutter app that precisely measures the timing behavior and resolution accuracy of SoLoud's `getPosition()` method.

## Overview

This test investigates whether `getPosition()` accurately reports audio playback time when called at short intervals (10ms). It uses high-precision timing measurements to detect timing resolution issues.

## How It Works

### 1. Playback Start Detection
- Creates a streaming audio source with 16kHz mono audio
- Starts playback immediately (before any audio data is streamed)
- Uses a **2ms polling timer** to detect when `position > Duration.zero`
- Records the exact microsecond timestamp when playback begins

### 2. Position Measurement Phase
Once playback starts, the app switches to **10ms interval measurements**:

```dart
Timer.periodic(Duration(milliseconds: 10), (timer) async {
  final callStartMicros = DateTime.now().microsecondsSinceEpoch;
  final position = await soloud.getPosition(_handle!);
  final callEndMicros = DateTime.now().microsecondsSinceEpoch;
  
  // Record timing data...
});
```

### 3. Audio Stream Generation
- Generates 440Hz sine wave in 100ms chunks
- Streams audio data progressively to simulate real-world conditions
- Continues for ~6 seconds total

## Measurements Explained

### Wall Time (ms)
- **What it is**: Milliseconds elapsed since playback started (when position first became > 0)
- **Expected behavior**: Should increase by ~10ms each measurement
- **Purpose**: Shows the real-world timing of our measurements

### Position (ms) 
- **What it is**: The playback position returned by `getPosition()`
- **Expected behavior**: Should closely track wall time (within reasonable tolerance)
- **Purpose**: Shows what SoLoud thinks the current playback position is

### Call Time (μs)
- **What it is**: Microseconds it took for the `getPosition()` call to complete
- **Red highlight**: Calls taking >5000 μs (5ms) are highlighted as potentially problematic
- **Purpose**: Detects if `getPosition()` calls are blocking or slow

### Delta (ms)
- **What it is**: Time difference between consecutive wall time measurements
- **Expected value**: ~10.0ms (since we call every 10ms)
- **Red highlight**: Values <8ms or >12ms indicate timing irregularities
- **Purpose**: Verifies our measurement timing is consistent

## What to Look For

### ✅ Good Results
- Wall time increases steadily by ~10ms
- Position values track closely with wall time
- Call times stay under 2000 μs 
- Deltas stay between 8-12ms

### ❌ Problematic Results
- **Position lag**: Position significantly behind wall time
- **Position jumps**: Large gaps in position values
- **Slow calls**: Call times >5ms (highlighted in red)
- **Timing issues**: Delta values outside 8-12ms range (highlighted in red)
- **Frozen position**: Position stops advancing while wall time continues

## Common Issues This Test Detects

1. **Low resolution**: Position only updates every 50-100ms instead of tracking smoothly
2. **Blocking calls**: `getPosition()` takes too long to return
3. **Position caching**: Same position returned for multiple consecutive calls
4. **Synchronization issues**: Position doesn't accurately reflect actual playback time

## Running the Test

1. `flutter pub get`
2. `flutter run`
3. Tap "Start Position Test"
4. Watch the real-time measurements for 5 seconds
5. Look for red-highlighted problematic measurements

The test automatically stops after 5 seconds and displays up to 50 recent measurements in a scrollable list.
