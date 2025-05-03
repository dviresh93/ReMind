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

  // Add other repository methods with proper error handling...
} 