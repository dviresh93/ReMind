// lib/presentation/screens/task_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import 'edit_task_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  
  const TaskDetailScreen({
    Key? key,
    required this.taskId,
  }) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Task? _task;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadTask();
  }
  
  // Load task details
  Future<void> _loadTask() async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final task = await taskProvider.getTaskById(widget.taskId);
    
    setState(() {
      _task = task;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Task Details'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_task == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Task Details'),
        ),
        body: const Center(
          child: Text('Task not found'),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditTaskScreen(task: _task!),
                ),
              ).then((_) => _loadTask());
            },
          ),
        ],
      ),
      body: _buildTaskDetailsBody(context),
    );
  }
  
  Widget _buildTaskDetailsBody(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Task Name
        Text(
          _task!.name,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        
        // Status Chip
        _buildStatusChip(),
        const SizedBox(height: 16),
        
        // Description
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(_task!.description),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Location
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_task!.locationName),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Proximity Radius: ${_task!.proximityRadius.toInt()} meters',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _buildMap(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Time Range
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time Range',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 8),
                    Text('Start: ${dateFormat.format(_task!.startTime)}'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time),
                    const SizedBox(width: 8),
                    Text('Time: ${timeFormat.format(_task!.startTime)}'),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 8),
                    Text('End: ${dateFormat.format(_task!.endTime)}'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time),
                    const SizedBox(width: 8),
                    Text('Time: ${timeFormat.format(_task!.endTime)}'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Reminder History
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminder History',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_task!.lastReminded != null)
                  Row(
                    children: [
                      const Icon(Icons.notifications),
                      const SizedBox(width: 8),
                      Text(
                        'Last Reminded: ${dateFormat.format(_task!.lastReminded!)} at ${timeFormat.format(_task!.lastReminded!)}',
                      ),
                    ],
                  )
                else
                  const Text('Never reminded'),
                
                if (_task!.status == TaskStatus.snoozed && _task!.snoozedUntil != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.snooze),
                      const SizedBox(width: 8),
                      Text(
                        'Snoozed until: ${dateFormat.format(_task!.snoozedUntil!)} at ${timeFormat.format(_task!.snoozedUntil!)}',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Action Buttons
        _buildActionButtons(context),
      ],
    );
  }
  
  // Build status chip based on task status
  Widget _buildStatusChip() {
    // Determine color and label based on status
    Color chipColor;
    String statusLabel;
    
    switch (_task!.status) {
      case TaskStatus.pending:
        chipColor = Colors.blue;
        statusLabel = 'Active';
        break;
      case TaskStatus.snoozed:
        chipColor = Colors.orange;
        statusLabel = 'Snoozed';
        break;
      case TaskStatus.completed:
        chipColor = Colors.green;
        statusLabel = 'Completed';
        break;
    }
    
    return Chip(
      label: Text(statusLabel),
      backgroundColor: chipColor.withOpacity(0.2),
      labelStyle: TextStyle(color: chipColor),
      avatar: Icon(
        _getStatusIcon(),
        color: chipColor,
        size: 18,
      ),
    );
  }
  
  // Get icon for task status
  IconData _getStatusIcon() {
    switch (_task!.status) {
      case TaskStatus.pending:
        return Icons.pending_actions;
      case TaskStatus.snoozed:
        return Icons.snooze;
      case TaskStatus.completed:
        return Icons.check_circle;
    }
  }
  
  // Build map widget to display task location
  Widget _buildMap() {
    return SizedBox(
      height: 300,
      child: FlutterMap(
        options: MapOptions(
          center: _task!.location,
          zoom: 15,
          interactiveFlags: InteractiveFlag.none,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: const ['a', 'b', 'c'],
            errorTileCallback: (tile, error) {
              print('Error loading map tile: $error');
              // Optionally show a fallback tile or error message
            },
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _task!.location,
                builder: (ctx) => const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Build action buttons based on task status
  Widget _buildActionButtons(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    
    if (_task!.status == TaskStatus.completed) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _showDeleteConfirmationDialog(context),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.restore),
            label: const Text('Restore'),
            onPressed: () {
              final updatedTask = _task!.copyWith(
                status: TaskStatus.pending,
                lastReminded: null,
                snoozedUntil: null,
              );
              taskProvider.updateTask(updatedTask).then((_) {
                Navigator.pop(context);
              });
            },
          ),
        ],
      );
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.check_circle),
          label: const Text('Mark Done'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            taskProvider.completeTask(_task!.id).then((_) {
              Navigator.pop(context);
            });
          },
        ),
        if (_task!.status != TaskStatus.snoozed)
          ElevatedButton.icon(
            icon: const Icon(Icons.snooze),
            label: const Text('Snooze'),
            onPressed: () => _showSnoozeDialog(context),
          ),
      ],
    );
  }
  
  // Show delete confirmation dialog
  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: Text('Are you sure you want to delete "${_task!.name}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final taskProvider = Provider.of<TaskProvider>(
                  context, 
                  listen: false,
                );
                
                Navigator.pop(context); // Close dialog
                taskProvider.deleteTask(_task!.id).then((_) {
                  Navigator.pop(context); // Go back to previous screen
                });
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
  
  // Show snooze options dialog
  void _showSnoozeDialog(BuildContext context) {
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
                  _snoozeTask(const Duration(minutes: 30));
                },
              ),
              ListTile(
                title: const Text('1 hour'),
                onTap: () {
                  Navigator.pop(context);
                  _snoozeTask(const Duration(hours: 1));
                },
              ),
              ListTile(
                title: const Text('3 hours'),
                onTap: () {
                  Navigator.pop(context);
                  _snoozeTask(const Duration(hours: 3));
                },
              ),
              ListTile(
                title: const Text('Tomorrow'),
                onTap: () {
                  Navigator.pop(context);
                  _snoozeTask(const Duration(hours: 24));
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
  
  // Snooze the task
  void _snoozeTask(Duration timeout) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    taskProvider.snoozeTask(_task!.id, timeout: timeout).then((_) {
      _loadTask(); // Refresh task data
    });
  }
}