import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class ETAScreen extends StatefulWidget {
  const ETAScreen({super.key});

  @override
  State<ETAScreen> createState() => _ETAScreenState();
}

class _ETAScreenState extends State<ETAScreen> {
  static const String _apiUrl = 'http://localhost:8000/gps/bus-location?bus_id=ESP32_BUS_001';
  static const String _etaUrl = 'http://localhost:8000/gps/estimate-arrival';
  
  LatLng? _busLocation;
  LatLng? _userLocation;
  LatLng? _selectedDestination;
  MapController? _mapController;
  bool _isLoading = false;
  Map<String, dynamic>? _etaResult;
  String? _errorMessage;
  String _destinationName = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Popular destinations in Kathmandu
  final List<Map<String, dynamic>> _popularDestinations = [
    {'name': 'Koteshwor Traffic Police', 'lat': 27.6933, 'lon': 85.3183},
    {'name': 'New Bus Park', 'lat': 27.7172, 'lon': 85.3240},
    {'name': 'Ratna Park', 'lat': 27.7065, 'lon': 85.3135},
    {'name': 'Thamel', 'lat': 27.7152, 'lon': 85.3097},
    {'name': 'Bhaktapur Durbar Square', 'lat': 27.6724, 'lon': 85.4298},
    {'name': 'Patan Durbar Square', 'lat': 27.6744, 'lon': 85.3261},
    {'name': 'Pashupatinath Temple', 'lat': 27.7105, 'lon': 85.3482},
    {'name': 'Boudhanath Stupa', 'lat': 27.7215, 'lon': 85.3624},
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _fetchCurrentBusLocation();
    _getCurrentUserLocation();
  }

