// lib/domain/entities/task.dart

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

enum TaskStatus {
  pending,    // Never been reminded
  snoozed,    // Reminded but snoozed
  completed,  // Marked as done
}

class Task {
  final String id;
  final String name;
  final String description;
  final LatLng location;
  final String locationName;
  final double proximityRadius; // in meters
  final DateTime startTime;
  final DateTime endTime;
  final TaskStatus status;
  final DateTime? lastReminded;
  final DateTime? snoozedUntil;

  Task({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.locationName,
    this.proximityRadius = 100.0, // Default proximity radius is 100 meters
    required this.startTime,
    required this.endTime,
    this.status = TaskStatus.pending,
    this.lastReminded,
    this.snoozedUntil,
  });

  // Create a copy of this task with given fields replaced with new values
  Task copyWith({
    String? id,
    String? name,
    String? description,
    LatLng? location,
    String? locationName,
    double? proximityRadius,
    DateTime? startTime,
    DateTime? endTime,
    TaskStatus? status,
    DateTime? lastReminded,
    DateTime? snoozedUntil,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      locationName: locationName ?? this.locationName,
      proximityRadius: proximityRadius ?? this.proximityRadius,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      lastReminded: lastReminded ?? this.lastReminded,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
    );
  }

  // Mark task as completed
  Task markAsCompleted() {
    return copyWith(
      status: TaskStatus.completed,
      lastReminded: DateTime.now(),
    );
  }

  // Mark task as snoozed with a timeout period
  Task snooze({Duration timeout = const Duration(hours: 1)}) {
    return copyWith(
      status: TaskStatus.snoozed,
      lastReminded: DateTime.now(),
      snoozedUntil: DateTime.now().add(timeout),
    );
  }

  // Check if task is active (not completed and not currently snoozed)
  bool isActive() {
    if (status == TaskStatus.completed) return false;
    if (status == TaskStatus.snoozed && snoozedUntil != null && DateTime.now().isBefore(snoozedUntil!)) return false;
    return true;
  }

  // Check if a task is valid for the current time
  bool isValidForTime(DateTime currentTime) {
    return currentTime.isAfter(startTime) && currentTime.isBefore(endTime);
  }

  // Convert to a Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'locationName': locationName,
      'proximityRadius': proximityRadius,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'status': status.index,
      'lastReminded': lastReminded?.millisecondsSinceEpoch,
      'snoozedUntil': snoozedUntil?.millisecondsSinceEpoch,
    };
  }

  // Create a Task from a Map
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      location: LatLng(map['latitude'], map['longitude']),
      locationName: map['locationName'],
      proximityRadius: map['proximityRadius'],
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime']),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime']),
      status: TaskStatus.values[map['status']],
      lastReminded: map['lastReminded'] != null ? DateTime.fromMillisecondsSinceEpoch(map['lastReminded']) : null,
      snoozedUntil: map['snoozedUntil'] != null ? DateTime.fromMillisecondsSinceEpoch(map['snoozedUntil']) : null,
    );
  }
}