import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:quickride/data/models/ride_model.dart';
import 'package:quickride/data/models/user_model.dart';

class RideProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  RideModel? _currentRide;
  List<RideModel> _rideHistory = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  RideModel? get currentRide => _currentRide;
  List<RideModel> get rideHistory => _rideHistory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasActiveRide => _currentRide != null && 
      (_currentRide!.status == RideStatus.requested || 
       _currentRide!.status == RideStatus.negotiating || 
       _currentRide!.status == RideStatus.accepted || 
       _currentRide!.status == RideStatus.inProgress);

  // Request a ride
  Future<bool> requestRide({
    required String passengerId,
    required LatLng pickup,
    required LatLng dropoff,
    required double proposedFare,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final rideData = {
        'passengerId': passengerId,
        'riderId': null,
        'pickup': GeoPoint(pickup.latitude, pickup.longitude),
        'dropoff': GeoPoint(dropoff.latitude, dropoff.longitude),
        'proposedFare': proposedFare,
        'agreedFare': null,
        'status': RideStatus.requested.index,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'startTime': null,
        'endTime': null,
        'distance': null,
        'duration': null,
        'riderRating': null,
        'riderReview': null,
      };
      
      final docRef = await _firestore.collection('rides').add(rideData);
      final rideDoc = await docRef.get();
      _currentRide = RideModel.fromFirestore(rideDoc);
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to request ride: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Accept ride request (for rider)
  Future<bool> acceptRideRequest(String rideId, String riderId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _firestore.collection('rides').doc(rideId).update({
        'riderId': riderId,
        'status': RideStatus.accepted.index,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      // Fetch updated ride
      await fetchRideDetails(rideId);
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to accept ride: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Propose fare (negotiation)
  Future<bool> proposeFare(String rideId, double fare, bool isRider) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Create a map with the fields to update
      final Map<String, dynamic> updateData = {
        'status': RideStatus.negotiating.index,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      // Set the appropriate fare field based on user type
      if (isRider) {
        updateData['riderProposedFare'] = fare;
      } else {
        updateData['proposedFare'] = fare;
      }

      // Update the ride document
      await _firestore.collection('rides').doc(rideId).update(updateData);
      
      // Fetch updated ride
      await fetchRideDetails(rideId);
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to propose fare: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Accept fare proposal
  Future<bool> acceptFareProposal(String rideId, double agreedFare) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _firestore.collection('rides').doc(rideId).update({
        'agreedFare': agreedFare,
        'status': RideStatus.accepted.index,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      // Fetch updated ride
      await fetchRideDetails(rideId);
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to accept fare proposal: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Start ride
  Future<bool> startRide(String rideId) async {
    _setLoading(true);
    _clearError();
    
    try {
      final now = DateTime.now();
      await _firestore.collection('rides').doc(rideId).update({
        'status': RideStatus.inProgress.index,
        'startTime': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      
      // Fetch updated ride
      await fetchRideDetails(rideId);
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to start ride: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Complete ride
  Future<bool> completeRide(String rideId, double? distance, double? duration) async {
    _setLoading(true);
    _clearError();
    
    try {
      final now = DateTime.now();
      await _firestore.collection('rides').doc(rideId).update({
        'status': RideStatus.completed.index,
        'endTime': Timestamp.fromDate(now),
        'distance': distance,
        'duration': duration,
        'updatedAt': Timestamp.fromDate(now),
      });
      
      // Fetch updated ride
      await fetchRideDetails(rideId);
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to complete ride: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Cancel ride
  Future<bool> cancelRide(String rideId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _firestore.collection('rides').doc(rideId).update({
        'status': RideStatus.cancelled.index,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      _currentRide = null;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to cancel ride: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Rate and review a ride
  Future<bool> rateRide(String rideId, int rating, String? review) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _firestore.collection('rides').doc(rideId).update({
        'riderRating': rating,
        'riderReview': review,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      // Update rider's average rating
      if (_currentRide != null && _currentRide!.riderId != null) {
        final riderDoc = await _firestore.collection('riders').doc(_currentRide!.riderId).get();
        if (riderDoc.exists) {
          final data = riderDoc.data() as Map<String, dynamic>;
          final currentRating = (data['rating'] ?? 0.0).toDouble();
          final totalRides = (data['totalRides'] ?? 0) + 1;
          final newRating = ((currentRating * (totalRides - 1)) + rating) / totalRides;
          
          await _firestore.collection('riders').doc(_currentRide!.riderId).update({
            'rating': newRating,
            'totalRides': totalRides,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
        }
      }
      
      // Fetch updated ride
      await fetchRideDetails(rideId);
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to rate ride: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Fetch ride details
  Future<void> fetchRideDetails(String rideId) async {
    _setLoading(true);
    _clearError();
    
    try {
      final rideDoc = await _firestore.collection('rides').doc(rideId).get();
      if (rideDoc.exists) {
        _currentRide = RideModel.fromFirestore(rideDoc);
      } else {
        _currentRide = null;
      }
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to fetch ride details: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Fetch user's ride history
  Future<void> fetchRideHistory(String userId, UserType userType) async {
    _setLoading(true);
    _clearError();
    
    try {
      final fieldName = userType == UserType.rider ? 'riderId' : 'passengerId';
      
      // Create an index for this query in the Firebase console
      final ridesSnapshot = await _firestore
          .collection('rides')
          .where(fieldName, isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      _rideHistory = [];
      
      for (var doc in ridesSnapshot.docs) {
        try {
          final ride = RideModel.fromFirestore(doc);
          _rideHistory.add(ride);
        } catch (e) {
          print('Error parsing ride document ${doc.id}: $e');
        }
      }
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to fetch ride history: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Check for active ride
  Future<void> checkForActiveRide(String userId, UserType userType) async {
    _setLoading(true);
    _clearError();
    
    try {
      final fieldName = userType == UserType.rider ? 'riderId' : 'passengerId';
      final ridesSnapshot = await _firestore
          .collection('rides')
          .where(fieldName, isEqualTo: userId)
          .where('status', whereIn: [
            RideStatus.requested.index,
            RideStatus.negotiating.index,
            RideStatus.accepted.index,
            RideStatus.inProgress.index,
          ])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      
      if (ridesSnapshot.docs.isNotEmpty) {
        _currentRide = RideModel.fromFirestore(ridesSnapshot.docs.first);
      } else {
        _currentRide = null;
      }
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to check for active ride: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Listen to ride updates
  Stream<RideModel> listenToRideUpdates(String rideId) {
    return _firestore
        .collection('rides')
        .doc(rideId)
        .snapshots()
        .map((snapshot) => RideModel.fromFirestore(snapshot));
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

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
