import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _defaultLocation = LatLng(27.6193, 85.5362);
  static const String _backendUrl = 'ws://10.0.2.2:8000/ws/location';
  static const Duration _reconnectDelay = Duration(seconds: 3);

  LatLng _busLocation = _defaultLocation;
  WebSocketChannel? _channel;
  StreamSubscription? _webSocketSubscription;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      // Close existing connection if any
      _disposeWebSocket();

      _channel = WebSocketChannel.connect(Uri.parse(_backendUrl));
      _isConnected = true;
      _reconnectAttempts = 0;

      _webSocketSubscription = _channel!.stream.listen(
        _handleWebSocketMessage,
        onDone: _onWebSocketDone,
        onError: _onWebSocketError,
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      _scheduleReconnect();
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message);

      // Only process location updates
      if (decoded["type"] == "location_update" && decoded["data"] != null) {
        final data = decoded["data"];
        final double? lat = data["latitude"];
        final double? lon = data["longitude"];

        if (lat != null && lon != null) {
          // Use filtered coordinates if available, otherwise use raw
          final bool useFiltered = data["filtered"] == true;
          final double finalLat =
              useFiltered ? (data["filtered_latitude"] ?? lat) : lat;
          final double finalLon =
              useFiltered ? (data["filtered_longitude"] ?? lon) : lon;

          // Update state only if location has changed
          if (_busLocation.latitude != finalLat ||
              _busLocation.longitude != finalLon) {
            setState(() {
              _busLocation = LatLng(finalLat, finalLon);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }

  void _onWebSocketDone() {
    debugPrint('WebSocket closed');
    _isConnected = false;
    _scheduleReconnect();
  }

  void _onWebSocketError(Object error) {
    debugPrint('WebSocket error: $error');
    _isConnected = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Max reconnection attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectAttempts++;
      _connectWebSocket();
    });
  }

  void _disposeWebSocket() {
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;

    _channel?.sink.close();
    _channel = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _manualReconnect() {
    setState(() {
      _isConnected = false;
      _reconnectAttempts = 0;
    });
    _connectWebSocket();
  }

  @override
  void dispose() {
    _disposeWebSocket();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Bus Map"),
        actions: [
          Icon(
            _isConnected ? Icons.wifi : Icons.wifi_off,
            color: _isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 16)
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _busLocation,
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.bus_tracker',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _busLocation,
                width: 50.0,
                height: 50.0,
                child: Icon(
                  Icons.directions_bus,
                  size: 40.0,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _manualReconnect,
        tooltip: 'Reconnect',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
