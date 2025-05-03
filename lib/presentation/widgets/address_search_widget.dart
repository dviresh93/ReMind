// lib/presentation/widgets/address_search_widget.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/location_helper.dart';

class AddressSearchWidget extends StatefulWidget {
  final Function(String name, LatLng location) onLocationSelected;
  
  const AddressSearchWidget({
    Key? key,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  State<AddressSearchWidget> createState() => _AddressSearchWidgetState();
}

class _AddressSearchWidgetState extends State<AddressSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final LocationHelper _locationHelper = LocationHelper();
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Search for locations
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    
    setState(() {
      _isSearching = true;
    });
    
    try {
      final results = await _locationHelper.searchLocations(query);
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search for a location',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = [];
                      });
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            _searchLocation(value);
          },
        ),
        
        const SizedBox(height: 8),
        
        // Loading indicator
        if (_isSearching)
          const Center(
            child: CircularProgressIndicator(),
          ),
          
        // Search results
        if (_searchResults.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return ListTile(
                  title: Text(
                    result['name'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${result['lat'].toStringAsFixed(4)}, ${result['lon'].toStringAsFixed(4)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    // Get the selected location details
                    final name = result['name'];
                    final lat = result['lat'];
                    final lon = result['lon'];
                    
                    // Pass back to parent
                    widget.onLocationSelected(
                      name,
                      LatLng(lat, lon),
                    );
                    
                    // Clear results
                    setState(() {
                      _searchResults = [];
                      _searchController.clear();
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}