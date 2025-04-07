import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickride/data/models/rider_model.dart';
import 'package:quickride/data/models/saved_location_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationProvider extends ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  List<SavedLocation> _savedLocations = [];
  List<SavedLocation> _recentLocations = [];
  String? _errorMessage;
  List<RiderModel> _nearbyRiders = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final double _searchRadiusInKm = 5.0;

  // Getters
  Position? get currentPosition => _currentPosition;
  List<SavedLocation> get savedLocations => _savedLocations;
  List<SavedLocation> get recentLocations => _recentLocations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<RiderModel> get nearbyRiders => _nearbyRiders;
  LatLng? get currentLatLng => _currentPosition != null 
      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) 
      : null;

  LocationProvider() {
    _initLocationService();
  }

  // Initialize location service
  Future<void> _initLocationService() async {
    _setLoading(true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setError('Location services are disabled.');
        _setLoading(false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setError('Location permissions are denied.');
          _setLoading(false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _setError('Location permissions are permanently denied, cannot request permissions.');
        _setLoading(false);
        return;
      }

      await getCurrentLocation();
    } catch (e) {
      _setError('Failed to initialize location service: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Get current location
  Future<void> getCurrentLocation() async {
    _setLoading(true);
    try {
      // Create LocationSettings with high accuracy
      final LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update if device moves by 10 meters
        timeLimit: const Duration(seconds: 10), // Timeout after 10 seconds
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      
      _currentPosition = position;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to get current location: ${e.toString()}');
      _setLoading(false);
    }
  }

  // saved locations
  Future<void> loadSavedLocations(String userId) async {
    _setLoading(true);
    clearError();
    
    try {
      // Load from Firestore for logged in users
      final snapshot = await _firestore
          .collection('saved_locations')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      _savedLocations = snapshot.docs
          .map((doc) => SavedLocation.fromFirestore(doc))
          .toList();
      
      // Load recent locations from local storage
      await _loadRecentLocations();
      
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load saved locations: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Save a new location
  Future<bool> saveLocation({
    required String userId,
    required String name,
    required String address,
    required LatLng location,
    bool isFavorite = false,
  }) async {
    _setLoading(true);
    clearError();
    
    try {
      final locationData = {
        'userId': userId,
        'name': name,
        'address': address,
        'location': GeoPoint(location.latitude, location.longitude),
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'isFavorite': isFavorite,
      };
      
      final docRef = await _firestore.collection('saved_locations').add(locationData);
      final newLocation = SavedLocation(
        id: docRef.id,
        userId: userId,
        name: name,
        address: address,
        location: location,
        createdAt: DateTime.now(),
        isFavorite: isFavorite,
      );
      
      _savedLocations.insert(0, newLocation);
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to save location: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Update an existing saved location
  Future<bool> updateSavedLocation(SavedLocation location) async {
    _setLoading(true);
    clearError();
    
    try {
      await _firestore
          .collection('saved_locations')
          .doc(location.id)
          .update(location.toFirestore());
      
      final index = _savedLocations.indexWhere((loc) => loc.id == location.id);
      if (index != -1) {
        _savedLocations[index] = location;
      }
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update location: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Delete a saved location
  Future<bool> deleteSavedLocation(String locationId) async {
    _setLoading(true);
    clearError();
    
    try {
      await _firestore.collection('saved_locations').doc(locationId).delete();
      
      _savedLocations.removeWhere((loc) => loc.id == locationId);
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete location: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Add a location to recent locations (stored locally)
  Future<void> addToRecentLocations({
    required String address,
    required LatLng location,
    String name = '',
  }) async {
    try {
      final now = DateTime.now();
      
      // Create a temporary location object
      final recentLocation = SavedLocation(
        id: now.millisecondsSinceEpoch.toString(), // Use timestamp as temporary ID
        userId: '',
        name: name.isEmpty ? address.split(',').first : name,
        address: address,
        location: location,
        createdAt: now,
      );
      
      // Remove existing entry with same address if exists
      _recentLocations.removeWhere((loc) => loc.address == address);
      
      // Add to beginning of list
      _recentLocations.insert(0, recentLocation);
      
      // Keep only the last 10 recent locations
      if (_recentLocations.length > 10) {
        _recentLocations = _recentLocations.sublist(0, 10);
      }
      
      // Save to local storage
      await _saveRecentLocations();
      
      notifyListeners();
    } catch (e) {
      print('Error adding to recent locations: $e');
    }
  }

  // Load recent locations from SharedPreferences
  Future<void> _loadRecentLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentLocationsJson = prefs.getString('recent_locations');
      
      if (recentLocationsJson != null && recentLocationsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(recentLocationsJson);
        
        _recentLocations = decoded.map((item) {
          return SavedLocation(
            id: item['id'],
            userId: item['userId'] ?? '',
            name: item['name'],
            address: item['address'],
            location: LatLng(item['latitude'], item['longitude']),
            createdAt: DateTime.parse(item['createdAt']),
          );
        }).toList();
      }
    } catch (e) {
      print('Error loading recent locations: $e');
      _recentLocations = [];
    }
  }

  // Save recent locations to SharedPreferences
  Future<void> _saveRecentLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final encoded = _recentLocations.map((location) {
        return {
          'id': location.id,
          'userId': location.userId,
          'name': location.name,
          'address': location.address,
          'latitude': location.location.latitude,
          'longitude': location.location.longitude,
          'createdAt': location.createdAt.toIso8601String(),
        };
      }).toList();
      
      await prefs.setString('recent_locations', jsonEncode(encoded));
    } catch (e) {
      print('Error saving recent locations: $e');
    }
  }

  // Clear recent locations
  Future<void> clearRecentLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recent_locations');
      _recentLocations = [];
      notifyListeners();
    } catch (e) {
      print('Error clearing recent locations: $e');
    }
  }

  // Find nearby riders
  Future<void> findNearbyRiders() async {
    if (_currentPosition == null) {
      await getCurrentLocation();
      if (_currentPosition == null) return;
    }

    _setLoading(true);
    try {
      // Query riders who are available and within the search radius
      final riders = await _firestore
          .collection('riders')
          .where('isAvailable', isEqualTo: true)
          .get();

      _nearbyRiders = [];
      for (var doc in riders.docs) {
        final rider = RiderModel.fromFirestore(doc);
        final riderLocation = rider.currentLocation;
        
        // Calculate distance between current location and rider
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          riderLocation.latitude,
          riderLocation.longitude,
        );
        
        // Convert distance to kilometers and check if within search radius
        if (distance / 1000 <= _searchRadiusInKm) {
          _nearbyRiders.add(rider);
        }
      }
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to find nearby riders: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Update rider location (for rider app)
  Future<void> updateRiderLocation(String riderId) async {
    if (_currentPosition == null) {
      await getCurrentLocation();
      if (_currentPosition == null) return;
    }

    try {
      await _firestore.collection('riders').doc(riderId).update({
        'currentLocation': GeoPoint(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      _setError('Failed to update rider location: ${e.toString()}');
    }
  }

  // Calculate distance between two points
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    ) / 1000; // Convert to kilometers
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
