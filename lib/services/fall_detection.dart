import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum FallState { monitoring, freeFallDetected, impactDetected }

class FallDetectionService {
  StreamSubscription<AccelerometerEvent>? _subscription;
  FallState _state = FallState.monitoring;
  DateTime? _freeFallTime;
  DateTime? _impactTime;
  
  // Buffers to track stillness after impact
  final List<double> _stillnessBuffer = [];
  static const int _stillnessWindowSize = 20; // ~2 seconds of data at 10Hz

  final VoidCallback onFallDetected;
  bool _isEnabled = false;

  bool get isEnabled => _isEnabled;

  FallDetectionService({required this.onFallDetected});

  // Start listening to the accelerometer
  void start() {
    if (_isEnabled) return;
    _isEnabled = true;
    _state = FallState.monitoring;
    _stillnessBuffer.clear();

    _subscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      _processAccelerometerData(event);
    });
    debugPrint("Fall Detection Service Started.");
  }

  // Stop listening
  void stop() {
    if (!_isEnabled) return;
    _isEnabled = false;
    _subscription?.cancel();
    _subscription = null;
    debugPrint("Fall Detection Service Stopped.");
  }

  // Process raw accelerometer readings
  void _processAccelerometerData(AccelerometerEvent event) {
    // Calculate total acceleration magnitude (including gravity ~9.8 m/s^2)
    final double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final now = DateTime.now();

    switch (_state) {
      case FallState.monitoring:
        // Free fall detection: magnitude drops near 0 (typical threshold: < 3.0 m/s^2)
        if (magnitude < 3.0) {
          _state = FallState.freeFallDetected;
          _freeFallTime = now;
          debugPrint("Fall Detection: Free fall detected! Magnitude: $magnitude");
        }
        break;

      case FallState.freeFallDetected:
        // Check for timeout (if impact doesn't happen within 500ms, reset)
        if (_freeFallTime != null && now.difference(_freeFallTime!).inMilliseconds > 500) {
          _state = FallState.monitoring;
          debugPrint("Fall Detection: Free fall timed out. Resetting.");
          break;
        }

        // Impact detection: sharp spike in acceleration (typical threshold: > 25.0 m/s^2)
        if (magnitude > 25.0) {
          _state = FallState.impactDetected;
          _impactTime = now;
          _stillnessBuffer.clear();
          debugPrint("Fall Detection: Impact detected! Magnitude: $magnitude");
        }
        break;

      case FallState.impactDetected:
        // Check for timeout in stillness verification (if we take too long, reset)
        if (_impactTime != null && now.difference(_impactTime!).inMilliseconds > 3000) {
          _state = FallState.monitoring;
          debugPrint("Fall Detection: Stillness validation timed out. Resetting.");
          break;
        }

        // Collect samples to check for stillness (the elder lies motionless on the floor)
        _stillnessBuffer.add(magnitude);

        if (_stillnessBuffer.length >= _stillnessWindowSize) {
          // Verify if the device is stationary near gravity
          if (_checkStillness()) {
            debugPrint("Fall Detection: Stillness confirmed! Triggering SOS countdown.");
            onFallDetected();
          } else {
            debugPrint("Fall Detection: Stillness rejected (movement detected). Resetting.");
          }
          _state = FallState.monitoring;
          _stillnessBuffer.clear();
        }
        break;
    }
  }

  // Check if the readings in the buffer represent a stationary state (gravity)
  bool _checkStillness() {
    if (_stillnessBuffer.isEmpty) return false;

    double sum = 0.0;
    for (var val in _stillnessBuffer) {
      sum += val;
    }
    final double mean = sum / _stillnessBuffer.length;

    // The resting gravity should be around 9.8 m/s^2 (allow 9.0 to 10.6)
    if (mean < 8.5 || mean > 11.0) {
      return false;
    }

    // Check variance: find the min and max readings
    double minVal = _stillnessBuffer[0];
    double maxVal = _stillnessBuffer[0];
    for (var val in _stillnessBuffer) {
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
    }

    // If difference between min and max magnitude is small (< 1.5 m/s^2), it is stationary
    final double range = maxVal - minVal;
    return range < 1.5;
  }
}
