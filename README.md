# SoLoud Test - getPosition Method Test

A Flutter test project to verify the functionality of the `getPosition` method in the SoLoud audio library.

## Overview

This project tests the `getPosition` method of the [flutter_soloud](https://pub.dev/packages/flutter_soloud) library by:

1. Creating a buffer stream for real-time audio playback
2. Feeding white noise data in chunks to simulate streaming audio
3. Monitoring the playback position using `getPosition()` method
4. Comparing the reported position with manual calculations based on streamed data

## Features

- Real-time audio streaming using SoLoud's buffer stream functionality
- Position tracking at 100ms intervals
- Visual log display showing position updates and analysis
- Validation of position accuracy against expected values

## Requirements

- Flutter SDK ^3.8.1
- flutter_soloud ^3.1.10

## Running the Test

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the application
4. Press the "Run Position Test" button to execute the test

## Test Details

The test:
- Initializes SoLoud with 16kHz sample rate, mono channel
- Creates a 2MB buffer stream
- Generates and streams 20 chunks of white noise (100ms each)
- Monitors playback position every 100ms
- Compares SoLoud's reported position with manually calculated position
- Displays results in real-time with analysis

## Expected Results

The test should show:
- Progressive position increases as audio plays
- Non-zero position values after playback starts
- Position values roughly matching the amount of audio data streamed
