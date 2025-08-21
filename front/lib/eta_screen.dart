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
  bool isLoading = true;
  bool hasError = false;
  List<Map<String, dynamic>> etaData = [];
  Timer? _refreshTimer;
  String selectedBusId = 'bus_001';

  // Available buses
  final List<Map<String, String>> buses = [
    {"id": "bus_001", "name": "Campus Shuttle"},
    {"id": "bus_002", "name": "KU to Kathmandu"},
    {"id": "bus_003", "name": "KU to Dhulikhel"},
  ];

  // Fixed stops with their coordinates
  final List<Map<String, dynamic>> stops = [
    {"stop": "Main Gate", "lat": 27.6198, "lon": 85.5380},
    {"stop": "Hostel", "lat": 27.6185, "lon": 85.5405},
    {"stop": "KU Central", "lat": 27.6210, "lon": 85.5355},
  ];

  final String baseUrl = 'http://10.0.2.2:8000/gps/estimate-arrival';

  @override
  void initState() {
    super.initState();
    fetchAllETAs();

    // Set up auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      fetchAllETAs();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchAllETAs() async {
    try {
      List<Map<String, dynamic>> results = [];

      for (var stop in stops) {
        final uri = Uri.parse(
            '$baseUrl?destination_lat=${stop["lat"]}&destination_lon=${stop["lon"]}&bus_id=$selectedBusId');

        final response = await http.get(uri);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          results.add({
            "stop": stop["stop"],
            "eta": data["estimated_arrival_minutes"],
            "distance": data["distance_km"],
            "traffic_factor": data["traffic_factor"],
            "accuracy": data["accuracy"],
            "route_info": data["route_info"],
            "current_location": data["current_location"],
            "base_eta": data["base_eta_minutes"],
            "traffic_adjusted_eta": data["traffic_adjusted_eta_minutes"],
          });
        } else {
          results.add({
            "stop": stop["stop"],
            "eta": "--",
            "distance": 0.0,
            "traffic_factor": 1.0,
            "accuracy": "unknown",
            "error": true
          });
        }
      }

      setState(() {
        etaData = results;
        isLoading = false;
        hasError = false;
      });
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  Color getAccuracyColor(String accuracy) {
    switch (accuracy) {
      case 'very_high':
        return Colors.green;
      case 'high':
        return Colors.lightGreen;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  IconData getAccuracyIcon(String accuracy) {
    switch (accuracy) {
      case 'very_high':
        return Icons.gps_fixed;
      case 'high':
        return Icons.gps_not_fixed;
      case 'medium':
        return Icons.location_on;
      default:
        return Icons.location_off;
    }
  }

  String getTrafficStatus(double trafficFactor) {
    if (trafficFactor > 1.3) return "Heavy Traffic";
    if (trafficFactor > 1.1) return "Light Traffic";
    if (trafficFactor < 0.9) return "Fast Route";
    return "Normal Traffic";
  }

  Color getTrafficColor(double trafficFactor) {
    if (trafficFactor > 1.3) return Colors.red;
    if (trafficFactor > 1.1) return Colors.orange;
    if (trafficFactor < 0.9) return Colors.green;
    return Colors.blue;
  }

  Widget buildETACard(Map<String, dynamic> eta) {
    final bool hasError = eta["error"] == true;
    final String etaText = hasError ? "--" : "${eta["eta"]} min";
    final double distance = eta["distance"] ?? 0.0;
    final double trafficFactor = eta["traffic_factor"] ?? 1.0;
    final String accuracy = eta["accuracy"] ?? "unknown";
    final Map<String, dynamic>? routeInfo = eta["route_info"];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main ETA Row
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    eta["stop"],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasError ? Colors.grey : Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    etaText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),

            if (!hasError) ...[
              const SizedBox(height: 12),

              // Distance and Traffic Info
              Row(
                children: [
                  Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    "${distance.toStringAsFixed(1)} km",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.traffic,
                    size: 16,
                    color: getTrafficColor(trafficFactor),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    getTrafficStatus(trafficFactor),
                    style: TextStyle(
                      color: getTrafficColor(trafficFactor),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Accuracy and Route Info
              Row(
                children: [
                  Icon(
                    getAccuracyIcon(accuracy),
                    size: 16,
                    color: getAccuracyColor(accuracy),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    accuracy.toUpperCase(),
                    style: TextStyle(
                      color: getAccuracyColor(accuracy),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (routeInfo != null && routeInfo["route_name"] != null) ...[
                    Icon(Icons.route, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        routeInfo["route_name"],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),

              // Traffic Factor Details
              if (trafficFactor != 1.0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: getTrafficColor(trafficFactor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: getTrafficColor(trafficFactor),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Base time: ${eta["base_eta"] ?? "--"} min • "
                          "With traffic: ${eta["traffic_adjusted_eta"] ?? "--"} min",
                          style: TextStyle(
                            fontSize: 12,
                            color: getTrafficColor(trafficFactor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bus ETA"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : fetchAllETAs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Bus Selection
          Container(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.directions_bus, color: Colors.blue),
                    const SizedBox(width: 12),
                    const Text(
                      "Select Bus:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedBusId,
                        isExpanded: true,
                        underline: Container(),
                        items: buses.map((bus) {
                          return DropdownMenuItem<String>(
                            value: bus["id"],
                            child: Text(bus["name"]!),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedBusId = newValue;
                              isLoading = true;
                            });
                            fetchAllETAs();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ETA List
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Calculating ETAs..."),
                      ],
                    ),
                  )
                : hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Unable to fetch ETA data",
                              style: TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Please check your connection and try again",
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: fetchAllETAs,
                              icon: const Icon(Icons.refresh),
                              label: const Text("Retry"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: etaData.length,
                        itemBuilder: (context, index) {
                          return buildETACard(etaData[index]);
                        },
                      ),
          ),

          // Last Updated Info
          if (!isLoading && !hasError)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    "Last updated: ${DateTime.now().toString().substring(11, 19)}",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    "Auto-refresh: 30s",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
