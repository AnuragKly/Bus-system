import 'dart:convert';
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
  }

  Future<void> fetchAllETAs() async {
    try {
      List<Map<String, dynamic>> results = [];

      for (var stop in stops) {
        final uri = Uri.parse(
            '$baseUrl?destination_lat=${stop["lat"]}&destination_lon=${stop["lon"]}&bus_id=bus_001');
        final response = await http.get(uri);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          results.add({
            "stop": stop["stop"],
            "eta": "${data["estimated_arrival_minutes"]} min"
          });
        } else {
          results.add({"stop": stop["stop"], "eta": "--"});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bus ETA")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasError
              ? Center(
                  child: ElevatedButton(
                    onPressed: fetchAllETAs,
                    child: const Text("Retry"),
                  ),
                )
              : ListView.builder(
                  itemCount: etaData.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.access_time),
                      title: Text(etaData[index]["stop"]),
                      trailing: Text(etaData[index]["eta"]),
                    );
                  },
                ),
    );
  }
}
