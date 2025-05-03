// lib/presentation/screens/current_tasks_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import 'task_detail_screen.dart';

class CurrentTasksScreen extends StatelessWidget {
  const CurrentTasksScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Snoozed'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ActiveTasksList(),
                _SnoozedTasksList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Active tasks list
class _ActiveTasksList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final activeTasks = taskProvider.activeTasks;
        
        if (activeTasks.isEmpty) {
          return const Center(
            child: Text(
              'No active tasks',
              style: TextStyle(fontSize: 18),
            ),
          );
        }
        
        return RefreshIndicator(
          onRefresh: () => taskProvider.refreshTasks(),
          child: ListView.builder(
            itemCount: activeTasks.length,
            itemBuilder: (context, index) {
              final task = activeTasks[index];
              return _TaskListItem(task: task);
            },
          ),
        );
      },
    );
  }
}

// Snoozed tasks list
class _SnoozedTasksList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final snoozedTasks = taskProvider.snoozedTasks;
        
        if (snoozedTasks.isEmpty) {
          return const Center(
            child: Text(
              'No snoozed tasks',
              style: TextStyle(fontSize: 18),
            ),
          );
        }
        
        return RefreshIndicator(
          onRefresh: () => taskProvider.refreshTasks(),
          child: ListView.builder(
            itemCount: snoozedTasks.length,
            itemBuilder: (context, index) {
              final task = snoozedTasks[index];
              return _TaskListItem(task: task);
            },
          ),
        );
      },
    );
  }
}

// Task list item
class _TaskListItem extends StatelessWidget {
  final Task task;
  
  const _TaskListItem({required this.task});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    
    // Format the time range
    final timeRange = '${dateFormat.format(task.startTime)} - ${dateFormat.format(task.endTime)}';
    
    // Format last reminded time if any
    final lastRemindedText = task.lastReminded != null 
        ? 'Last reminded: ${dateFormat.format(task.lastReminded!)} at ${timeFormat.format(task.lastReminded!)}'
        : 'Never reminded';
    
    // Format snoozed until time if any
    final snoozedUntilText = task.snoozedUntil != null 
        ? 'Snoozed until: ${dateFormat.format(task.snoozedUntil!)} at ${timeFormat.format(task.snoozedUntil!)}'
        : '';
        
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
              // Task name
              Text(
                task.name,
                style: theme.textTheme.titleLarge,
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
              
              // Last reminded
              Row(
                children: [
                  const Icon(Icons.notifications, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    lastRemindedText,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              
              // Snoozed until (if applicable)
              if (task.snoozedUntil != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.snooze, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      snoozedUntilText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Actions
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Mark as done
                  TextButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Done'),
                    onPressed: () {
                      // Mark task as completed
                      context.read<TaskProvider>().completeTask(task.id);
                    },
                  ),
                  
                  // Snooze
                  TextButton.icon(
                    icon: const Icon(Icons.snooze),
                    label: const Text('Snooze'),
                    onPressed: () {
                      // Show snooze options dialog
                      _showSnoozeDialog(context, task);
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
  
  // Show snooze options dialog
  void _showSnoozeDialog(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Snooze Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('30 minutes'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<TaskProvider>().snoozeTask(
                    task.id, 
                    timeout: const Duration(minutes: 30),
                  );
                },
              ),
              ListTile(
                title: const Text('1 hour'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<TaskProvider>().snoozeTask(
                    task.id, 
                    timeout: const Duration(hours: 1),
                  );
                },
              ),
              ListTile(
                title: const Text('3 hours'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<TaskProvider>().snoozeTask(
                    task.id, 
                    timeout: const Duration(hours: 3),
                  );
                },
              ),
              ListTile(
                title: const Text('Tomorrow'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<TaskProvider>().snoozeTask(
                    task.id, 
                    timeout: const Duration(hours: 24),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}