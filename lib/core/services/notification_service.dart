// lib/core/services/notification_service.dart

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/rxdart.dart';

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

  Future<void> initialize() async {
    // Initialize native notification plugin
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _selectNotificationSubject.add(response.payload);
      },
    );
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