// lib/core/services/monitor_service.dart

import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../../data/repositories/local_task_repository.dart';
import 'location_service.dart';
import 'notification_service.dart';

class MonitorService {
  // Singleton implementation
  static final MonitorService _instance = MonitorService._internal();
  factory MonitorService() => _instance;
  MonitorService._internal();
  
  // Services
  late LocationService _locationService;
  late NotificationService _notificationService;
  late TaskRepository _taskRepository;
  
  // Service instance
  final FlutterBackgroundService _backgroundService = FlutterBackgroundService();
  
  // Initialization flags
  bool _isInitialized = false;
  
  // Set of already notified task IDs to prevent duplicate notifications
  Set<String> _notifiedTaskIds = {};
  
  // Add these fields
  Timer? _recoveryTimer;
  static const _recoveryInterval = Duration(minutes: 5);
  
  // Add new fields for recovery
  static const _maxRecoveryAttempts = 3;
  static const _recoveryBackoff = Duration(minutes: 1);
  int _recoveryAttempts = 0;
  DateTime? _lastRecoveryAttempt;
  
  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize dependencies
    _locationService = LocationService();
    _notificationService = NotificationService();
    _taskRepository = await LocalTaskRepository.create();
    
    await _locationService.initialize();
    await _notificationService.initialize();
    
    // Initialize background service
    await _initializeBackgroundService();
    
    // Load notified task IDs from SharedPreferences
    await _loadNotifiedTaskIds();
    
    // Start recovery mechanism
    await _startRecoveryMechanism();
    
