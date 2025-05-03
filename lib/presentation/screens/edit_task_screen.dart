// lib/presentation/screens/edit_task_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import '../../core/services/location_service.dart';

class EditTaskScreen extends StatefulWidget {
  final Task? task; // Null if adding a new task
  
  const EditTaskScreen({
    Key? key,
    this.task,
  }) : super(key: key);

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationNameController;
  
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _endTime = TimeOfDay.now();
  
  double _proximityRadius = 100.0; // Default radius in meters
  LatLng _location = LatLng(0, 0); // Default location (will be updated)
  
  MapController _mapController = MapController();
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    _nameController = TextEditingController(text: widget.task?.name ?? '');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');
    _locationNameController = TextEditingController(text: widget.task?.locationName ?? '');
    
    // Initialize dates and times if editing
    if (widget.task != null) {
      _startDate = widget.task!.startTime;
      _startTime = TimeOfDay.fromDateTime(widget.task!.startTime);
      _endDate = widget.task!.endTime;
      _endTime = TimeOfDay.fromDateTime(widget.task!.endTime);
      _proximityRadius = widget.task!.proximityRadius;
      _location = widget.task!.location;
    } else {
      // For new tasks, get default proximity radius from settings
      _loadDefaultProximityRadius();
      // Get current location
      _getCurrentLocation();
    }
    
    // Initialize map controller
    _mapController = MapController();
  }
  
  // Load default proximity radius from settings
  Future<void> _loadDefaultProximityRadius() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _proximityRadius = prefs.getDouble('default_proximity_radius') ?? 100.0;
    });
  }
  
  // Get current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _location = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      
      // Center map on current location
      _mapController.move(_location, 14.0);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to get current location. Please select location manually.'),
        ),
      );
    }
  }
  
  @override
  void dispose() {
    // Properly dispose controllers
    _nameController.dispose();
    _descriptionController.dispose();
    _locationNameController.dispose();
    
    // Also dispose the map controller
    if (_mapController is Disposable) {
      (_mapController as Disposable).dispose();
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Add Task' : 'Edit Task'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(context),
    );
  }
  
  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Task Name
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Task Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a task name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Location Name
          TextFormField(
            controller: _locationNameController,
            decoration: const InputDecoration(
              labelText: 'Location Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a location name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Map for location selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap on the map to select a location',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: _buildMap(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use Current Location'),
                    onPressed: _getCurrentLocation,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Proximity Radius Slider
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Proximity Radius',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Distance in meters to notify you when nearby (${_proximityRadius.toInt()} meters)',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Slider(
                    value: _proximityRadius,
                    min: 50,
                    max: 500,
                    divisions: 9,
                    label: '${_proximityRadius.toInt()} m',
                    onChanged: (value) {
                      setState(() {
                        _proximityRadius = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Date and Time Ranges
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Time Range',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Start Date
                  ListTile(
                    title: const Text('Start Date'),
                    subtitle: Text(
                      DateFormat('MMM d, yyyy').format(_startDate),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () {
                      _selectStartDate(context);
                    },
                  ),
                  
                  // Start Time
                  ListTile(
                    title: const Text('Start Time'),
                    subtitle: Text(_startTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () {
                      _selectStartTime(context);
                    },
                  ),
                  
                  const Divider(),
                  
                  // End Date
                  ListTile(
                    title: const Text('End Date'),
                    subtitle: Text(
                      DateFormat('MMM d, yyyy').format(_endDate),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () {
                      _selectEndDate(context);
                    },
                  ),
                  
                  // End Time
                  ListTile(
                    title: const Text('End Time'),
                    subtitle: Text(_endTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () {
                      _selectEndTime(context);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Save Button
          ElevatedButton(
            onPressed: () {
              _saveTask();
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(
              widget.task == null ? 'Add Task' : 'Save Changes',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
  
  // Build map widget for location selection
  Widget _buildMap() {
    return SizedBox(
      height: 300,
      child: FlutterMap(
        options: MapOptions(
          center: _location,
          zoom: 15,
          onTap: (_, point) => _updateLocation(point),
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
                point: _location,
                builder: (ctx) => const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
          CircleLayer(
            circles: [
              CircleMarker(
                point: _location,
                radius: _proximityRadius,
                color: Colors.blue.withOpacity(0.3),
                borderColor: Colors.blue,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Select start date
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        
        // Ensure end date is not before start date
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }
  
  // Select start time
  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
      });
    }
  }
  
  // Select end date
  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: _startDate.add(const Duration(days: 365)),
    );
    
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }
  
  // Select end time
  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    
    if (picked != null && picked != _endTime) {
      setState(() {
        _endTime = picked;
      });
    }
  }
  
  // Combine date and time into DateTime
  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }
  
  // Save task
  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      // Validate dates more thoroughly
      final now = DateTime.now();
      final startDateTime = _combineDateTime(_startDate, _startTime);
      final endDateTime = _combineDateTime(_endDate, _endTime);
      
      // Check if start time is in the past for new tasks
      if (widget.task == null && startDateTime.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Start time cannot be in the past for new tasks'),
          ),
        );
        return;
      }
      
      // Check if end time is after start time
      if (endDateTime.isBefore(startDateTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End time must be after start time'),
          ),
        );
        return;
      }
      
      // Validate proximity radius
      if (_proximityRadius < 50 || _proximityRadius > 500) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proximity radius must be between 50 and 500 meters'),
          ),
        );
        return;
      }
      
      // Create or update task
      final Task task = widget.task == null
          ? Task(
              id: const Uuid().v4(),
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              location: _location,
              locationName: _locationNameController.text.trim(),
              proximityRadius: _proximityRadius,
              startTime: startDateTime,
              endTime: endDateTime,
            )
          : widget.task!.copyWith(
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              location: _location,
              locationName: _locationNameController.text.trim(),
              proximityRadius: _proximityRadius,
              startTime: startDateTime,
              endTime: endDateTime,
            );
      
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });
      
      // Save to repository with error handling
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      
      Future<void> saveOperation;
      if (widget.task == null) {
        saveOperation = taskProvider.addTask(task);
      } else {
        saveOperation = taskProvider.updateTask(task);
      }
      
      saveOperation.then((_) {
        Navigator.pop(context);
      }).catchError((error) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save task: $error'),
          ),
        );
      });
    }
  }
}