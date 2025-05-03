// lib/core/services/monitor_service.dart

import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    
    // For Android, set as foreground service
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
    }
    
    // Initialize dependencies within the service
    final locationService = LocationService();
    await locationService.initialize();
    
    final notificationService = NotificationService();
    await notificationService.initialize();
    
    final taskRepository = await LocalTaskRepository.create();
    
    // Set up location listener
    locationService.locationStream.listen((position) async {
      await _checkNearbyTasks(position, taskRepository, notificationService);
    });
    
    // Periodic check for snoozed tasks that need to be reactivated
    Timer.periodic(const Duration(minutes: 5), (_) async {
      await _checkSnoozedTasks(taskRepository);
    });
    
    // Keep the service alive
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
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
    final notifiedIds = prefs