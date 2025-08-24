// map_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  static const LatLng _defaultLocation = LatLng(27.6193, 85.5362);
  static const String _backendUrl = 'ws://localhost:8000/ws/location';
  static const String _apiUrl = 'http://localhost:8000/gps/bus-location?bus_id=ESP32_BUS_001';

  LatLng _busLocation = _defaultLocation;
  WebSocketChannel? _channel;
  bool _isConnected = false;
  MapController? _mapController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
    
    _fetchLatestLocation();
    _connectWebSocket();
  }

  Future<void> _fetchLatestLocation() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['latitude'] != null && data['longitude'] != null) {
          setState(() {
            _busLocation = LatLng(
              data['latitude'].toDouble(),
              data['longitude'].toDouble(),
            );
          });
          debugPrint('Fetched latest location: $_busLocation');
          _centerMapOnBus();
        }
      }
    } catch (e) {
      debugPrint('Error fetching latest location: $e');
    }
  }

  void _centerMapOnBus() {
    if (_mapController != null) {
      _mapController!.move(_busLocation, 16.0);
    }
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_backendUrl));
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          try {
            final decoded = jsonDecode(message);
            if (decoded["type"] == "location_update" &&
                decoded["data"] != null) {
              final data = decoded["data"];
              final lat = data["latitude"]?.toDouble();
              final lon = data["longitude"]?.toDouble();
              if (lat != null && lon != null) {
                setState(() => _busLocation = LatLng(lat, lon));
                _centerMapOnBus(); // Auto-center on new location
                debugPrint('Updated bus location: $_busLocation');
              }
            }
          } catch (e) {
            debugPrint("Error parsing WS message: $e");
          }
        },
        onError: (_) => setState(() => _isConnected = false),
        onDone: () => setState(() => _isConnected = false),
      );
    } catch (e) {
      debugPrint("WebSocket error: $e");
      setState(() => _isConnected = false);
    }
  }

  void _manualReconnect() {
    _channel?.sink.close();
    _fetchLatestLocation();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Bus Map"),
        actions: [
          Icon(_isConnected ? Icons.wifi : Icons.wifi_off,
              color: _isConnected ? Colors.green : Colors.red),
          const SizedBox(width: 16),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _busLocation, 
          initialZoom: 15.0,
          minZoom: 8.0,   // Allow zooming out more
          maxZoom: 18.0,  // Allow zooming in more
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
          MarkerLayer(markers: [
            Marker(
              point: _busLocation,
              width: 50,
              height: 50,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer pulse ring for visibility
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withOpacity(0.2),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.6),
                              width: 2,
                            ),
                          ),
                        ),
                        // Main bus icon
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.shade700,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_bus,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        // Direction indicator (yellow dot)
                        Positioned(
                          top: 2,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.yellow,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          ])
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
          
          // Center on bus button
          FloatingActionButton(
            heroTag: "center",
            onPressed: _centerMapOnBus,
            tooltip: "Center on Bus",
            backgroundColor: Colors.blue,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
          const SizedBox(height: 10),
          // Refresh/reconnect button
          FloatingActionButton(
            heroTag: "refresh",
            onPressed: _manualReconnect,
            tooltip: "Refresh Location",
            backgroundColor: Colors.green,
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
