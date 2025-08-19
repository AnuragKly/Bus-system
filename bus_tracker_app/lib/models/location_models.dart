class LocationData {
  final double latitude;
  final double longitude;
  final String busId;
  final DateTime timestamp;
  final double? speed;
  final double? heading;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.busId,
    required this.timestamp,
    this.speed,
    this.heading,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      busId: json['bus_id'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      speed: json['speed']?.toDouble(),
      heading: json['heading']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'bus_id': busId,
      'timestamp': timestamp.toIso8601String(),
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
    };
  }

  @override
  String toString() {
    return 'LocationData(lat: $latitude, lng: $longitude, bus: $busId, time: $timestamp)';
  }
}

class ETAResult {
  final String estimatedArrivalTime;
  final double? distanceKm;
  final Map<String, dynamic>? routeInfo;
  final String destinationName;
  final double destinationLatitude;
  final double destinationLongitude;

  const ETAResult({
    required this.estimatedArrivalTime,
    required this.destinationName,
    required this.destinationLatitude,
    required this.destinationLongitude,
    this.distanceKm,
    this.routeInfo,
  });

  factory ETAResult.fromJson(Map<String, dynamic> json, String destName, double destLat, double destLng) {
    return ETAResult(
      estimatedArrivalTime: json['estimated_arrival_time'] ?? 'Unknown',
      destinationName: destName,
      destinationLatitude: destLat,
      destinationLongitude: destLng,
      distanceKm: json['distance_km']?.toDouble(),
      routeInfo: json['route_info'] as Map<String, dynamic>?,
    );
  }
}
