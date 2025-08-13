import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng busLocation = LatLng(27.6193, 85.5362); // Default location
  Timer? _timer;

  final String backendUrl =
      'http://192.168.1.5:8000/gps/bus-location?bus_id=bus_001';

  @override
  void initState() {
    super.initState();
    fetchBusLocation();
    // Refresh every 10 seconds for live update
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      fetchBusLocation();
    });
  }

  Future<void> fetchBusLocation() async {
    try {
      final response = await http.get(Uri.parse(backendUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          busLocation = LatLng(data['latitude'], data['longitude']);
        });
      } else {
        debugPrint('Failed to fetch bus location: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching bus location: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
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
