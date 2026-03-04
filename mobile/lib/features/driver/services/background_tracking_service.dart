import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../firebase_options.dart';
import '../../../../core/config/env.dart';
import 'trip_finalizer.dart';

// ─── ADAPTIVE TRACKING CONSTANTS ───
const double _ARRIVING_DISTANCE_M = 804.0;
const double _ARRIVED_RADIUS_M = 100.0;
const int _FAR_UPDATE_SEC = 20;
const int _NEAR_UPDATE_SEC = 5;

// ─────────────────────────────────────────────────────────────────────────────
// ANDROID BACKGROUND SERVICE ENTRY POINT
// This runs inside a background isolate (separate from the main Flutter isolate)
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Tracking Active",
      content: "Ready to track trip",
    );
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    }
    final prefs = await SharedPreferences.getInstance();

    StreamSubscription<Position>? posSubscription;
    Map<String, dynamic>? lastUpdateData;

    service.on('request_update').listen((event) async {
      debugPrint("[Background] request_update received.");
      if (lastUpdateData != null) {
        lastUpdateData!['nextStopId'] = prefs.getString('next_stop_id');
        lastUpdateData!['nextStopName'] = prefs.getString('next_stop_name');
        service.invoke('update', lastUpdateData);
      }
    });

    service.on('stopService').listen((event) async {
      debugPrint("[Background] stopService received.");
      await posSubscription?.cancel();
      BackgroundTrackingService._isRunning = false;
      service.stopSelf();
    });

    final collegeId = prefs.getString('track_college_id');
    final busId = prefs.getString('track_bus_id');
    final tripId = prefs.getString('track_trip_id');

    if (collegeId == null || busId == null || tripId == null) {
      debugPrint("[Background] Context missing, stopping service.");
      service.stopSelf();
      return;
    }

    debugPrint("[Background] Tracking STARTED for Bus $busId, Trip $tripId");

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Tracking Active",
        content: "Bus $busId is on route",
      );
    }

    int lastWriteMs = 0;
    String currentMode = "FAR";
    String currentStatus = "ON_ROUTE";
    Position? lastPosition;
    double smoothedSpeedMph = 0.0;
    const double emaAlpha = 0.25;
    final Set<String> arrivingNotifiedIds = {};

    late final Stream<Position> positionStream;
    try {
      positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
    } catch (e) {
      debugPrint("[Background] Failed to start position stream: $e");
      service.stopSelf();
      return;
    }

    posSubscription = positionStream.listen((Position position) async {
      try {
        final now = DateTime.now();

        double rawSpeedMph = 0.0;
        if (position.speed > 0.5) {
          rawSpeedMph = position.speed * 2.23694;
        } else if (lastPosition != null) {
          final distM = Geolocator.distanceBetween(
              lastPosition!.latitude, lastPosition!.longitude,
              position.latitude, position.longitude);
          final timeSec = position.timestamp
              .difference(lastPosition!.timestamp)
              .inSeconds;
          if (timeSec > 0 && distM > 2) {
            rawSpeedMph = (distM / timeSec) * 2.23694;
          }
        }

        if (rawSpeedMph < 1.0) rawSpeedMph = 0.0;
        if (rawSpeedMph > 85.0) rawSpeedMph = smoothedSpeedMph;
        smoothedSpeedMph =
            (emaAlpha * rawSpeedMph) + ((1 - emaAlpha) * smoothedSpeedMph);
        final finalSpeedMph = smoothedSpeedMph.round();

        await BackgroundTrackingService._bufferPoint(
            prefs, position, finalSpeedMph);

        final nextStopLat = prefs.getDouble('next_stop_lat');
        final nextStopLng = prefs.getDouble('next_stop_lng');
        final nextStopId = prefs.getString('next_stop_id') ?? '';
        final nextStopRadius = prefs.getDouble('next_stop_radius') ?? 100.0;
        final nextStopName = prefs.getString('next_stop_name') ?? 'Stop';

        double distToNextStop = double.infinity;
        if (nextStopLat != null && nextStopLng != null) {
          distToNextStop = Geolocator.distanceBetween(
              position.latitude, position.longitude,
              nextStopLat, nextStopLng);
        }

        final hasArrivedCurrent =
            prefs.getBool('has_arrived_current') ?? false;
        final newState = BackgroundTrackingService._computeAdaptiveState(
            distToNextStop, currentStatus, nextStopRadius, hasArrivedCurrent);
        final newMode = newState['mode']!;
        final newStatus = newState['status']!;

        final elapsedMs = now.millisecondsSinceEpoch - lastWriteMs;
        final intervalSec =
            newMode == 'NEAR_STOP' ? _NEAR_UPDATE_SEC : _FAR_UPDATE_SEC;
        final statusChanged = newStatus != currentStatus;
        final modeChanged = newMode != currentMode;
        final intervalElapsed = elapsedMs >= (intervalSec * 1000);

        if (statusChanged || modeChanged || intervalElapsed) {
          BackgroundTrackingService._writeToFirestore(prefs, busId, tripId,
              position, newMode, newStatus, nextStopId, finalSpeedMph);
          lastWriteMs = now.millisecondsSinceEpoch;
          currentMode = newMode;
          currentStatus = newStatus;
        }

        if (distToNextStop <= nextStopRadius && !hasArrivedCurrent) {
          await prefs.setBool('has_arrived_current', true);
          BackgroundTrackingService._handleArrivalEntry(
              prefs, collegeId, busId, tripId, nextStopId, nextStopName, position);
        } else if (distToNextStop > (nextStopRadius + 30) &&
            hasArrivedCurrent) {
          await prefs.setBool('has_arrived_current', false);
          BackgroundTrackingService._handleStopCompletion(
              prefs, collegeId, busId, tripId, nextStopId);
        } else if (!hasArrivedCurrent && distToNextStop > nextStopRadius) {
          BackgroundTrackingService._checkForSkip(
              prefs, collegeId, busId, tripId, nextStopId, position, distToNextStop);
        }

        if ((newStatus == 'ARRIVING' || newStatus == 'AT_STOP') &&
            !arrivingNotifiedIds.contains(nextStopId)) {
          arrivingNotifiedIds.add(nextStopId);
          BackgroundTrackingService._notifyServer(
            tripId, busId, collegeId, nextStopId, "ARRIVING",
            stopName: nextStopName,
            prefs: prefs,
          );
        }

        lastPosition = position;

        debugPrint(
            "[Background] lat=${position.latitude}, lng=${position.longitude}, status=$newStatus");

        lastUpdateData = {
          "lat": position.latitude,
          "lng": position.longitude,
          "speed": smoothedSpeedMph / 2.23694,
          "speedMph": finalSpeedMph,
          "heading": position.heading,
          "status": newStatus,
          "mode": newMode,
          "nextStopId": nextStopId,
          "nextStopName": nextStopName,
        };

        service.invoke('update', lastUpdateData);
      } catch (e) {
        debugPrint("[Background] Position callback error (non-fatal): $e");
      }
    }, onError: (e) {
      debugPrint("[Background] Stream error: $e");
    });

    service.on('skip_stop').listen((event) {
      BackgroundTrackingService._handleManualSkip(service, event);
    });
  } catch (e) {
    debugPrint("[Background] CRITICAL onStart error: $e");
    service.stopSelf();
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// ✅ iOS NATIVE LOCATION TRACKING
//
// WHY: flutter_background_service on iOS uses BGTaskScheduler.
//      Apple decides when to run it — usually every 15-30 minutes.
//      It CANNOT do continuous GPS tracking.
//
// SOLUTION: On iOS, run Geolocator directly in the MAIN ISOLATE with:
//   - allowBackgroundLocationUpdates: true
//   - activityType: ActivityType.automotiveNavigation
//   - pauseLocationUpdatesAutomatically: false
//
// iOS WILL keep delivering location updates even when the screen is locked,
// as long as the app has "location" in UIBackgroundModes (Info.plist ✅)
// and "Location updates" in Xcode Background Modes capability.
// ─────────────────────────────────────────────────────────────────────────────
class IosLocationTracker {
  static StreamSubscription<Position>? _subscription;
  static bool _isRunning = false;

  static bool get isRunning => _isRunning;

  /// Starts iOS native location tracking (call this instead of BackgroundTrackingService.start() on iOS)
  static Future<void> start({
    required String collegeId,
    required String busId,
    required String tripId,
    required SharedPreferences prefs,
    required Function(Map<String, dynamic>) onUpdate,
  }) async {
    if (_isRunning) {
      debugPrint("[IosTracker] Already running, skipping start.");
      return;
    }

    _isRunning = true;
    debugPrint("[IosTracker] Starting iOS native location tracking...");

    int lastWriteMs = 0;
    String currentMode = "FAR";
    String currentStatus = "ON_ROUTE";
    Position? lastPosition;
    double smoothedSpeedMph = 0.0;
    const double emaAlpha = 0.25;
    final Set<String> arrivingNotifiedIds = {};

    // ✅ KEY: AppleSettings with allowBackgroundLocationUpdates keeps GPS alive on screen lock
    final locationSettings = AppleSettings(
      accuracy: LocationAccuracy.high,
      activityType: ActivityType.automotiveNavigation,
      distanceFilter: 10,
      pauseLocationUpdatesAutomatically: false,
      // ✅ CRITICAL: Without this, GPS stops when screen locks on iOS
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true, // Blue status bar pill
    );

    try {
      _subscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen(
        (Position position) async {
          try {
            final now = DateTime.now();

            // Compute speed
            double rawSpeedMph = 0.0;
            if (position.speed > 0.5) {
              rawSpeedMph = position.speed * 2.23694;
            } else if (lastPosition != null) {
              final distM = Geolocator.distanceBetween(
                  lastPosition!.latitude, lastPosition!.longitude,
                  position.latitude, position.longitude);
              final timeSec = position.timestamp
                  .difference(lastPosition!.timestamp)
                  .inSeconds;
              if (timeSec > 0 && distM > 2) {
                rawSpeedMph = (distM / timeSec) * 2.23694;
              }
            }

            if (rawSpeedMph < 1.0) rawSpeedMph = 0.0;
            if (rawSpeedMph > 85.0) rawSpeedMph = smoothedSpeedMph;
            smoothedSpeedMph =
                (emaAlpha * rawSpeedMph) + ((1 - emaAlpha) * smoothedSpeedMph);
            final finalSpeedMph = smoothedSpeedMph.round();

            await BackgroundTrackingService._bufferPoint(
                prefs, position, finalSpeedMph);

            final nextStopLat = prefs.getDouble('next_stop_lat');
            final nextStopLng = prefs.getDouble('next_stop_lng');
            final nextStopId = prefs.getString('next_stop_id') ?? '';
            final nextStopRadius =
                prefs.getDouble('next_stop_radius') ?? 100.0;
            final nextStopName = prefs.getString('next_stop_name') ?? 'Stop';

            double distToNextStop = double.infinity;
            if (nextStopLat != null && nextStopLng != null) {
              distToNextStop = Geolocator.distanceBetween(
                  position.latitude, position.longitude,
                  nextStopLat, nextStopLng);
            }

            final hasArrivedCurrent =
                prefs.getBool('has_arrived_current') ?? false;
            final newState = BackgroundTrackingService._computeAdaptiveState(
                distToNextStop, currentStatus, nextStopRadius, hasArrivedCurrent);
            final newMode = newState['mode']!;
            final newStatus = newState['status']!;

            final elapsedMs = now.millisecondsSinceEpoch - lastWriteMs;
            final intervalSec =
                newMode == 'NEAR_STOP' ? _NEAR_UPDATE_SEC : _FAR_UPDATE_SEC;

            if ((newStatus != currentStatus) ||
                (newMode != currentMode) ||
                (elapsedMs >= intervalSec * 1000)) {
              BackgroundTrackingService._writeToFirestore(prefs, busId, tripId,
                  position, newMode, newStatus, nextStopId, finalSpeedMph);
              lastWriteMs = now.millisecondsSinceEpoch;
              currentMode = newMode;
              currentStatus = newStatus;
            }

            if (distToNextStop <= nextStopRadius && !hasArrivedCurrent) {
              await prefs.setBool('has_arrived_current', true);
              BackgroundTrackingService._handleArrivalEntry(
                  prefs, collegeId, busId, tripId, nextStopId, nextStopName, position);
            } else if (distToNextStop > (nextStopRadius + 30) &&
                hasArrivedCurrent) {
              await prefs.setBool('has_arrived_current', false);
              BackgroundTrackingService._handleStopCompletion(
                  prefs, collegeId, busId, tripId, nextStopId);
            }

            if (newStatus == 'ARRIVING' &&
                !arrivingNotifiedIds.contains(nextStopId)) {
              arrivingNotifiedIds.add(nextStopId);
              BackgroundTrackingService._notifyServer(
                tripId, busId, collegeId, nextStopId, "ARRIVING",
                stopName: nextStopName,
                prefs: prefs,
              );
            }

            lastPosition = position;

            final updateData = {
              "lat": position.latitude,
              "lng": position.longitude,
              "speed": smoothedSpeedMph / 2.23694,
              "speedMph": finalSpeedMph,
              "heading": position.heading,
              "status": newStatus,
              "mode": newMode,
              "nextStopId": nextStopId,
              "nextStopName": nextStopName,
            };

            debugPrint(
                "[IosTracker] lat=${position.latitude}, lng=${position.longitude}, status=$newStatus");
            onUpdate(updateData);
          } catch (e) {
            debugPrint("[IosTracker] Position callback error: $e");
          }
        },
        onError: (e) {
          debugPrint("[IosTracker] Stream error: $e");
        },
      );
    } catch (e) {
      _isRunning = false;
      debugPrint("[IosTracker] Failed to start: $e");
      rethrow;
    }
  }

  static Future<void> stop() async {
    _isRunning = false;
    await _subscription?.cancel();
    _subscription = null;
    debugPrint("[IosTracker] Stopped.");
  }
}

// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
class BackgroundTrackingService {
  static bool _isRunning = false;

  static bool get isRunning => _isRunning;

  static Future<void> initialize() async {
    try {
      // On iOS, flutter_background_service is only used for Android.
      // We configure it anyway so the Android path works.
      if (Platform.isAndroid) {
        final service = FlutterBackgroundService();
        await service.configure(
          androidConfiguration: AndroidConfiguration(
            onStart: onStart,
            autoStart: false,
            isForegroundMode: true,
            notificationChannelId: 'bus_tracking',
            initialNotificationTitle: 'Tracking Active',
            initialNotificationContent: 'Ready to track trip',
            foregroundServiceTypes: [AndroidForegroundType.location],
          ),
          iosConfiguration: IosConfiguration(
            autoStart: false,
            onForeground: onStart,
            onBackground: onIosBackground,
          ),
        );
      }
    } catch (e) {
      debugPrint("[BackgroundTrackingService] initialize() failed: $e");
    }
  }

  /// ✅ FIX: Start tracking with platform-aware logic
  /// - Android: Uses flutter_background_service (true background process)
  /// - iOS: Uses IosLocationTracker (native Geolocator in main isolate)
  static Future<void> start({
    required String collegeId,
    required String busId,
    required String tripId,
    Function(Map<String, dynamic>)? onIosUpdate, // Only used on iOS
  }) async {
    if (_isRunning) {
      debugPrint("[BackgroundTrackingService] start() SKIPPED - already running");
      return;
    }
    _isRunning = true;

    if (Platform.isIOS) {
      // ✅ iOS PATH: Native Geolocator with background location
      final prefs = await SharedPreferences.getInstance();
      // Save context so IosLocationTracker can use them
      await prefs.setString('track_college_id', collegeId);
      await prefs.setString('track_bus_id', busId);
      await prefs.setString('track_trip_id', tripId);

      await IosLocationTracker.start(
        collegeId: collegeId,
        busId: busId,
        tripId: tripId,
        prefs: prefs,
        onUpdate: onIosUpdate ?? (_) {},
      );
    } else {
      // ✅ ANDROID PATH: flutter_background_service foreground service
      try {
        final service = FlutterBackgroundService();
        await service.startService();
      } catch (e) {
        _isRunning = false;
        debugPrint("[BackgroundTrackingService] Android start() FAILED: $e");
        rethrow;
      }
    }
  }

  static Future<void> stop() async {
    _isRunning = false;

    if (Platform.isIOS) {
      await IosLocationTracker.stop();
    } else {
      try {
        final service = FlutterBackgroundService();
        service.invoke("stopService");
      } catch (e) {
        debugPrint("[BackgroundTrackingService] stop() error: $e");
      }
    }
  }

  /// Send a command to the background service (Android only)
  static void sendCommand(String event, [Map<String, dynamic>? data]) {
    if (Platform.isAndroid) {
      final service = FlutterBackgroundService();
      service.invoke(event, data);
    }
  }

  /// Listen to updates from background service (Android only)
  /// For iOS, use the onIosUpdate callback passed to start()
  static Stream<Map<String, dynamic>?>? getUpdateStream() {
    if (Platform.isAndroid) {
      return FlutterBackgroundService().on('update');
    }
    return null;
  }

  // ─── Shared Static Helpers (used by both Android isolate and iOS tracker) ──

  static Future<void> _bufferPoint(
      SharedPreferences prefs, Position p, int speedMph) async {
    final newPoint = {
      'lat': p.latitude,
      'lng': p.longitude,
      'speed': speedMph,
      'speedMph': speedMph,
      'heading': p.heading,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final bufferStr = prefs.getString('trip_history_buffer') ?? '[]';
    List<dynamic> buffer = jsonDecode(bufferStr);
    buffer.add(newPoint);
    if (buffer.length > 5000) buffer.removeAt(0);
    await prefs.setString('trip_history_buffer', jsonEncode(buffer));
  }

  static Future<void> _writeToFirestore(
    SharedPreferences prefs,
    String busId,
    String tripId,
    Position p,
    String mode,
    String status,
    String nextStopId,
    int speedMph,
  ) async {
    try {
      final db = FirebaseFirestore.instance;

      await db.collection('buses').doc(busId).update({
        'status': 'ON_ROUTE',
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        'location': {
          'latitude': p.latitude,
          'longitude': p.longitude,
          'heading': p.heading,
          'speed': speedMph,
          'speedMph': speedMph,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'currentLocation': {
          'lat': p.latitude,
          'lng': p.longitude,
          'latitude': p.latitude,
          'longitude': p.longitude,
          'heading': p.heading,
          'speedMph': speedMph,
        },
        'speed': speedMph,
        'speedMph': speedMph,
        'currentSpeed': speedMph,
        'currentStatus': status,
        'trackingMode': mode,
        'nextStopId': nextStopId,
      });
      debugPrint("[Tracker] Firestore WRITE: status=$status, speed=${speedMph}mph");
    } catch (e) {
      debugPrint("[Tracker] Firestore WRITE FAILED: $e");
    }
  }

  static Map<String, String> _computeAdaptiveState(
    double distToNextStopM,
    String currentStatus,
    double radiusM,
    bool hasArrivedCurrent,
  ) {
    if (hasArrivedCurrent) {
       // We latch in ARRIVED even if GPS drifts slightly outside, 
       // until _handleStopCompletion explicitly moves us out with hysteresis.
       return {'mode': 'NEAR_STOP', 'status': 'ARRIVED'};
    }
    
    if (distToNextStopM <= radiusM) {
      return {'mode': 'NEAR_STOP', 'status': 'ARRIVED'};
    } else if (distToNextStopM <= _ARRIVING_DISTANCE_M) {
      return {'mode': 'NEAR_STOP', 'status': 'ARRIVING'};
    } else {
      return {'mode': 'FAR', 'status': 'ON_ROUTE'};
    }
  }

  static Future<void> _handleArrivalEntry(
    SharedPreferences prefs,
    String collegeId,
    String busId,
    String tripId,
    String stopId,
    String stopName,
    Position p,
  ) async {
    try {
      final db = FirebaseFirestore.instance;
      final tripRef = db.collection('trips').doc(tripId);
      final tripDoc = await tripRef.get();
      if (!tripDoc.exists) return;

      final data = tripDoc.data()!;
      final progress = data['stopProgress'] as Map<String, dynamic>? ?? {};
      final arrivedIds = List<String>.from(progress['arrivedStopIds'] ?? []);
      final arrivals = Map<String, dynamic>.from(progress['arrivals'] ?? {});
      final stops = (data['stopsSnapshot'] as List<dynamic>?) ?? [];
      final currentIndex = (progress['currentIndex'] as num?)?.toInt() ?? 0;

      if (!arrivedIds.contains(stopId)) {
        arrivedIds.add(stopId);
        arrivals[stopId] = DateTime.now().toIso8601String();
        
        final batch = db.batch();

        // 1. Update Trip
        batch.update(tripRef, {
          'stopProgress.arrivedStopIds': arrivedIds,
          'stopProgress.arrivals': arrivals,
          'stopStatus.$stopId': 'ARRIVED',
        });

        // 2. Trigger Event for Student Notifications (Firestore fallback)
        final notifRef = db.collection('stopArrivals').doc();
        batch.set(notifRef, {
          'tripId': tripId,
          'busId': busId,
          'collegeId': collegeId,
          'stopId': stopId,
          'stopName': stops.length > currentIndex ? (stops[currentIndex]['name'] ?? stopName) : stopName,
          'type': 'ARRIVED',
          'arrivedAt': DateTime.now().toIso8601String(),
          'timestamp': DateTime.now().toIso8601String(),
          'processed': true, // Mark true because we will also call Node API
        });

        // 3. Update Bus
        batch.update(db.collection('buses').doc(busId), {
          'currentStatus': 'ARRIVED',
          'trackingMode': 'NEAR_STOP',
        });

        // 4. Trigger Server FCM (Step 5F) UNCONDITIONALLY BEFORE BATCH COMMIT
        // This prevents Android offline queueing from swallowing/delaying the HTTP dispatch
        _notifyServer(tripId, busId, collegeId, stopId, "ARRIVED", 
          stopName: stops.length > currentIndex ? stops[currentIndex]['name'] : stopName,
          arrivalDocId: notifRef.id,
          prefs: prefs
        );

        await batch.commit();

        // 5. Update UI immediately (Android)
        if (Platform.isAndroid) {
          FlutterBackgroundService().invoke('update', {
            'status': 'ARRIVED',
            'nextStopId': stopId,
          });
        }
      }
    } catch (e) {
      debugPrint("[Background] HandleArrivalEntry error: $e");
    }
  }

  static Future<void> _handleStopCompletion(
    SharedPreferences prefs,
    String collegeId,
    String busId,
    String tripId,
    String stopId,
  ) async {
    try {
      final db = FirebaseFirestore.instance;
      final tripRef = db.collection('trips').doc(tripId);
      final tripDoc = await tripRef.get();
      if (!tripDoc.exists) return;

      final data = tripDoc.data()!;
      final progress = data['stopProgress'] as Map<String, dynamic>? ?? {};
      final stops = (data['stopsSnapshot'] as List<dynamic>?) ?? [];
      final currentIndex = (progress['currentIndex'] as num?)?.toInt() ?? 0;

      final newIndex = currentIndex + 1;
      final isFinalStop = newIndex >= stops.length;

      final batch = db.batch();

      // 1. Update Trip Progress
      batch.update(tripRef, {
        'stopProgress.currentIndex': newIndex,
        'stopProgress.completedStopIds': FieldValue.arrayUnion([stopId]),
        'stopStatus.$stopId': 'COMPLETED',
      });

      // 2. Update Bus Status
      final Map<String, dynamic> busUpdate = {
        'currentStatus': 'MOVING',
        'trackingMode': 'FAR',
        'completedStops': FieldValue.arrayUnion([stopId]),
      };

      if (!isFinalStop) {
        final nextStop = stops[newIndex] as Map<String, dynamic>;
        busUpdate['nextStopId'] = nextStop['stopId'] as String;
        
        // Cache NEXT stop for isolate restart
        await prefs.setDouble('next_stop_lat', (nextStop['lat'] as num).toDouble());
        await prefs.setDouble('next_stop_lng', (nextStop['lng'] as num).toDouble());
        await prefs.setDouble('next_stop_radius', (nextStop['radiusM'] as num?)?.toDouble() ?? 100.0);
        await prefs.setString('next_stop_id', nextStop['stopId'] as String);
        await prefs.setString('next_stop_name', (nextStop['name'] as String?) ?? 'Stop');
        await prefs.setBool('has_arrived_current', false);

        batch.update(db.collection('buses').doc(busId), busUpdate);
        await batch.commit();

        // 5. Update UI immediately
        if (Platform.isAndroid) {
          FlutterBackgroundService().invoke('update', {
            'status': 'MOVING',
            'nextStopId': nextStop['stopId'],
            'nextStopName': nextStop['name'],
          });
        }
      } else {
        // AUTO-END
        debugPrint("[Background] AUTO-ENDING TRIP at final stop");

        // Notify students that trip ended UNCONDITIONALLY BEFORE BATCH COMMIT
        try {
          _notifyServer(tripId, busId, collegeId, '', 'TRIP_ENDED', prefs: prefs);
        } catch (e) {
          debugPrint('[Background] Trip ended notification failed: $e');
        }

        batch.update(tripRef, {
          'status': 'COMPLETED',
          'isActive': false,
          'endTime': DateTime.now().toIso8601String(),
          'endedAt': FieldValue.serverTimestamp(),
        });
        busUpdate['status'] = 'IDLE';
        busUpdate['activeTripId'] = null;
        busUpdate['currentStatus'] = 'OFFLINE';
        busUpdate['trackingMode'] = 'FAR';
        
        await prefs.setBool('pending_finalize', true);
        await prefs.setString('pending_trip_id', tripId);
        await prefs.setString('pending_bus_id', busId);
        await prefs.setString('pending_college_id', collegeId);
        
        batch.update(db.collection('buses').doc(busId), busUpdate);
        await batch.commit(); // Ensure firestore is updated before finalization

        try {
           final apiBase = prefs.getString('api_base_url') ?? Env.apiUrl;
           final user = FirebaseAuth.instance.currentUser;
           final token = await user?.getIdToken();
           if (token != null) {
              await Dio().post(
                '$apiBase/api/driver/trip/end/$busId',
                options: Options(headers: {'Authorization': 'Bearer $token'}),
              );
           }
        } catch(e) {
           debugPrint("[Background] Auto-finalize HTTP failed, will retry: $e");
        }

        // C-4 FIX: Explicitly reset _isRunning so a new trip can be started afterward.
        BackgroundTrackingService._isRunning = false;
        
        if (Platform.isAndroid) {
          FlutterBackgroundService().invoke("stopService");
        } else {
          await IosLocationTracker.stop();
        }
      }

    } catch (e) {
      debugPrint("[Background] HandleStopCompletion error: $e");
    }
  }

  static Future<void> _checkForSkip(
    SharedPreferences prefs,
    String collegeId,
    String busId,
    String tripId,
    String currentStopId,
    Position p,
    double distToCurrentM,
  ) async {
    try {
      final db = FirebaseFirestore.instance;
      final tripRef = db.collection('trips').doc(tripId);
      final tripDoc = await tripRef.get();
      if (!tripDoc.exists) return;

      final data = tripDoc.data()!;
      final progress =
          data['stopProgress'] as Map<String, dynamic>? ?? {};
      final currentIndex =
          (progress['currentIndex'] as num?)?.toInt() ?? 0;
      final stops = (data['stopsSnapshot'] as List<dynamic>?) ?? [];

      if (currentIndex + 1 < stops.length) {
        final followingStop =
            stops[currentIndex + 1] as Map<String, dynamic>;
        final distToFollowingM = Geolocator.distanceBetween(
            p.latitude,
            p.longitude,
            (followingStop['lat'] as num).toDouble(),
            (followingStop['lng'] as num).toDouble());

        if (distToFollowingM < distToCurrentM && distToCurrentM > 500) {
          debugPrint(
              "[Tracker] AUTO-SKIP DETECTED for $currentStopId but MANUAL SKIP REQUIRED.");
        }
      }
    } catch (e) {
      debugPrint("[Tracker] CheckForSkip error: $e");
    }
  }

  static Future<void> _handleManualSkip(ServiceInstance service, Map<String, dynamic>? params) async {
    if (params == null) return;
    
    final stopId = params['stopId'] as String?;
    if (stopId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final collegeId = prefs.getString('track_college_id');
      final busId = prefs.getString('track_bus_id');
      final tripId = prefs.getString('track_trip_id');

      if (collegeId == null || busId == null || tripId == null) {
        debugPrint("[Background] Skip failed: missing context");
        return;
      }

      final db = FirebaseFirestore.instance;
      final tripRef = db.collection('trips').doc(tripId);
      final tripDoc = await tripRef.get();
      if (!tripDoc.exists) return;

      final data = tripDoc.data()!;
      final progress = data['stopProgress'] as Map<String, dynamic>? ?? {};
      final currentIndex = (progress['currentIndex'] as num?)?.toInt() ?? 0;
      final stops = (data['stopsSnapshot'] as List<dynamic>?) ?? [];

      // Verify the stopId matches the CURRENT stop in progress
      if (stops[currentIndex]['stopId'] != stopId && stops[currentIndex]['id'] != stopId) {
        debugPrint("[Background] Skip mismatch: targeted $stopId, currently at ${stops[currentIndex]['stopId']}");
        return;
      }

      if (currentIndex + 1 < stops.length) {
        final batch = db.batch();
        final skippedIds = List<String>.from(progress['skippedStopIds'] ?? []);
        
        if (!skippedIds.contains(stopId)) {
          skippedIds.add(stopId);
          final newIndex = currentIndex + 1;
          final nextStop = stops[newIndex] as Map<String, dynamic>;

          // 1. Update Trip Progress
          batch.update(tripRef, {
            'stopProgress.currentIndex': newIndex,
            'stopProgress.skippedStopIds': skippedIds,
          });

          // 2. Trigger Skip Event for Notifications
          final notifRef = db.collection('stopArrivals').doc();
          batch.set(notifRef, {
            'tripId': tripId,
            'busId': busId,
            'collegeId': collegeId,
            'stopId': stopId,
            'stopName': stops[currentIndex]['name'] ?? 'Stop',
            'type': 'SKIPPED',
            'timestamp': DateTime.now().toIso8601String(),
            'processed': true,
          });

          // 3. Update Bus Status
          batch.update(db.collection('buses').doc(busId), {
            'nextStopId': nextStop['stopId'] ?? nextStop['id'],
            'currentStatus': 'ON_ROUTE',
          });

          // 4. Trigger Server FCM
          final stopData = stops[currentIndex] as Map<String, dynamic>;
          final targetStudentIds = (stopData['studentIds'] as List<dynamic>?)?.cast<String>();

          _notifyServer(tripId, busId, collegeId, stopId, "SKIPPED", 
            stopName: stops[currentIndex]['name'],
            arrivalDocId: notifRef.id,
            targetStudentIds: targetStudentIds,
            prefs: prefs
          );

          await batch.commit();

          // 5. Update Local Cache for Isolate (Crucial for restarts)
          await prefs.setDouble('next_stop_lat', (nextStop['lat'] as num).toDouble());
          await prefs.setDouble('next_stop_lng', (nextStop['lng'] as num).toDouble());
          await prefs.setDouble('next_stop_radius', (nextStop['radiusM'] as num?)?.toDouble() ?? 100.0);
          await prefs.setString('next_stop_id', nextStop['stopId'] ?? nextStop['id'] as String);
          await prefs.setString('next_stop_name', (nextStop['name'] as String?) ?? 'Stop');
          await prefs.setBool('has_arrived_current', false);

          debugPrint("[Tracker] MANUAL SKIP SUCCESS: $stopId -> ${nextStop['stopId'] ?? nextStop['id']}");
          
          // 6. Update UI immediately (Safe invoke using the active service instance)
          if (Platform.isAndroid) {
            service.invoke('update', {
              'status': 'ON_ROUTE',
              'lat': prefs.getDouble('last_lat') ?? 0.0,
              'lng': prefs.getDouble('last_lng') ?? 0.0,
              'speedMph': params['speedMph'] ?? 0,
              'nextStopId': nextStop['stopId'] ?? nextStop['id'],
              'nextStopName': nextStop['name'],
            });
          }
        }
      } else {
        debugPrint("[Background] Cannot skip last stop.");
      }
    } catch (e) {
      debugPrint("[Background] Manual skip error: $e");
    }
  }

  /// Fire-and-forget call to the Node.js server to multicast FCM notifications.
  static void _notifyServer(
    String tripId,
    String busId,
    String collegeId,
    String stopId,
    String type, {
    String? stopName,
    String? arrivalDocId,
    List<String>? targetStudentIds,
    SharedPreferences? prefs,
  }) async {
    try {
      final apiBase = prefs?.getString('api_base_url') ?? Env.apiUrl;
      
      // Use Firebase ID Token directly - this ensures it is ALWAYS fresh
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[Tracker] _notifyServer aborted: No active FirebaseAuth user.');
        return;
      }

      final token = await user.getIdToken();
      if (token == null || token.isEmpty) {
        debugPrint('[Tracker] _notifyServer aborted: Failed to fetch fresh ID token.');
        return;
      }

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));

      final payload = {
        'tripId': tripId,
        'busId': busId,
        'collegeId': collegeId,
        'stopId': stopId,
        'stopName': stopName ?? 'Stop',
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        if (arrivalDocId != null) 'arrivalDocId': arrivalDocId,
        if (targetStudentIds != null && targetStudentIds.isNotEmpty) 
          'targetStudentIds': targetStudentIds,
      };

      if (type == 'TRIP_ENDED') {
        final response = await dio.post(
          '$apiBase/api/driver/trip-ended-notify',
          data: {
            'tripId': tripId,
            'busId': busId,
            'collegeId': collegeId,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        debugPrint('[Tracker] TRIP_ENDED success: ${response.statusCode}');
      } else {
        final response = await dio.post(
          '$apiBase/api/driver/stop-event',
          data: payload,
        );
        debugPrint('[Tracker] $type success: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('[Tracker] FAILED for $type at stopId=$stopId: ${e.message}');
      if (e.response != null) {
        debugPrint('[Tracker] Server response: ${e.response?.statusCode} — ${e.response?.data}');
      }
    } catch (e) {
      debugPrint('[Tracker] Unexpected error in _notifyServer [$type]: $e');
    }
  }
}
