import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';

class LocalTaskRepository implements TaskRepository {
  static const String _taskBoxName = 'tasks';
  final Box<Map<dynamic, dynamic>> _taskBox;
  
  LocalTaskRepository(this._taskBox);
  
  static Future<LocalTaskRepository> create() async {
    if (!Hive.isBoxOpen(_taskBoxName)) {
      final box = await Hive.openBox<Map<dynamic, dynamic>>(_taskBoxName)
          .catchError((error) {
        print('Error opening Hive box: $error');
        throw Exception('Failed to initialize local storage');
      });
      return LocalTaskRepository(box);
    }
    return LocalTaskRepository(Hive.box<Map<dynamic, dynamic>>(_taskBoxName));
  }

  // Implementation remains the same but with added error handling
  @override
  Future<List<Task>> getAllTasks() async {
    try {
      return _taskBox.values
          .map((map) => Task.fromMap(Map<String, dynamic>.from(map)))
          .toList();
    } catch (e) {
      print('Error getting all tasks: $e');
      return [];
    }
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
    
    return tasks.where((task) => 
      task.status == TaskStatus.snoozed && 
      task.snoozedUntil != null && 
      now.isBefore(task.snoozedUntil!)
    ).toList();
  }

  @override
  Future<Task?> getTaskById(String id) async {
    try {
      final tasks = await getAllTasks();
      return tasks.firstWhere((task) => task.id == id);
    } catch (e) {
      print('Error getting task by ID: $e');
      return null;
    }
  }

  @override
  Future<void> addTask(Task task) async {
    try {
      await _taskBox.put(task.id, task.toMap());
    } catch (e) {
      print('Error adding task: $e');
      throw Exception('Failed to add task');
    }
  }

  @override
  Future<void> updateTask(Task task) async {
    try {
      await _taskBox.put(task.id, task.toMap());
    } catch (e) {
      print('Error updating task: $e');
      throw Exception('Failed to update task');
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      await _taskBox.delete(id);
    } catch (e) {
      print('Error deleting task: $e');
      throw Exception('Failed to delete task');
    }
  }

  @override
  Future<void> completeTask(String id) async {
    try {
      final task = await getTaskById(id);
      if (task != null) {
        final completedTask = task.markAsCompleted();
        await updateTask(completedTask);
      }
    } catch (e) {
      print('Error completing task: $e');
      throw Exception('Failed to complete task');
    }
  }

  @override
  Future<void> snoozeTask(String id, {Duration timeout = const Duration(hours: 1)}) async {
    try {
      final task = await getTaskById(id);
      if (task != null) {
        final snoozedTask = task.snooze(timeout: timeout);
        await updateTask(snoozedTask);
      }
    } catch (e) {
      print('Error snoozing task: $e');
      throw Exception('Failed to snooze task');
    }
  }

  // Add other repository methods with proper error handling...
} 