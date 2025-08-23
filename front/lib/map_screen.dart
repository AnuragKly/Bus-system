// map_screen.dart
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
  static const String _backendUrl =
      'ws://a053d04320d7.ngrok-free.app/location'; // ✅ updated to ngrok link

  LatLng _busLocation = _defaultLocation;
  WebSocketChannel? _channel;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
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
    _connectWebSocket();
  }

  @override
  void dispose() {
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
        options: MapOptions(initialCenter: _busLocation, initialZoom: 15.0),
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
              child: const Icon(Icons.directions_bus,
                  size: 40, color: Colors.blue),
            )
          ])
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _manualReconnect,
        tooltip: "Reconnect",
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
