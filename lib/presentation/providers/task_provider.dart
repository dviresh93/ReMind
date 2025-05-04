// lib/presentation/providers/task_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../../core/services/monitor_service.dart';

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final Function onResume;
  
  _AppLifecycleObserver({required this.onResume});
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}

class TaskProvider with ChangeNotifier {
  final TaskRepository _taskRepository;
  final MonitorService _monitorService;
  late final _AppLifecycleObserver _lifecycleObserver;
  
  List<Task> _allTasks = [];
  List<Task> _activeTasks = [];
  List<Task> _completedTasks = [];
  List<Task> _snoozedTasks = [];
  
  // Getters
  List<Task> get allTasks => _allTasks;
  List<Task> get activeTasks => _activeTasks;
  List<Task> get completedTasks => _completedTasks;
  List<Task> get snoozedTasks => _snoozedTasks;
  
  // Constructor
  TaskProvider({
    required TaskRepository taskRepository,
    required MonitorService monitorService,
  }) : 
    _taskRepository = taskRepository,
    _monitorService = monitorService {
    // Initially load tasks
    refreshTasks();
    
    // Set up a periodic refresh that accounts for app state
    const refreshInterval = Duration(minutes: 1);
    Timer.periodic(refreshInterval, (timer) async {
      // Only refresh when app is in foreground
      final isInForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (isInForeground) {
        await refreshTasks();
      }
    });
    
    // Also listen for app lifecycle changes
    _lifecycleObserver = _AppLifecycleObserver(
      onResume: () => refreshTasks(),
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }
  
  // Don't forget to dispose in the provider
  @override
  void dispose() {
    // Remove the observer when provider is disposed
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }
  
  // Refresh tasks from repository
  Future<void> refreshTasks() async {
    _allTasks = await _taskRepository.getAllTasks();
    _activeTasks = await _taskRepository.getActiveTasks();
    _completedTasks = await _taskRepository.getCompletedTasks();
    _snoozedTasks = await _taskRepository.getSnoozedTasks();
    
    notifyListeners();
  }
  
  // Add a new task
  Future<void> addTask(Task task) async {
    await _taskRepository.addTask(task);
    await refreshTasks();
  }
  
  // Update an existing task
  Future<void> updateTask(Task task) async {
    await _taskRepository.updateTask(task);
    await refreshTasks();
  }
  
  // Delete a task
  Future<void> deleteTask(String id) async {
    await _taskRepository.deleteTask(id);
    await refreshTasks();
  }
  
  // Mark a task as completed
  Future<void> completeTask(String id) async {
    await _monitorService.markTaskAsCompleted(id);
    await refreshTasks();
  }
  
  // Snooze a task
  Future<void> snoozeTask(String id, {Duration timeout = const Duration(hours: 1)}) async {
    await _monitorService.snoozeTask(id, timeout: timeout);
    await refreshTasks();
  }
  
  // Get a specific task by ID
  Future<Task?> getTaskById(String id) async {
    return await _taskRepository.getTaskById(id);
  }
}