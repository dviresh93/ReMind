// lib/domain/repositories/task_repository.dart

import '../entities/task.dart';

abstract class TaskRepository {
  // Get all tasks
  Future<List<Task>> getAllTasks();
  
  // Get active tasks (not completed and not currently snoozed)
  Future<List<Task>> getActiveTasks();
  
  // Get completed tasks
  Future<List<Task>> getCompletedTasks();
  
  // Get snoozed tasks
  Future<List<Task>> getSnoozedTasks();
  
  // Get a specific task by ID
  Future<Task?> getTaskById(String id);
  
  // Add a new task
  Future<void> addTask(Task task);
  
  // Update an existing task
  Future<void> updateTask(Task task);
  
  // Delete a task
  Future<void> deleteTask(String id);
  
  // Move a task to the completed list
  Future<void> completeTask(String id);
  
  // Snooze a task with a timeout
  Future<void> snoozeTask(String id, {Duration timeout = const Duration(hours: 1)});
}