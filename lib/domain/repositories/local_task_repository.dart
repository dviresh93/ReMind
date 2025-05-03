// lib/data/repositories/local_task_repository.dart

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';

class LocalTaskRepository implements TaskRepository {
  static const String _taskBoxName = 'tasks';
  final Box<Map<dynamic, dynamic>> _taskBox;
  
  LocalTaskRepository(this._taskBox);
  
  // Create a singleton instance
  static Future<LocalTaskRepository> create() async {
    // Register the adapter
    if (!Hive.isBoxOpen(_taskBoxName)) {
      // Open the box
      final box = await Hive.openBox<Map<dynamic, dynamic>>(_taskBoxName);
      return LocalTaskRepository(box);
    } else {
      return LocalTaskRepository(Hive.box<Map<dynamic, dynamic>>(_taskBoxName));
    }
  }

  @override
  Future<List<Task>> getAllTasks() async {
    return _taskBox.values
        .map((map) => Task.fromMap(Map<String, dynamic>.from(map)))
        .toList();
  }

  @override
  Future<List<Task>> getActiveTasks() async {
    final now = DateTime.now();
    final tasks = await getAllTasks();
    
    return tasks.where((task) {
      // Check if task is not completed
      if (task.status == TaskStatus.completed) return false;
      
      // Check if task is currently snoozed
      if (task.status == TaskStatus.snoozed && 
          task.snoozedUntil != null && 
          now.isBefore(task.snoozedUntil!)) {
        return false;
      }
      
      // Check if task is valid for the current time
      return task.isValidForTime(now);
    }).toList();
  }

  @override
  Future<List<Task>> getCompletedTasks() async {
    final tasks = await getAllTasks();
    return tasks.where((task) => task.status == TaskStatus.completed).toList();
  }

  @override
  Future<List<Task>> getSnoozedTasks() async {
    final now = DateTime.now();
    final tasks = await getAllTasks();
    
    return tasks.where((task) {
      return task.status == TaskStatus.snoozed && 
             task.snoozedUntil != null && 
             now.isBefore(task.snoozedUntil!);
    }).toList();
  }

  @override
  Future<Task?> getTaskById(String id) async {
    final taskMap = _taskBox.get(id);
    if (taskMap == null) return null;
    
    return Task.fromMap(Map<String, dynamic>.from(taskMap));
  }

  @override
  Future<void> addTask(Task task) async {
    // If no ID is provided, generate one
    final taskToSave = task.id.isEmpty 
        ? task.copyWith(id: const Uuid().v4()) 
        : task;
    
    await _taskBox.put(taskToSave.id, taskToSave.toMap());
  }

  @override
  Future<void> updateTask(Task task) async {
    await _taskBox.put(task.id, task.toMap());
  }

  @override
  Future<void> deleteTask(String id) async {
    await _taskBox.delete(id);
  }

  @override
  Future<void> completeTask(String id) async {
    final task = await getTaskById(id);
    if (task == null) return;
    
    final updatedTask = task.markAsCompleted();
    await updateTask(updatedTask);
  }

  @override
  Future<void> snoozeTask(String id, {Duration timeout = const Duration(hours: 1)}) async {
    final task = await getTaskById(id);
    if (task == null) return;
    
    final updatedTask = task.snooze(timeout: timeout);
    await updateTask(updatedTask);
  }
}