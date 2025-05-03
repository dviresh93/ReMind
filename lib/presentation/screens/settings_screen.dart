// lib/presentation/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/monitor_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings keys
  static const String _enableBackgroundServiceKey = 'enable_background_service';
  static const String _proximityRadiusKey = 'default_proximity_radius';
  static const String _defaultSnoozeTimeKey = 'default_snooze_time';
  
  // Default values
  static const bool _defaultEnableBackgroundService = true;
  static const double _defaultProximityRadius = 100.0;
  static const int _defaultSnoozeTime = 60; // minutes
  
  // Current values
  bool _enableBackgroundService = _defaultEnableBackgroundService;
  double _proximityRadius = _defaultProximityRadius;
  int _snoozeTime = _defaultSnoozeTime;
  
  // Loading state
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _enableBackgroundService = prefs.getBool(_enableBackgroundServiceKey) ?? _defaultEnableBackgroundService;
      _proximityRadius = prefs.getDouble(_proximityRadiusKey) ?? _defaultProximityRadius;
      _snoozeTime = prefs.getInt(_defaultSnoozeTimeKey) ?? _defaultSnoozeTime;
      _isLoading = false;
    });
  }
  
  // Save a setting
  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return ListView(
      children: [
        // Background Service
        SwitchListTile(
          title: const Text('Enable Background Service'),
          subtitle: const Text('Allows ReMind to monitor your location and notify you about nearby tasks'),
          value: _enableBackgroundService,
          onChanged: (value) async {
            setState(() {
              _enableBackgroundService = value;
            });
            
            await _saveSetting(_enableBackgroundServiceKey, value);
            
            final monitorService = context.read<MonitorService>();
            if (value) {
              await monitorService.startService();
            } else {
              await monitorService.stopService();
            }
          },
        ),
        
        const Divider(),
        
        // Default Proximity Radius
        ListTile(
          title: const Text('Default Proximity Radius'),
          subtitle: Text('${_proximityRadius.toInt()} meters'),
          trailing: const Icon(Icons.edit),
          onTap: () {
            _showProximityRadiusDialog();
          },
        ),
        
        // Default Snooze Time
        ListTile(
          title: const Text('Default Snooze Time'),
          subtitle: Text('${_snoozeTime} minutes'),
          trailing: const Icon(Icons.edit),
          onTap: () {
            _showSnoozeTimeDialog();
          },
        ),
        
        const Divider(),
        
        // About Section
        const ListTile(
          title: Text('About'),
          subtitle: Text('ReMind - Location-based Reminder App'),
        ),
        
        // Version
        const ListTile(
          title: Text('Version'),
          subtitle: Text('1.0.0'),
        ),
      ],
    );
  }
  
  // Show dialog to change proximity radius
  void _showProximityRadiusDialog() {
    double newRadius = _proximityRadius;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Default Proximity Radius'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Distance in meters to detect tasks'),
              const SizedBox(height: 16),
              Slider(
                value: newRadius,
                min: 50,
                max: 500,
                divisions: 9,
                label: '${newRadius.toInt()} m',
                onChanged: (value) {
                  newRadius = value;
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
            TextButton(
              onPressed: () async {
                await _saveSetting(_proximityRadiusKey, newRadius);
                setState(() {
                  _proximityRadius = newRadius;
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
  
  // Show dialog to change default snooze time
  void _showSnoozeTimeDialog() {
    int newSnoozeTime = _snoozeTime;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Default Snooze Time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Time in minutes'),
              const SizedBox(height: 16),
              DropdownButton<int>(
                value: newSnoozeTime,
                onChanged: (value) {
                  if (value != null) {
                    newSnoozeTime = value;
                  }
                },
                items: [
                  const DropdownMenuItem(
                    value: 15,
                    child: Text('15 minutes'),
                  ),
                  const DropdownMenuItem(
                    value: 30,
                    child: Text('30 minutes'),
                  ),
                  const DropdownMenuItem(
                    value: 60,
                    child: Text('1 hour'),
                  ),
                  const DropdownMenuItem(
                    value: 180,
                    child: Text('3 hours'),
                  ),
                  const DropdownMenuItem(
                    value: 1440,
                    child: Text('1 day'),
                  ),
                ],
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
            TextButton(
              onPressed: () async {
                await _saveSetting(_defaultSnoozeTimeKey, newSnoozeTime);
                setState(() {
                  _snoozeTime = newSnoozeTime;
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}