    _isInitialized = true;
  }
  
  // Initialize the background service
  Future<void> _initializeBackgroundService() async {
    await _backgroundService.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: true,
        isForegroundMode: true,
        initialNotificationTitle: 'ReMind',
        initialNotificationContent: 'Monitoring for tasks',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }
  
  // iOS background handler
  @pragma('vm:entry-point')
  static bool _onIosBackground(ServiceInstance service) {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }
  
  // Main background service function
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    
    LocationService? locationService;
    NotificationService? notificationService;
    TaskRepository? taskRepository;
    Timer? periodicTimer;
    
    try {
      // For Android, set as foreground service
      if (service is AndroidServiceInstance) {
        service.setAsForegroundService();
      }
      
      // Initialize Hive properly in background service
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        await Hive.initFlutter(appDocDir.path);
        print('Hive initialized in background service');
      } catch (e) {
        print('Error initializing Hive in background service: $e');
        throw Exception('Failed to initialize Hive in background service');
      }
      
      // Initialize dependencies with error handling
      try {
        locationService = LocationService();
        await locationService.initialize();
      } catch (e) {
        print('Error initializing location service: $e');
        throw Exception('Location service initialization failed');
      }
      
      try {
        notificationService = NotificationService();
        await notificationService.initialize();
      } catch (e) {
        print('Error initializing notification service: $e');
        // Continue without notifications if they fail
      }
      
      try {
        taskRepository = await LocalTaskRepository.create();
      } catch (e) {
        print('Error creating task repository: $e');
        throw Exception('Failed to initialize task repository');
      }
      
      // Set up location listener with error handling
      locationService.locationStream.listen(
        (position) async {
          try {
            await _checkNearbyTasks(position, taskRepository!, notificationService!);
          } catch (e) {
            print('Error checking nearby tasks: $e');
          }
        },
        onError: (error) {
          print('Error in location stream: $error');
        },
      );
      
      // Periodic check for snoozed tasks
      periodicTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
        try {
          await _checkSnoozedTasks(taskRepository!);
        } catch (e) {
          print('Error checking snoozed tasks: $e');
        }
      });
      
      // Keep the service alive and handle cleanup
      service.on('stopService').listen((event) async {
        periodicTimer?.cancel();
        locationService?.dispose();
        notificationService?.dispose();
        service.stopSelf();
      });
    } catch (e) {
      if (e.toString().contains('only be used in the main isolate')) {
        // This is expected when running in a background service
        print('Background service plugin warning (expected): $e');
        // Continue execution
      } else {
        // Handle other errors
        print('Unexpected error in background service: $e');
        throw e;
      }
    }
  }
  
  // Check for nearby tasks
  static Future<void> _checkNearbyTasks(
    Position position,
    TaskRepository taskRepository,
    NotificationService notificationService,
  ) async {
    // Get active tasks
    final tasks = await taskRepository.getActiveTasks();
    
    // Check which tasks are nearby
    final locationService = LocationService();
    final nearbyTasks = locationService.getNearbyTasks(tasks, position);
    
    // Load already notified task IDs
    final notifiedTaskIds = await _getNotifiedTaskIds();
    
    // Show notifications for nearby tasks that haven't been notified yet
    for (final task in nearbyTasks) {
      if (!notifiedTaskIds.contains(task.id)) {
        await notificationService.showTaskActionNotification(task);
        
        // Add to notified set
        notifiedTaskIds.add(task.id);
        await _saveNotifiedTaskIds(notifiedTaskIds);
      }
    }
  }
  
  // Check for snoozed tasks that need to be reactivated
  static Future<void> _checkSnoozedTasks(TaskRepository taskRepository) async {
    final now = DateTime.now();
    final snoozedTasks = await taskRepository.getSnoozedTasks();
    
    for (final task in snoozedTasks) {
      if (task.snoozedUntil != null && now.isAfter(task.snoozedUntil!)) {
        // Reactivate the task by updating its status to pending
        final updatedTask = task.copyWith(
          status: TaskStatus.pending,
          snoozedUntil: null,
        );
        
        await taskRepository.updateTask(updatedTask);
      }
    }
  }
  
  // Load already notified task IDs from SharedPreferences
  Future<void> _loadNotifiedTaskIds() async {
    final prefs = await SharedPreferences.getInstance();
    final notifiedIds = prefs.getStringList('notified_task_ids') ?? [];
    _notifiedTaskIds = Set<String>.from(notifiedIds);
  }
  
  // Get notified task IDs (static for background service)
  static Future<Set<String>> _getNotifiedTaskIds() async {
    final prefs = await SharedPreferences.getInstance();
    final notifiedIds = prefs.getStringList('notified_task_ids') ?? [];
    return Set<String>.from(notifiedIds);
  }
  
  // Save notified task IDs
  static Future<void> _saveNotifiedTaskIds(Set<String> notifiedIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notified_task_ids', notifiedIds.toList());
  }

  Future<void> stopService() async {
    if (!_isInitialized) return;
    
    // Stop the service properly
    _backgroundService.invoke('stopService');
    
    // Clean up resources
    _locationService.dispose();
    _notificationService.dispose();
    
    // Clear notification UI
    await _notificationService.cancelAllNotifications();
    
    _isInitialized = false;
  }

  Future<void> startService() async {
    if (!_isInitialized) {
      await initialize();
    }
    await _backgroundService.startService();
  }

  Future<void> markTaskAsCompleted(String id) async {
    await _taskRepository.completeTask(id);
    // Remove from notified tasks if present
    _notifiedTaskIds.remove(id);
    await _saveNotifiedTaskIds(_notifiedTaskIds);
  }

  Future<void> snoozeTask(String id, {Duration timeout = const Duration(hours: 1)}) async {
    await _taskRepository.snoozeTask(id, timeout: timeout);
    // Remove from notified tasks if present
    _notifiedTaskIds.remove(id);
    await _saveNotifiedTaskIds(_notifiedTaskIds);
  }

  // Add this method
  Future<void> _startRecoveryMechanism() async {
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer.periodic(_recoveryInterval, (_) async {
      await _attemptServiceRecovery();
    });
  }

  Future<void> _attemptServiceRecovery() async {
    try {
      final isRunning = await _backgroundService.isRunning();
      if (!isRunning) {
        // Check if we should attempt recovery
        if (_canAttemptRecovery()) {
          print('Background service not running, attempting recovery...');
          _recoveryAttempts++;
          _lastRecoveryAttempt = DateTime.now();
          
          await startService();
          
          // Verify service is running
          final isNowRunning = await _backgroundService.isRunning();
          if (!isNowRunning) {
            await _handleRecoveryFailure();
          } else {
            // Reset recovery counters on success
            _recoveryAttempts = 0;
            _lastRecoveryAttempt = null;
          }
        } else {
          await _handleRecoveryFailure();
        }
      }
    } catch (e) {
      print('Error in recovery mechanism: $e');
      await _handleRecoveryFailure();
    }
  }

  bool _canAttemptRecovery() {
    if (_recoveryAttempts >= _maxRecoveryAttempts) return false;
    if (_lastRecoveryAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastRecoveryAttempt!);
      return timeSinceLastAttempt > _recoveryBackoff;
    }
    return true;
  }

  Future<void> _handleRecoveryFailure() async {
    await _notificationService.showServiceStatusNotification(
      'Service Recovery Failed',
      'Please open the app to restart the monitoring service.',
    );
  }

  // Update dispose method
  @override
  void dispose() {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _backgroundService.invoke('stopService');
    _locationService.dispose();
    _notificationService.dispose();
    _isInitialized = false;
  }
}