  Future<void> _getCurrentUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _errorMessage = 'Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _errorMessage = 'Location permission denied');
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to get user location: $e');
    }
  }

  Future<void> _fetchCurrentBusLocation() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _busLocation = LatLng(
            data['latitude'].toDouble(),
            data['longitude'].toDouble(),
          );
          _errorMessage = null;
        });
        
        // Center map on bus location
        if (_mapController != null && _busLocation != null) {
          _mapController!.move(_busLocation!, 13.0);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to get bus location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateETA() async {
    if (_busLocation == null || _selectedDestination == null) return;
    
    setState(() => _isLoading = true);
    try {
      final url = '$_etaUrl?destination_lat=${_selectedDestination!.latitude}&destination_lon=${_selectedDestination!.longitude}&bus_id=ESP32_BUS_001';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _etaResult = data;
          _errorMessage = null;
        });
      } else {
        setState(() => _errorMessage = 'Failed to calculate ETA');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error calculating ETA: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedDestination = point;
      _etaResult = null;
      _destinationName = 'Custom Location (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
      _searchController.text = _destinationName;
    });
    
    // Calculate ETA immediately when destination is selected
    _calculateETA();
  }

  void _selectPopularDestination(Map<String, dynamic> destination) {
    setState(() {
      _selectedDestination = LatLng(destination['lat'], destination['lon']);
      _destinationName = destination['name'];
      _searchController.text = _destinationName;
      _etaResult = null;
    });
    
    // Move map to show both bus and destination
    if (_mapController != null && _busLocation != null && _selectedDestination != null) {
      _fitMapToBounds();
    }
    
    _calculateETA();
  }

  void _fitMapToBounds() {
    if (_busLocation == null || _selectedDestination == null) return;
    
    double minLat = [_busLocation!.latitude, _selectedDestination!.latitude].reduce((a, b) => a < b ? a : b);
    double maxLat = [_busLocation!.latitude, _selectedDestination!.latitude].reduce((a, b) => a > b ? a : b);
    double minLon = [_busLocation!.longitude, _selectedDestination!.longitude].reduce((a, b) => a < b ? a : b);
    double maxLon = [_busLocation!.longitude, _selectedDestination!.longitude].reduce((a, b) => a > b ? a : b);
    
    LatLng center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
    double zoom = 12.0; // Adjust based on distance
    
    _mapController!.move(center, zoom);
  }

  void _clearDestination() {
    setState(() {
      _selectedDestination = null;
      _etaResult = null;
      _destinationName = '';
      _searchController.clear();
    });
  }

  void _centerOnBus() {
    if (_mapController != null && _busLocation != null) {
      _mapController!.move(_busLocation!, 15.0);
    }
  }

  void _centerOnUser() {
    if (_mapController != null && _userLocation != null) {
      _mapController!.move(_userLocation!, 15.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus ETA Calculator'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnUser,
            tooltip: 'Center on My Location',
          ),
          IconButton(
            icon: const Icon(Icons.directions_bus),
            onPressed: _centerOnBus,
            tooltip: 'Center on Bus',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCurrentBusLocation,
            tooltip: 'Refresh Bus Location',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar for Destinations
          Container(
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search or enter destination name...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearDestination,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) {
                    setState(() => _destinationName = value);
                  },
                ),
                
                // Popular Destinations
                const SizedBox(height: 12),
                Container(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _popularDestinations.length,
                    itemBuilder: (context, index) {
                      final dest = _popularDestinations[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ElevatedButton(
                          onPressed: () => _selectPopularDestination(dest),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Text(
                            dest['name'],
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Map with improved zoom controls
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _busLocation ?? const LatLng(27.7172, 85.3240),
                    initialZoom: 13.0,
                    minZoom: 8.0,   // Allow zooming out more
                    maxZoom: 18.0,  // Allow zooming in more
                    onTap: _onMapTap,
                    // Enable better zoom controls
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.bus_tracker',
                    ),
                    MarkerLayer(
                      markers: [
                        // Bus marker (red)
                        if (_busLocation != null)
                          Marker(
                            point: _busLocation!,
                            width: 60,
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.directions_bus,
                                size: 30,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        
                        // User location marker (blue)
                        if (_userLocation != null)
                          Marker(
                            point: _userLocation!,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.person_pin_circle,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        
                        // Destination marker (green)
                        if (_selectedDestination != null)
                          Marker(
                            point: _selectedDestination!,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on,
                                size: 25,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // ETA Results
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              child: _buildETAResults(),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Zoom Controls
          FloatingActionButton(
            mini: true,
            heroTag: "zoom_in",
            onPressed: () {
              if (_mapController != null) {
                _mapController!.move(
                  _mapController!.camera.center,
                  _mapController!.camera.zoom + 1,
                );
              }
            },
            backgroundColor: Colors.white,
            child: const Icon(Icons.zoom_in, color: Colors.black),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            heroTag: "zoom_out",
            onPressed: () {
              if (_mapController != null) {
                _mapController!.move(
                  _mapController!.camera.center,
                  _mapController!.camera.zoom - 1,
                );
              }
            },
            backgroundColor: Colors.white,
            child: const Icon(Icons.zoom_out, color: Colors.black),
          ),
          const SizedBox(height: 16),
          
          // Clear destination button
          if (_selectedDestination != null)
            FloatingActionButton(
              heroTag: "clear",
              onPressed: _clearDestination,
              backgroundColor: Colors.red,
              child: const Icon(Icons.clear, color: Colors.white),
              tooltip: 'Clear Destination',
            ),
        ],
      ),
    );
  }

  Widget _buildETAResults() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Calculating ETA...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_selectedDestination == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Tap on the map to select your destination',
              style: TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_etaResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ETA Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.access_time, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimated Arrival Time',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_etaResult!['estimated_arrival_minutes']?.toStringAsFixed(0)} minutes',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          
          // Route Details
          Row(
            children: [
              Icon(Icons.straighten, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text(
                'Distance: ${_etaResult!['distance_km']?.toStringAsFixed(1)} km',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Icon(
                Icons.traffic,
                color: _getTrafficColor(_etaResult!['traffic_factor'] ?? 1.0),
              ),
              const SizedBox(width: 8),
              Text(
                'Traffic: ${_getTrafficStatus(_etaResult!['traffic_factor'] ?? 1.0)}',
                style: TextStyle(
                  fontSize: 14,
                  color: _getTrafficColor(_etaResult!['traffic_factor'] ?? 1.0),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Icon(Icons.update, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'Last updated: ${_etaResult!['last_updated'] ?? 'Unknown'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTrafficColor(double factor) {
    if (factor > 1.3) return Colors.red;
    if (factor > 1.1) return Colors.orange;
    if (factor < 0.9) return Colors.green;
    return Colors.blue;
  }

  String _getTrafficStatus(double factor) {
    if (factor > 1.3) return "Heavy Traffic";
    if (factor > 1.1) return "Light Traffic";
    if (factor < 0.9) return "Fast Route";
    return "Normal Traffic";
  }
}
