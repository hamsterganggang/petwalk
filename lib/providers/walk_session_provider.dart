import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/animal_data_model.dart';

class WalkSessionProvider with ChangeNotifier {
  bool _isTracking = false;
  bool get isTracking => _isTracking;

  List<LatLng> _routeCoordinates = [];
  List<LatLng> get routeCoordinates => _routeCoordinates;

  DateTime? _startTime;
  DateTime? get startTime => _startTime;

  Duration _elapsedTime = Duration.zero;
  Duration get elapsedTime => _elapsedTime;

  double _totalDistance = 0.0; // In kilometers
  double get totalDistance => _totalDistance;

  List<AnimalDataModel> _selectedPets = [];
  List<AnimalDataModel> get selectedPets => _selectedPets;

  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;

  void startTracking(List<AnimalDataModel> pets) {
    _isTracking = true;
    _selectedPets = pets;
    _routeCoordinates = [];
    _elapsedTime = Duration.zero;
    _totalDistance = 0.0;
    _startTime = DateTime.now();
    
    _startTimer();
    _startLocationUpdates();
    notifyListeners();
  }

  void stopTracking() {
    _isTracking = false;
    _timer?.cancel();
    _positionSubscription?.cancel();
    notifyListeners();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedTime += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _startLocationUpdates() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      _updateLocation(LatLng(position.latitude, position.longitude));
    });
  }

  void _updateLocation(LatLng newLocation) {
    if (_routeCoordinates.isNotEmpty) {
      final lastLocation = _routeCoordinates.last;
      final distance = Geolocator.distanceBetween(
        lastLocation.latitude,
        lastLocation.longitude,
        newLocation.latitude,
        newLocation.longitude,
      );
      _totalDistance += distance / 1000.0; // Convert to km
    }
    _routeCoordinates.add(newLocation);
    notifyListeners();
  }

  void reset() {
    stopTracking();
    _routeCoordinates = [];
    _elapsedTime = Duration.zero;
    _totalDistance = 0.0;
    _startTime = null;
    _selectedPets = [];
    notifyListeners();
  }
}
