// Flutter App Configuration
// File: lib/config/app_config.dart

class AppConfig {
  // Backend API Configuration
  static const String baseUrl = 'http://localhost:8000'; // Change to your backend URL
  static const String wsUrl = 'ws://localhost:8000/ws'; // WebSocket URL
  
  // API Endpoints
  static const String busLocationEndpoint = '/bus-location';
  static const String estimateArrivalEndpoint = '/estimate-arrival';
  static const String estimateArrivalAdvancedEndpoint = '/estimate-arrival-advanced';
  static const String routeAnalysisEndpoint = '/route-analysis';
  
  // Map Configuration
  static const double defaultZoom = 14.0;
  static const double minZoom = 10.0;
  static const double maxZoom = 20.0;
  
  // Kathmandu Valley Default Location
  static const double defaultLatitude = 27.7172;
  static const double defaultLongitude = 85.3240;
  
  // App Configuration
  static const String appName = 'Bus Tracker Nepal';
  static const String appVersion = '1.0.0';
  
  // Update Intervals (in seconds)
  static const int busLocationUpdateInterval = 5;
  static const int etaUpdateInterval = 30;
  
  // Distance thresholds (in meters)
  static const double nearbyBusThreshold = 1000.0; // 1km
  static const double arrivalThreshold = 100.0;    // 100m
}

// Environment-specific configurations
class Environment {
  static const String dev = 'development';
  static const String prod = 'production';
  
  static const String current = String.fromEnvironment('ENV', defaultValue: dev);
  
  static bool get isDevelopment => current == dev;
  static bool get isProduction => current == prod;
}
