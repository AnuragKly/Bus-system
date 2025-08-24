import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class ETAScreenV2 extends StatefulWidget {
  const ETAScreenV2({super.key});

  @override
  State<ETAScreenV2> createState() => _ETAScreenV2State();
}

class _ETAScreenV2State extends State<ETAScreenV2> {
  static const String _apiUrl = 'http://localhost:8000/gps/bus-location?bus_id=ESP32_BUS_001';
  static const String _etaUrl = 'http://localhost:8000/gps/estimate-arrival';
  
  // Flow control
  int _currentStep = 0; // 0: Welcome, 1: Search, 2: Map confirmation, 3: ETA result
  
  // Location data
  LatLng? _busLocation; // Point A (always bus location)
  LatLng? _userLocation; // User's current location
  LatLng? _selectedDestination; // Point B (destination)
  String _destinationName = '';
  String _busLocationName = 'Current Bus Position'; // Name for bus location
  
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  MapController? _mapController;
  
  // State management
  bool _isLoading = false;
  Map<String, dynamic>? _etaResult;
  String? _errorMessage;
  List<Map<String, dynamic>> _searchSuggestions = [];
  
  // Nepal places database (comprehensive for Kathmandu to Dhulikhel route + Ring Road)
  final List<Map<String, dynamic>> _nepalPlaces = [
    // Kathmandu Ring Road (Clockwise from Koteshwor)
    {'name': 'Koteshwor Traffic Police Station', 'city': 'Kathmandu', 'lat': 27.6933, 'lon': 85.3183},
    {'name': 'Koteshwor Chowk', 'city': 'Kathmandu', 'lat': 27.6945, 'lon': 85.3167},
    {'name': 'Jadibuti', 'city': 'Kathmandu', 'lat': 27.6891, 'lon': 85.3558},
    {'name': 'Jadibuti Bus Stop', 'city': 'Kathmandu', 'lat': 27.6883, 'lon': 85.3545},
    {'name': 'Lokanthali', 'city': 'Kathmandu', 'lat': 27.6856, 'lon': 85.3689},
    {'name': 'Sinamangal', 'city': 'Kathmandu', 'lat': 27.6967, 'lon': 85.3578},
    {'name': 'Tribhuvan Airport', 'city': 'Kathmandu', 'lat': 27.6966, 'lon': 85.3591},
    {'name': 'Gaushala', 'city': 'Kathmandu', 'lat': 27.7089, 'lon': 85.3534},
    {'name': 'Chabahil', 'city': 'Kathmandu', 'lat': 27.7234, 'lon': 85.3624},
    {'name': 'Chabahil Bus Stop', 'city': 'Kathmandu', 'lat': 27.7229, 'lon': 85.3618},
    {'name': 'Maharajgunj', 'city': 'Kathmandu', 'lat': 27.7394, 'lon': 85.3425},
    {'name': 'Teaching Hospital', 'city': 'Kathmandu', 'lat': 27.7394, 'lon': 85.3425},
    {'name': 'Baneshwor', 'city': 'Kathmandu', 'lat': 27.6989, 'lon': 85.3378},
    {'name': 'Baneshwor Chowk', 'city': 'Kathmandu', 'lat': 27.6996, 'lon': 85.3371},
    {'name': 'New Baneshwor', 'city': 'Kathmandu', 'lat': 27.6934, 'lon': 85.3289},
    {'name': 'Tinkune', 'city': 'Kathmandu', 'lat': 27.6889, 'lon': 85.3445},
    
    // Ring Road West Side
    {'name': 'Balaju', 'city': 'Kathmandu', 'lat': 27.7398, 'lon': 85.3015},
    {'name': 'Balaju Bus Stop', 'city': 'Kathmandu', 'lat': 27.7389, 'lon': 85.3009},
    {'name': 'Gongabu', 'city': 'Kathmandu', 'lat': 27.7234, 'lon': 85.3089},
    {'name': 'New Bus Park (Gongabu)', 'city': 'Kathmandu', 'lat': 27.7172, 'lon': 85.3240},
    {'name': 'Samakhusi', 'city': 'Kathmandu', 'lat': 27.7234, 'lon': 85.2956},
    {'name': 'Kalanki', 'city': 'Kathmandu', 'lat': 27.6921, 'lon': 85.2846},
    {'name': 'Kalanki Chowk', 'city': 'Kathmandu', 'lat': 27.6915, 'lon': 85.2851},
    {'name': 'Kalimati', 'city': 'Kathmandu', 'lat': 27.6956, 'lon': 85.2967},
    {'name': 'Kuleshwor', 'city': 'Kathmandu', 'lat': 27.6823, 'lon': 85.2934},
    {'name': 'Balkhu', 'city': 'Kathmandu', 'lat': 27.6678, 'lon': 85.3012},
    {'name': 'Balkhu Bridge', 'city': 'Kathmandu', 'lat': 27.6671, 'lon': 85.3023},
    
    // Kathmandu Central Areas
    {'name': 'Ratna Park', 'city': 'Kathmandu', 'lat': 27.7065, 'lon': 85.3135},
    {'name': 'Old Bus Park (Ratna Park)', 'city': 'Kathmandu', 'lat': 27.7065, 'lon': 85.3135},
    {'name': 'Thamel', 'city': 'Kathmandu', 'lat': 27.7152, 'lon': 85.3097},
    {'name': 'Durbar Marg', 'city': 'Kathmandu', 'lat': 27.7056, 'lon': 85.3115},
    {'name': 'New Road', 'city': 'Kathmandu', 'lat': 27.7034, 'lon': 85.3130},
    {'name': 'Asan Tole', 'city': 'Kathmandu', 'lat': 27.7058, 'lon': 85.3077},
    {'name': 'Indra Chowk', 'city': 'Kathmandu', 'lat': 27.7054, 'lon': 85.3092},
    {'name': 'Basantapur Durbar Square', 'city': 'Kathmandu', 'lat': 27.7045, 'lon': 85.3077},
    {'name': 'Pashupatinath Temple', 'city': 'Kathmandu', 'lat': 27.7105, 'lon': 85.3482},
    {'name': 'Boudhanath Stupa', 'city': 'Kathmandu', 'lat': 27.7215, 'lon': 85.3624},
    {'name': 'Swayambhunath Temple', 'city': 'Kathmandu', 'lat': 27.7149, 'lon': 85.2906},
    
    // Lalitpur (Patan) Ring Road Section
    {'name': 'Lagankhel', 'city': 'Lalitpur', 'lat': 27.6668, 'lon': 85.3242},
    {'name': 'Lagankhel Bus Stop', 'city': 'Lalitpur', 'lat': 27.6661, 'lon': 85.3235},
    {'name': 'Satdobato', 'city': 'Lalitpur', 'lat': 27.6589, 'lon': 85.3367},
    {'name': 'Satdobato Chowk', 'city': 'Lalitpur', 'lat': 27.6582, 'lon': 85.3374},
    {'name': 'Jawalakhel', 'city': 'Lalitpur', 'lat': 27.6712, 'lon': 85.3167},
    {'name': 'Jawalakhel Chowk', 'city': 'Lalitpur', 'lat': 27.6705, 'lon': 85.3159},
    {'name': 'Kupondole', 'city': 'Lalitpur', 'lat': 27.6789, 'lon': 85.3098},
    {'name': 'Pulchowk', 'city': 'Lalitpur', 'lat': 27.6779, 'lon': 85.3182},
    {'name': 'Pulchowk Engineering Campus', 'city': 'Lalitpur', 'lat': 27.6779, 'lon': 85.3182},
    {'name': 'Patan Durbar Square', 'city': 'Lalitpur', 'lat': 27.6744, 'lon': 85.3261},
    {'name': 'Patan Hospital', 'city': 'Lalitpur', 'lat': 27.6745, 'lon': 85.3233},
    {'name': 'Godavari', 'city': 'Lalitpur', 'lat': 27.5989, 'lon': 85.3923},
    {'name': 'Imadol', 'city': 'Lalitpur', 'lat': 27.6567, 'lon': 85.3456},
    {'name': 'Gwarko', 'city': 'Lalitpur', 'lat': 27.6678, 'lon': 85.3389},
    
    // Bhaktapur Main Road
    {'name': 'Thimi', 'city': 'Bhaktapur', 'lat': 27.6789, 'lon': 85.3889},
    {'name': 'Thimi Chowk', 'city': 'Bhaktapur', 'lat': 27.6795, 'lon': 85.3896},
    {'name': 'Kamal Binayak', 'city': 'Bhaktapur', 'lat': 27.6734, 'lon': 85.4067},
    {'name': 'Bhaktapur Durbar Square', 'city': 'Bhaktapur', 'lat': 27.6724, 'lon': 85.4298},
    {'name': 'Nyatapola Temple', 'city': 'Bhaktapur', 'lat': 27.6719, 'lon': 85.4287},
    {'name': 'Bhaktapur Bus Stop', 'city': 'Bhaktapur', 'lat': 27.6734, 'lon': 85.4267},
    {'name': 'Sallaghari', 'city': 'Bhaktapur', 'lat': 27.6598, 'lon': 85.4456},
    {'name': 'Changunarayan', 'city': 'Bhaktapur', 'lat': 27.7189, 'lon': 85.4267},
    {'name': 'Sipadol', 'city': 'Bhaktapur', 'lat': 27.6645, 'lon': 85.4623},
    {'name': 'Balkot', 'city': 'Bhaktapur', 'lat': 27.6567, 'lon': 85.4789},
    
    // Road to Dhulikhel - Major Stops
    {'name': 'Sanga', 'city': 'Kavrepalanchok', 'lat': 27.6456, 'lon': 85.4934},
    {'name': 'Sanga Chowk', 'city': 'Kavrepalanchok', 'lat': 27.6445, 'lon': 85.4945},
    {'name': 'Banepa', 'city': 'Kavrepalanchok', 'lat': 27.6298, 'lon': 85.5203},
    {'name': 'Banepa Chowk', 'city': 'Kavrepalanchok', 'lat': 27.6289, 'lon': 85.5198},
    {'name': 'Banepa Hospital', 'city': 'Kavrepalanchok', 'lat': 27.6278, 'lon': 85.5234},
    {'name': 'Nala', 'city': 'Kavrepalanchok', 'lat': 27.6234, 'lon': 85.5345},
    {'name': 'Nala Bazaar', 'city': 'Kavrepalanchok', 'lat': 27.6245, 'lon': 85.5356},
    {'name': 'Dhulikhel', 'city': 'Kavrepalanchok', 'lat': 27.6167, 'lon': 85.5444},
    {'name': 'Dhulikhel Hospital', 'city': 'Kavrepalanchok', 'lat': 27.6178, 'lon': 85.5423},
    {'name': 'Dhulikhel Bus Stop', 'city': 'Kavrepalanchok', 'lat': 27.6156, 'lon': 85.5456},
    
    // Kathmandu University Area
    {'name': 'Kathmandu University (Dhulikhel)', 'city': 'Kavrepalanchok', 'lat': 27.6167, 'lon': 85.5444},
    {'name': 'KU School of Engineering', 'city': 'Kavrepalanchok', 'lat': 27.6189, 'lon': 85.5434},
    {'name': 'KU Medical School', 'city': 'Kavrepalanchok', 'lat': 27.6145, 'lon': 85.5456},
    
    // Additional Important Places
    {'name': 'Tribhuvan University (Kirtipur)', 'city': 'Kirtipur', 'lat': 27.6789, 'lon': 85.2774},
    {'name': 'Bir Hospital', 'city': 'Kathmandu', 'lat': 27.7024, 'lon': 85.3144},
    
    // Special Options
    {'name': 'Your Current Location', 'city': 'GPS', 'lat': 0.0, 'lon': 0.0}, // Special entry
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _fetchCurrentBusLocation();
    _getCurrentUserLocation();
  }

