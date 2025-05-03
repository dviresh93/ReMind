// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import 'core/services/location_service.dart';
import 'core/services/monitor_service.dart';
import 'core/services/notification_service.dart';
import 'data/repositories/local_task_repository.dart';
import 'domain/repositories/task_repository.dart';
import 'presentation/providers/task_provider.dart';
import 'app.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize Hive
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  
  // Initialize services
  final locationService = LocationService();
  await locationService.initialize();
  
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  final taskRepository = await LocalTaskRepository.create();
  
  final monitorService = MonitorService();
  await monitorService.initialize();
  
  // Start the background service
  await monitorService.startService();
  
  // Run the app
  runApp(
    MultiProvider(
      providers: [
        Provider<TaskRepository>(
          create: (_) => taskRepository,
        ),
        Provider<LocationService>(
          create: (_) => locationService,
        ),
        Provider<NotificationService>(
          create: (_) => notificationService,
        ),
        Provider<MonitorService>(
          create: (_) => monitorService,
        ),
        ChangeNotifierProvider(
          create: (context) => TaskProvider(
            taskRepository: context.read<TaskRepository>(),
            monitorService: context.read<MonitorService>(),
          ),
        ),
      ],
      child: const ReMindApp(),
    ),
  );
}