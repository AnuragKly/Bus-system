import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/auth_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng busLocation = const LatLng(27.6193, 85.5362); // Kathmandu University default
  late WebSocketChannel? channel;
  final MapController _mapController = MapController();
  bool _isConnected = false;
  String _connectionStatus = 'Connecting...';
  DateTime? _lastUpdate;
  String? _busId;

  @override
  void initState() {
    super.initState();
    _initializeConnection();
  }

  Future<void> _initializeConnection() async {
    try {
      // Get current user's bus ID
      final authService = AuthService();
      _busId = await authService.getStoredUserId();
      
      // Connect to WebSocket for real-time updates
      _connectWebSocket();
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection failed: $e';
      });
    }
  }

  void _connectWebSocket() {
    try {
      // Update WebSocket URL to match your backend
      const wsUrl = 'ws://localhost:8002/ws/location';
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      channel!.stream.listen(
        (message) {
          try {
            final decoded = jsonDecode(message);
            if (decoded["type"] == "location_update" && decoded["data"] != null) {
              final lat = decoded["data"]["latitude"];
              final lng = decoded["data"]["longitude"];
              final busId = decoded["data"]["bus_id"];
              
              if (lat != null && lng != null) {
                setState(() {
                  busLocation = LatLng(lat.toDouble(), lng.toDouble());
                  _isConnected = true;
                  _connectionStatus = 'Live tracking: $busId';
                  _lastUpdate = DateTime.now();
                });
                
                // Auto-center map on new location
                _mapController.move(busLocation, _mapController.zoom);
              }
            }
          } catch (e) {
            debugPrint('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          setState(() {
            _isConnected = false;
            _connectionStatus = 'Connection error';
          });
        },
        onDone: () {
          setState(() {
            _isConnected = false;
            _connectionStatus = 'Connection closed';
          });
        },
      );
    } catch (e) {
      setState(() {
        _connectionStatus = 'Failed to connect: $e';
      });
    }
  }

  void _centerOnBus() {
    _mapController.move(busLocation, 16);
  }

  String _formatLastUpdate() {
    if (_lastUpdate == null) return 'No updates';
    final diff = DateTime.now().difference(_lastUpdate!);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  void dispose() {
    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺️ Live Bus Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnBus,
            tooltip: 'Center on bus',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _connectWebSocket,
            tooltip: 'Reconnect',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: busLocation,
              zoom: 15,
              minZoom: 10,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.nepalbus.tracker',
                maxNativeZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  // Bus marker
                  Marker(
                    point: busLocation,
                    width: 60,
                    height: 60,
                    builder: (context) => Container(
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.blue : Colors.grey,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isConnected ? Colors.blue : Colors.grey).withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_bus,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  
                  // Nepal landmarks for reference
                  Marker(
                    point: const LatLng(27.7172, 85.3240), // Kathmandu
                    width: 40,
                    height: 40,
                    builder: (context) => Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_city,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Bus route circle (approx area)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: busLocation,
                    radius: 100, // meters
                    useRadiusInMeter: true,
                    color: Colors.blue.withOpacity(0.1),
                    borderColor: Colors.blue.withOpacity(0.3),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            ],
          ),

          // Connection status banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _isConnected ? Colors.green : Colors.orange,
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectionStatus,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  Text(
                    _formatLastUpdate(),
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),

          // Bus info card
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.directions_bus,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _busId ?? 'Bus Tracker',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Lat: ${busLocation.latitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                'Lng: ${busLocation.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _centerOnBus,
                            icon: const Icon(Icons.my_location, size: 16),
                            label: const Text('Center'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _connectWebSocket,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
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
        ],
      ),
    );
  }
}
