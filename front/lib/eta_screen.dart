// eta_screen.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ETAScreen extends StatefulWidget {
  const ETAScreen({super.key});

  @override
  State<ETAScreen> createState() => _ETAScreenState();
}

class _ETAScreenState extends State<ETAScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _etaData = [];
  Timer? _refreshTimer;
  String _selectedBusId = 'bus_001';
  DateTime? _lastUpdated;

  // Available buses
  final List<Map<String, String>> _buses = [
    {"id": "bus_001", "name": "Campus Shuttle"},
    {"id": "bus_002", "name": "KU to Kathmandu"},
    {"id": "bus_003", "name": "KU to Dhulikhel"},
  ];

  // Fixed stops
  final List<Map<String, dynamic>> _stops = [
    {"stop": "Main Gate", "lat": 27.6198, "lon": 85.5380},
    {"stop": "Hostel", "lat": 27.6185, "lon": 85.5405},
    {"stop": "KU Central", "lat": 27.6210, "lon": 85.5355},
  ];

  // ✅ updated to ngrok URL instead of 10.0.2.2
  final String _baseUrl = 'https://a053d04320d7.ngrok-free.app/';

  @override
  void initState() {
    super.initState();
    _fetchAllETAs();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchAllETAs();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAllETAs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait(
        _stops.map((stop) => _fetchETAForStop(stop)),
      );

      if (mounted) {
        setState(() {
          _etaData = results;
          _isLoading = false;
          _hasError = false;
          _lastUpdated = DateTime.now();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _fetchETAForStop(
      Map<String, dynamic> stop) async {
    try {
      final uri = Uri.parse(
          '$_baseUrl?destination_lat=${stop["lat"]}&destination_lon=${stop["lon"]}&bus_id=$_selectedBusId');

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "stop": stop["stop"],
          "eta": data["estimated_arrival_minutes"],
          "base_eta": data["base_eta_minutes"],
          "traffic_adjusted_eta": data["traffic_adjusted_eta_minutes"],
          "distance": data["distance_km"],
          "traffic_factor": data["traffic_factor"],
          "accuracy": data["accuracy"],
          "route_info": data["route_info"],
          "current_location": data["current_location"],
          "error": false,
        };
      }
    } catch (_) {}
    return {
      "stop": stop["stop"],
      "eta": "--",
      "distance": 0.0,
      "traffic_factor": 1.0,
      "accuracy": "unknown",
      "error": true,
    };
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

  Widget _buildETACard(Map<String, dynamic> eta) {
    final bool hasError = eta["error"] == true;
    final String etaText =
        hasError ? "--" : "${eta["eta"]?.toStringAsFixed(1)} min";
    final double distance = eta["distance"] ?? 0.0;
    final double trafficFactor = eta["traffic_factor"] ?? 1.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(eta["stop"],
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: !hasError
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Distance: ${distance.toStringAsFixed(1)} km"),
                  Text("Traffic: ${_getTrafficStatus(trafficFactor)}",
                      style: TextStyle(color: _getTrafficColor(trafficFactor))),
                  if (eta["accuracy"] != null)
                    Text("Accuracy: ${eta["accuracy"]}"),
                  if (eta["base_eta"] != null &&
                      eta["traffic_adjusted_eta"] != null)
                    Text(
                        "Base ETA: ${eta["base_eta"].toStringAsFixed(1)} min, Adjusted: ${eta["traffic_adjusted_eta"].toStringAsFixed(1)} min"),
                ],
              )
            : const Text("Unable to fetch ETA"),
        trailing: Chip(
          label: Text(etaText),
          backgroundColor: hasError ? Colors.grey : Colors.blue,
          labelStyle: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bus ETA")),
      body: Column(
        children: [
          // Dropdown
          Padding(
            padding: const EdgeInsets.all(8),
            child: DropdownButton<String>(
              value: _selectedBusId,
              isExpanded: true,
              items: _buses.map((bus) {
                return DropdownMenuItem(
                    value: bus["id"], child: Text(bus["name"]!));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedBusId = val);
                  _fetchAllETAs();
                }
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? const Center(child: Text("Error fetching ETA"))
                    : RefreshIndicator(
                        onRefresh: _fetchAllETAs,
                        child: ListView.builder(
                          itemCount: _etaData.length,
                          itemBuilder: (context, i) =>
                              _buildETACard(_etaData[i]),
                        ),
                      ),
          ),
          if (_lastUpdated != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                  "Last updated: ${_lastUpdated!.toLocal().toString().substring(11, 19)}"),
            )
        ],
      ),
    );
  }
}
