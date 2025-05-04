// lib/core/services/location_service.dart

import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/task.dart';
import 'notification_service.dart';

class LocationService {
  static const String _isolateName = 'locationIsolate';
  static const String _portName = 'location_service_port';
  
  // Singleton implementation
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Streams and controllers
  StreamController<Position>? _locationStreamController;
  Stream<Position> get locationStream => _locationStreamController?.stream ?? Stream.empty();
  
  // Background isolate and port
  Isolate? _isolate;
  ReceivePort? _receivePort;
  
  // Haversine formula calculator
  final Distance _distance = const Distance();
  
  // Notification service
  late NotificationService _notificationService;
  
  // Add this property to track initialization status
  bool _isInitialized = false;
  
  // Update the location settings
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.balanced,  // Changed from high to balanced
    distanceFilter: 50,  // Changed from 10m to 50m
    timeLimit: Duration(minutes: 5),  // Add time limit to prevent continuous updates
  );
  
  // Add this property to prevent concurrent initialization
  bool _initializing = false;
  
  // Initialize the location service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Prevent concurrent initialization
    if (_initializing) return;
    _initializing = true;
    
    try {
      // Create a stream controller if not exists or was closed
      _locationStreamController ??= StreamController<Position>.broadcast();
      
      // Initialize dependencies
      _notificationService = NotificationService();
      await _notificationService.initialize();
      
      // Start periodic permission checks
      Timer.periodic(const Duration(minutes: 15), (_) {
        verifyLocationPermissions();
      });
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return Future.error('Location services are disabled.');
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return Future.error('Location permissions are denied');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return Future.error(
            'Location permissions are permanently denied, we cannot request permissions.');
      }
      
      // Start location tracking
      await _startLocationTracking();
      
      _isInitialized = true;
    } finally {
      _initializing = false;
    }
  }

  // Start tracking location in the background
  Future<void> _startLocationTracking() async {
    try {
      _receivePort?.close();  // Close existing port if any
      _isolate?.kill();       // Kill existing isolate if any
      
      _receivePort = ReceivePort();
      IsolateNameServer.removePortNameMapping(_portName);  // Clean up old mapping
      IsolateNameServer.registerPortWithName(
        _receivePort!.sendPort, 
        _portName,
      );
      
      // Implement the missing message handler
      _receivePort!.listen(_handleIsolateMessage);
      
      _isolate = await Isolate.spawn(
        _isolateFunction,
        _receivePort!.sendPort,
      ).catchError((error) {
        print('Error spawning isolate: $error');
        _cleanupResources();
        throw Exception('Failed to start location tracking');
      });
      
      // Send start signal to isolate
      final sendPort = IsolateNameServer.lookupPortByName(_portName);
      sendPort?.send('start');
    } catch (e) {
      print('Error in _startLocationTracking: $e');
      _cleanupResources();
      rethrow;
    }
  }
  
  // Add the missing method to handle messages from the isolate
  SendPort? _isolateSendPort;
  
  void _handleIsolateMessage(dynamic message) {
    if (message is SendPort) {
      _isolateSendPort = message;
      _isolateSendPort?.send('start');
    } else if (message is Position) {
      _locationStreamController?.add(message);
    }
  }
  
  // Function to run in the isolate
  static void _isolateFunction(SendPort sendPort) async {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    
    await for (var message in receivePort) {
      if (message == 'start') {
        break;
      }
    }
    
    final mainSendPort = IsolateNameServer.lookupPortByName(_portName);
    if (mainSendPort == null) {
      Isolate.exit();
    }
    
    StreamSubscription<Position>? positionStream;
    
    // Add retry counter
    int retryCount = 0;
    const maxRetries = 3;
    
    try {
      positionStream = Geolocator.getPositionStream(
        locationSettings: _locationSettings,
      ).listen(
        (Position position) {
          mainSendPort?.send(position);
        },
        onError: (error) {
          print('Error in location stream: $error');
          positionStream?.cancel();
          
          // Limit retry attempts
          if (retryCount < maxRetries) {
            retryCount++;
            Future.delayed(const Duration(seconds: 5), () {
              final port = IsolateNameServer.lookupPortByName(_portName);
              if (port != null) {
                // Don't recursively call, use a state machine approach
                positionStream = Geolocator.getPositionStream(
                  locationSettings: _locationSettings,
                ).listen(
                  (Position position) {
                    mainSendPort?.send(position);
                  },
                  onError: (error) {
                    print('Error in location stream: $error');
                    positionStream?.cancel();
                    
                    // Too many retries, exit isolate
                    Isolate.exit();
                  },
                );
              }
            });
          } else {
            // Too many retries, exit isolate
            Isolate.exit();
          }
        },
      );
    } catch (e) {
      print('Fatal error in location stream: $e');
      positionStream?.cancel();
      Isolate.exit();
    }
    
    // Add a handler to clean up resources when exiting
    receivePort.listen((message) {
      if (message == 'stop') {
        positionStream?.cancel();
        Isolate.exit();
      }
    });
  }

  // Check if a task is nearby the current location
  bool isTaskNearby(Task task, Position currentPosition, {double? customProximityRadius}) {
    // Convert Position to LatLng
    final currentLatLng = LatLng(currentPosition.latitude, currentPosition.longitude);
    
    // Calculate distance between current position and task location
    final distanceInMeters = _distance.as(
      LengthUnit.Meter,
      currentLatLng,
      task.location,
    );
    
    // Check if within proximity radius
    return distanceInMeters <= (customProximityRadius ?? task.proximityRadius);
  }
  
  // Get all nearby tasks from a list
  List<Task> getNearbyTasks(List<Task> tasks, Position currentPosition) {
    return tasks.where((task) => isTaskNearby(task, currentPosition)).toList();
  }
  
  // Dispose resources
  void _cleanupResources() {
    // Send stop message to isolate if it exists
    final sendPort = IsolateNameServer.lookupPortByName(_portName);
    sendPort?.send('stop');
    
    _receivePort?.close();
    _isolate?.kill();
    _isolate = null;
    _receivePort = null;
    IsolateNameServer.removePortNameMapping(_portName);
    
    // Close the stream controller
    _locationStreamController?.close();
    _locationStreamController = null;
    _isInitialized = false;
  }

  // Fixed dispose method (removed invalid super.dispose())
  void dispose() {
    _cleanupResources();
  }

  // Add this method to periodically check permissions
  Future<void> verifyLocationPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _notificationService.showServiceStatusNotification(
          'Location services disabled',
          'Please enable location services for ReMind to work properly'
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Automatically try to request permission again
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _notificationService.showServiceStatusNotification(
            'Location permission required',
            'ReMind needs location permission to remind you about nearby tasks'
          );
        } else if (permission == LocationPermission.always ||
                  permission == LocationPermission.whileInUse) {
          // Permission granted, restart tracking if needed
          if (!_isInitialized) {
            await initialize();
          }
        }
      }
    } catch (e) {
      print('Error verifying location permissions: $e');
    }
  }
}