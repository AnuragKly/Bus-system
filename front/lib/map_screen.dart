import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock bus location (e.g., Kathmandu University)
    LatLng busLocation = LatLng(27.6193, 85.5362);

    return Scaffold(
      appBar: AppBar(title: const Text("Live Bus Map")),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: busLocation,
          initialZoom: 15, // Zoom in more
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
                  'assets/bus.png', // your PNG file
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