  Future<void> _getCurrentUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('Failed to get user location: $e');
    }
  }

  Future<void> _fetchCurrentBusLocation() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _busLocation = LatLng(
            data['latitude'].toDouble(),
            data['longitude'].toDouble(),
          );
          _busLocationName = _findNearestLocationName(_busLocation!);
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to get bus location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _findNearestLocationName(LatLng location) {
    double minDistance = double.infinity;
    String nearestName = 'Current Bus Position';
    
    for (var place in _nepalPlaces) {
      if (place['name'] == 'Your Current Location') continue;
      
      double distance = _calculateDistance(
        location.latitude, location.longitude,
        place['lat'], place['lon']
      );
      
      if (distance < minDistance && distance < 0.5) { // Within 500m
        minDistance = distance;
        nearestName = 'Near ${place['name']}';
      }
    }
    
    return nearestName;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    double dLat = (lat2 - lat1) * (math.pi / 180);
    double dLon = (lon2 - lon1) * (math.pi / 180);
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) * math.cos(lat2 * (math.pi / 180)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  void _searchPlaces(String query) {
    if (query.isEmpty) {
      setState(() => _searchSuggestions = []);
      return;
    }
    
    final suggestions = _nepalPlaces
        .where((place) => 
            place['name'].toLowerCase().contains(query.toLowerCase()) ||
            place['city'].toLowerCase().contains(query.toLowerCase()))
        .take(8)
        .toList();
    
    setState(() => _searchSuggestions = suggestions);
  }

  void _selectDestination(Map<String, dynamic> place) {
    setState(() {
      if (place['name'] == 'Your Current Location') {
        // Use user's current location
        if (_userLocation != null) {
          _selectedDestination = _userLocation!;
          _destinationName = 'Your Current Location';
        } else {
          // If user location not available, show error
          _errorMessage = 'Unable to detect your current location. Please enable location services.';
          return;
        }
      } else {
        // Use selected place
        _selectedDestination = LatLng(place['lat'], place['lon']);
        _destinationName = place['name'];
      }
      
      _searchController.text = _destinationName;
      _searchSuggestions = [];
      _currentStep = 2; // Go to map confirmation
    });
    
    // Center map on destination
    if (_mapController != null && _selectedDestination != null) {
      _mapController!.move(_selectedDestination!, 15.0);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (_currentStep == 2) {
      setState(() {
        _selectedDestination = point;
        _destinationName = 'Custom Location (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
      });
    }
  }

  void _confirmLocation() {
    if (_selectedDestination != null) {
      setState(() => _currentStep = 3);
      _calculateETA();
    }
  }

  Future<void> _calculateETA() async {
    if (_busLocation == null || _selectedDestination == null) return;
    
    setState(() => _isLoading = true);
    try {
      final url = '$_etaUrl?destination_lat=${_selectedDestination!.latitude}&destination_lon=${_selectedDestination!.longitude}&bus_id=ESP32_BUS_001';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _etaResult = data;
          _errorMessage = null;
        });
      } else {
        setState(() => _errorMessage = 'Failed to calculate ETA');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error calculating ETA: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startOver() {
    setState(() {
      _currentStep = 0;
      _selectedDestination = null;
      _destinationName = '';
      _searchController.clear();
      _etaResult = null;
      _errorMessage = null;
      _searchSuggestions = [];
    });
  }

  void _showDestinationOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Text(
                'Choose Your Destination',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select how you want to set your destination',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Option 1: Your Current Location
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.my_location,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Your Current Location',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _userLocation != null 
                      ? 'Use your GPS location as destination'
                      : 'Detecting your location...',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  if (_userLocation != null) {
                    setState(() {
                      _selectedDestination = _userLocation!;
                      _destinationName = 'Your Current Location';
                      _currentStep = 2; // Go to map confirmation
                    });
                    if (_mapController != null && _selectedDestination != null) {
                      _mapController!.move(_selectedDestination!, 15.0);
                    }
                  } else {
                    setState(() => _errorMessage = 'Unable to detect your location. Please enable location services.');
                  }
                },
              ),
              
              const SizedBox(height: 16),
              
              // Option 2: Search Places
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.search,
                    color: Colors.green.shade700,
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Search Places',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Search from 80+ locations in Nepal',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentStep = 1);
                },
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        leading: _currentStep > 0 
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    if (_currentStep > 0) _currentStep--;
                    if (_currentStep == 0) {
                      _selectedDestination = null;
                      _destinationName = '';
                      _searchController.clear();
                      _searchSuggestions = [];
                    }
                  });
                },
              )
            : null,
        actions: [
          if (_currentStep > 0)
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: _startOver,
              tooltip: 'Start Over',
            ),
        ],
      ),
      body: _buildCurrentStep(),
    );
  }

  String _getAppBarTitle() {
    switch (_currentStep) {
      case 0: return 'Bus ETA Calculator';
      case 1: return 'Select Destination';
      case 2: return 'Confirm Location';
      case 3: return 'ETA Result';
      default: return 'Bus ETA Calculator';
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildWelcomeScreen();
      case 1: return _buildSearchScreen();
      case 2: return _buildMapConfirmationScreen();
      case 3: return _buildETAResultScreen();
      default: return _buildWelcomeScreen();
    }
  }

  Widget _buildWelcomeScreen() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.shade100,
            ),
            child: Icon(
              Icons.directions_bus,
              size: 64,
              color: Colors.green.shade700,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Title
          Text(
            'Calculate Bus Arrival Time',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Subtitle
          Text(
            'Get real-time ETA from current bus location to your destination',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 48),
          
          // Info Cards
          _buildInfoCard(
            icon: Icons.location_on,
            title: 'From: Current Bus Location',
            subtitle: 'Starting point is always the current bus position',
            color: Colors.red,
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoCard(
            icon: Icons.my_location,
            title: 'To: Choose Your Destination',
            subtitle: 'Select from: Your Current Location or Search Places',
            color: Colors.blue,
          ),
          
          const SizedBox(height: 48),
          
          // Start Button with Options
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _showDestinationOptions(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Choose Your Destination',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchScreen() {
    return Column(
      children: [
        // Search Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(
            children: [
              Text(
                'Where do you want to go?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Type the name of your destination',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _searchPlaces,
            decoration: InputDecoration(
              hintText: 'Search for places in Nepal...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchPlaces('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            autofocus: true,
          ),
        ),
        
        // Search Results
        Expanded(
          child: _searchSuggestions.isEmpty
              ? _buildPopularPlaces()
              : _buildSearchResults(),
        ),
      ],
    );
  }

  Widget _buildPopularPlaces() {
    final popularPlaces = _nepalPlaces.take(10).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Popular Destinations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: popularPlaces.length,
            itemBuilder: (context, index) {
              final place = popularPlaces[index];
              return _buildPlaceListTile(place);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchSuggestions.length,
      itemBuilder: (context, index) {
        final place = _searchSuggestions[index];
        return _buildPlaceListTile(place);
      },
    );
  }

  Widget _buildPlaceListTile(Map<String, dynamic> place) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.green.shade100,
        ),
        child: Icon(
          Icons.location_on,
          color: Colors.green.shade700,
          size: 20,
        ),
      ),
      title: Text(
        place['name'],
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${place['city']} • ${place['lat'].toStringAsFixed(4)}, ${place['lon'].toStringAsFixed(4)}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      onTap: () => _selectDestination(place),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }

  Widget _buildMapConfirmationScreen() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green.shade50,
          child: Column(
            children: [
              Text(
                'Confirm Your Destination',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _destinationName,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Drag the pin to fine-tune the location',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        
        // Map
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedDestination ?? const LatLng(27.7172, 85.3240),
                  initialZoom: 15.0,
                  minZoom: 8.0,
                  maxZoom: 18.0,
                  onTap: _onMapTap,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.bus_tracker',
                  ),
                  MarkerLayer(
                    markers: [
                      // Bus location (red)
                      if (_busLocation != null)
                        Marker(
                          point: _busLocation!,
                          width: 50,
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.directions_bus,
                              size: 25,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      
                      // Destination (green, draggable-looking)
                      if (_selectedDestination != null)
                        Marker(
                          point: _selectedDestination!,
                          width: 60,
                          height: 60,
                          child: Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.green,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                              Container(
                                width: 4,
                                height: 20,
                                color: Colors.green,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Confirm Button
        Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedDestination != null ? _confirmLocation : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Confirm Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildETAResultScreen() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Calculating ETA...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _calculateETA,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_etaResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Main ETA Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade50, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // ETA Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Colors.green.shade700,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_etaResult!['estimated_arrival_minutes']?.toStringAsFixed(0)} min',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Estimated Arrival Time',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                
                // Route Details
                _buildDetailRow(
                  Icons.straighten,
                  'Distance',
                  '${_etaResult!['distance_km']?.toStringAsFixed(1)} km',
                ),
                
                const SizedBox(height: 12),
                
                _buildDetailRow(
                  Icons.speed,
                  'Average Speed',
                  '${_etaResult!['effective_speed_kmh']?.toStringAsFixed(1)} km/h',
                ),
                
                const SizedBox(height: 12),
                
                _buildDetailRow(
                  Icons.traffic,
                  'Traffic',
                  _getTrafficStatus(_etaResult!['traffic_factor'] ?? 1.0),
                  color: _getTrafficColor(_etaResult!['traffic_factor'] ?? 1.0),
                ),
                
                const SizedBox(height: 12),
                
                _buildDetailRow(
                  Icons.analytics,
                  'Confidence',
                  '${_etaResult!['confidence_percentage']?.toStringAsFixed(0)}%',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Route Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _busLocationName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _destinationName.isNotEmpty ? _destinationName : 'Selected Destination',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _startOver,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('New Search'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _calculateETA,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Refresh ETA'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color ?? Colors.grey.shade800,
          ),
        ),
      ],
    );
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
}
