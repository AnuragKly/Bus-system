import 'package:flutter/material.dart';

class ETAScreen extends StatelessWidget {
  const ETAScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock ETA data
    List<Map<String, dynamic>> etaData = [
      {"stop": "Main Gate", "eta": "5 min"},
      {"stop": "Hostel", "eta": "12 min"},
      {"stop": "KU Central", "eta": "18 min"},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Bus ETA")),
      body: ListView.builder(
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
