import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ETAScreen extends StatefulWidget {
  const ETAScreen({super.key});

  @override
  State<ETAScreen> createState() => _ETAScreenState();
}

class _ETAScreenState extends State<ETAScreen> {
  List<Map<String, dynamic>> etaData = [];
  bool isLoading = true;
  bool hasError = false;

  // Use same URL style as MapScreen (adjust for emulator/localhost)
  final String backendUrl = 'http://10.0.2.2:8000/gps/bus-eta?bus_id=bus_001';
  // If you're on a real device, use 'http://192.168.1.xx:8000/...'
  // If running on desktop: 'http://127.0.0.1:8000/...'

  @override
  void initState() {
    super.initState();
    fetchETAData();
  }

  Future<void> fetchETAData() async {
    try {
      final response = await http.get(Uri.parse(backendUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Assuming backend returns something like:
        // [{"stop": "Main Gate", "eta": "5 min"}, {"stop": "Hostel", "eta": "12 min"}]
        setState(() {
          etaData = List<Map<String, dynamic>>.from(data);
          isLoading = false;
          hasError = false;
        });
      } else {
        debugPrint('Failed to fetch ETA: ${response.statusCode}');
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching ETA: $e');
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Failed to load ETA data"),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: fetchETAData,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: etaData.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.access_time),
                      title: Text(etaData[index]["stop"] ?? "Unknown Stop"),
                      trailing: Text(etaData[index]["eta"] ?? "--"),
                    );
                  },
                ),
    );
  }
}
