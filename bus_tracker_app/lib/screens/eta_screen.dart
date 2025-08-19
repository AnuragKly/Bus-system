import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ETAScreen extends StatefulWidget {
  const ETAScreen({super.key});

  @override
  State<ETAScreen> createState() => _ETAScreenState();
}

class _ETAScreenState extends State<ETAScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _etaResult;
  String? _error;

  // Predefined destinations in Nepal for quick selection
  final List<Map<String, dynamic>> _popularDestinations = [
    {'name': 'Kathmandu Durbar Square', 'lat': 27.7046, 'lng': 85.3077},
    {'name': 'Pashupatinath Temple', 'lat': 27.7106, 'lng': 85.3488},
    {'name': 'Swayambhunath Stupa', 'lat': 27.7149, 'lng': 85.2905},
    {'name': 'Pokhara Lakeside', 'lat': 28.2096, 'lng': 83.9856},
    {'name': 'Chitwan National Park', 'lat': 27.5291, 'lng': 84.3542},
    {'name': 'Bhaktapur Durbar Square', 'lat': 27.6722, 'lng': 85.4276},
    {'name': 'Nagarkot', 'lat': 27.7172, 'lng': 85.5221},
    {'name': 'Bandipur', 'lat': 27.9317, 'lng': 84.4198},
  ];

  Future<void> _calculateETA(double destLat, double destLng, String destName) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _etaResult = null;
    });

    try {
      final authService = AuthService();
      
      // Call the ETA API endpoint
      final response = await authService.authenticatedRequest(
        'POST',
        '/api/optimization/eta',
        body: {
          'destination_latitude': destLat,
          'destination_longitude': destLng,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _etaResult = {
            ...data,
            'destination_name': destName,
            'destination_latitude': destLat,
            'destination_longitude': destLng,
          };
        });
      } else {
        setState(() {
          _error = 'Failed to calculate ETA: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildDestinationCard(Map<String, dynamic> destination) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(
            Icons.location_on,
            color: Colors.blue.shade700,
          ),
        ),
        title: Text(
          destination['name'],
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Lat: ${destination['lat'].toStringAsFixed(4)}, '
          'Lng: ${destination['lng'].toStringAsFixed(4)}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _calculateETA(
          destination['lat'].toDouble(),
          destination['lng'].toDouble(),
          destination['name'],
        ),
      ),
    );
  }

  Widget _buildETAResult() {
    if (_etaResult == null) return const SizedBox.shrink();

    final eta = _etaResult!['estimated_arrival_time'];
    final distance = _etaResult!['distance_km'];
    final route = _etaResult!['route_info'];
    final destName = _etaResult!['destination_name'];

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.access_time,
                    color: Colors.green.shade700,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimated Arrival',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        eta ?? 'Calculating...',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Destination info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      destName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Distance and route info
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    'Distance',
                    distance != null ? '${distance.toStringAsFixed(1)} km' : 'N/A',
                    Icons.straighten,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoTile(
                    'Route Type',
                    route?['type'] ?? 'Direct',
                    Icons.route,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            
            if (route != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Route Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              _buildRouteDetails(route),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteDetails(Map<String, dynamic> route) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (route['total_distance'] != null)
            _buildDetailRow('Total Distance', '${route['total_distance']} km'),
          if (route['estimated_duration'] != null)
            _buildDetailRow('Estimated Duration', route['estimated_duration']),
          if (route['traffic_factor'] != null)
            _buildDetailRow('Traffic Factor', '${route['traffic_factor']}x'),
          if (route['road_conditions'] != null)
            _buildDetailRow('Road Conditions', route['road_conditions']),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🕐 ETA Calculator'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom destination input
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calculate ETA to Destination',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a popular destination or enter custom coordinates:',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Error display
            if (_error != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            // Loading indicator
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),

            // ETA Result
            _buildETAResult(),

            // Popular destinations
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'Popular Destinations in Nepal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _popularDestinations.length,
              itemBuilder: (context, index) {
                return _buildDestinationCard(_popularDestinations[index]);
              },
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
