// lib/presentation/screens/archived_tasks_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import 'task_detail_screen.dart';

class ArchivedTasksScreen extends StatelessWidget {
  const ArchivedTasksScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final completedTasks = taskProvider.completedTasks;
        
        if (completedTasks.isEmpty) {
          return const Center(
            child: Text(
              'No archived tasks',
              style: TextStyle(fontSize: 18),
            ),
          );
        }
        
        return RefreshIndicator(
          onRefresh: () => taskProvider.refreshTasks(),
          child: ListView.builder(
            itemCount: completedTasks.length,
            itemBuilder: (context, index) {
              final task = completedTasks[index];
              return _ArchivedTaskListItem(task: task);
            },
          ),
        );
      },
    );
  }
}

// Archived task list item
class _ArchivedTaskListItem extends StatelessWidget {
  final Task task;
  
  const _ArchivedTaskListItem({required this.task});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    
    // Format the time range
    final timeRange = '${dateFormat.format(task.startTime)} - ${dateFormat.format(task.endTime)}';
    
    // Format last reminded time (when it was completed)
    final completedText = task.lastReminded != null 
        ? 'Completed: ${dateFormat.format(task.lastReminded!)} at ${timeFormat.format(task.lastReminded!)}'
        : 'Completed';
        
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailScreen(taskId: task.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Task name with completed icon
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Location
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.locationName,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // Time range
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    timeRange,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // Completed time
              Row(
                children: [
                  const Icon(Icons.done_all, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    completedText,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              
              // Actions
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Delete
                  TextButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    onPressed: () {
                      // Confirm delete
                      _showDeleteConfirmationDialog(context, task);
                    },
                  ),
                  
                  // Restore as active
                  TextButton.icon(
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore'),
                    onPressed: () {
                      // Update task status to pending
                      final updatedTask = task.copyWith(
                        status: TaskStatus.pending,
                        lastReminded: null,
                        snoozedUntil: null,
                      );
                      
                      context.read<TaskProvider>().updateTask(updatedTask);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Show delete confirmation dialog
  void _showDeleteConfirmationDialog(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: Text('Are you sure you want to delete "${task.name}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<TaskProvider>().deleteTask(task.id);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}