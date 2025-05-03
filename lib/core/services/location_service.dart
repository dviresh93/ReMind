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
  final _locationStreamController = StreamController<Position>.broadcast();
  Stream<Position> get locationStream => _locationStreamController.stream;
  
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
  
  // Initialize the location service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
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
      
      _receivePort!.listen(_handleIsolateMessage);
      
      _isolate = await Isolate.spawn(
        _isolateFunction,
        _receivePort!.sendPort,
      ).catchError((error) {
        print('Error spawning isolate: $error');
        _cleanupResources();
        throw Exception('Failed to start location tracking');
      });
    } catch (e) {
      print('Error in _startLocationTracking: $e');
      _cleanupResources();
      rethrow;
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
    
    try {
      await Geolocator.getPositionStream(
        locationSettings: _locationSettings,
      ).listen(
        (Position position) {
          mainSendPort?.send(position);
        },
        onError: (error) {
          print('Error in location stream: $error');
          // Attempt to restart the stream on error
          _isolateFunction(sendPort);
        },
      );
    } catch (e) {
      print('Fatal error in location stream: $e');
      Isolate.exit();
    }
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
    _receivePort?.close();
    _isolate?.kill();
    _isolate = null;
    _receivePort = null;
    IsolateNameServer.removePortNameMapping(_portName);
    _locationStreamController.close();
    _isInitialized = false;
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  // Add this method to periodically check permissions
  Future<void> verifyLocationPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Notify about disabled location services
        _notificationService.showServiceStatusNotification(
          'Location services disabled',
          'Please enable location services for ReMind to work properly'
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        // Permissions have been revoked, update app state
        _notificationService.showServiceStatusNotification(
          'Location permission required',
          'ReMind needs location permission to remind you about nearby tasks'
        );
      }
    } catch (e) {
      print('Error verifying location permissions: $e');
    }
  }
}