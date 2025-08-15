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
  LatLng busLocation = LatLng(27.6193, 85.5362); // default fallback
  late WebSocketChannel channel;

  final String backendUrl = 'ws://10.0.2.2:8000/ws/location';
  // Change host if running on real device (use your LAN IP)

  @override
  void initState() {
    super.initState();
    channel = WebSocketChannel.connect(Uri.parse(backendUrl));

    channel.stream.listen((message) {
      try {
        final decoded = jsonDecode(message);
        if (decoded["type"] == "location_update" && decoded["data"] != null) {
          final lat = decoded["data"]["latitude"];
          final lon = decoded["data"]["longitude"];
          if (lat != null && lon != null) {
            setState(() {
              busLocation = LatLng(lat, lon);
            });
          }
        }
      } catch (e) {
        debugPrint('Error parsing WebSocket message: $e');
      }
    });
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Bus Map")),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: busLocation,
          initialZoom: 15,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.front',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: busLocation,
                width: 40,
                height: 40,
                child: Image.asset(
                  'assets/bus.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
