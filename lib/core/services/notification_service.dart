// lib/core/services/notification_service.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/task.dart';

class NotificationService {
  // Singleton implementation
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
      
  final BehaviorSubject<String?> _selectNotificationSubject =
      BehaviorSubject<String?>();
  
  Stream<String?> get selectNotificationStream => _selectNotificationSubject.stream;

  bool _isInitialized = false;

  Future<bool> requestNotificationPermissions() async {
    // For iOS, permissions are requested during initialization
    if (Platform.isIOS) {
      return true; // Permissions handled by DarwinInitializationSettings
    }
    
    // For Android 13+ (API level 33+)
    if (Platform.isAndroid) {
      // Check if we can request runtime permissions (Android 13+)
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation
              AndroidFlutterLocalNotificationsPlugin>();
              
      if (androidImplementation != null) {
        final arePermissionsGranted = await androidImplementation.arePermissionsGranted();
        
        if (!arePermissionsGranted) {
          final permissionGranted = await androidImplementation.requestPermission();
          return permissionGranted ?? false;
        }
        
        return true;
      }
    }
    
    return false;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize FlutterLocalNotificationsPlugin
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Android initialization
    const androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization
    const darwinInitializationSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    // Initialize settings
    final initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: darwinInitializationSettings,
    );
    
    // Initialize the plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Request permissions
    final hasPermission = await requestNotificationPermissions();
    
    if (!hasPermission) {
      print('Notification permissions not granted');
      // Store this state so the app can show appropriate UI
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_permission_granted', false);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_permission_granted', true);
    }
    
    _isInitialized = true;
  }
  
  // Define notification channels
  Future<void> _setupNotificationChannels() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'remind_task_channel',
      'Task Reminders',
      description: 'Notifications for nearby tasks',
      importance: Importance.high,
    );
    
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
  
  // Show a task notification
  Future<void> showTaskNotification(Task task) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'remind_task_channel',
      'Task Reminders',
      channelDescription: 'Notifications for nearby tasks',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // Show the notification
    await _flutterLocalNotificationsPlugin.show(
      task.id.hashCode,
      'ReMind: ${task.name}',
      'You\'re near ${task.locationName}. ${task.description}',
      details,
      payload: task.id,
    );
  }
  
  // Create a notification with action buttons
  Future<void> showTaskActionNotification(Task task) async {
    // For Android, define action buttons
    final List<AndroidNotificationAction> androidActions = [
      const AndroidNotificationAction(
        'done_action',
        'Mark as Done',
        showsUserInterface: true,
      ),
      const AndroidNotificationAction(
        'snooze_action',
        'Remind Me Later',
        showsUserInterface: true,
      ),
    ];
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'remind_task_channel',
      'Task Reminders',
      channelDescription: 'Notifications for nearby tasks',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      actions: androidActions,
    );
    
    // For iOS, we'll handle actions differently since the API is different
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );
    
    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // Show the notification
    await _flutterLocalNotificationsPlugin.show(
      task.id.hashCode,
      'ReMind: ${task.name}',
      'You\'re near ${task.locationName}. ${task.description}',
      details,
      payload: task.id,
    );
  }
  
  // Cancel a specific notification
  Future<void> cancelTaskNotification(Task task) async {
    await _flutterLocalNotificationsPlugin.cancel(task.id.hashCode);
  }
  
  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
  
  // Dispose resources
  void dispose() {
    _selectNotificationSubject.close();
  }
}