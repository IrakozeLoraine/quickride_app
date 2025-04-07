import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum RideStatus {
  requested, // Initial request
  negotiating, // Fare negotiation ongoing
  accepted, // Rider accepted
  inProgress, // Ride started
  completed, // Ride completed
  cancelled, // Ride cancelled
}

class RideModel {
  final String id;
  final String passengerId;
  final String? riderId;
  final LatLng pickup;
  final LatLng dropoff;
  final double proposedFare;
  final double? riderProposedFare;
  final double? agreedFare;
  final RideStatus status;
  final DateTime createdAt;
  final DateTime? startTime;
  final DateTime? endTime;
  final double? distance;
  final double? duration;
  final int? riderRating;
  final String? riderReview;

  RideModel({
    required this.id,
    required this.passengerId,
    this.riderId,
    required this.pickup,
    required this.dropoff,
    required this.proposedFare,
    this.riderProposedFare,
    this.agreedFare,
    required this.status,
    required this.createdAt,
    this.startTime,
    this.endTime,
    this.distance,
    this.duration,
    this.riderRating,
    this.riderReview,
  });

  factory RideModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final GeoPoint pickupPoint = data['pickup'] as GeoPoint;
    final GeoPoint dropoffPoint = data['dropoff'] as GeoPoint;

    return RideModel(
      id: doc.id,
      passengerId: data['passengerId'] ?? '',
      riderId: data['riderId'],
      pickup: LatLng(pickupPoint.latitude, pickupPoint.longitude),
      dropoff: LatLng(dropoffPoint.latitude, dropoffPoint.longitude),
      proposedFare: (data['proposedFare'] ?? 0.0).toDouble(),
      riderProposedFare: data['riderProposedFare']?.toDouble(),
      agreedFare: data['agreedFare']?.toDouble(),
      status: RideStatus.values[data['status'] ?? 0],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      startTime: data['startTime'] != null
          ? (data['startTime'] as Timestamp).toDate()
          : null,
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      distance: data['distance']?.toDouble(),
      duration: data['duration']?.toDouble(),
      riderRating: data['riderRating'],
      riderReview: data['riderReview'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'passengerId': passengerId,
      'riderId': riderId,
      'pickup': GeoPoint(pickup.latitude, pickup.longitude),
      'dropoff': GeoPoint(dropoff.latitude, dropoff.longitude),
      'proposedFare': proposedFare,
      'riderProposedFare': riderProposedFare,
      'agreedFare': agreedFare,
      'status': status.index,
      'createdAt': Timestamp.fromDate(createdAt),
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'distance': distance,
      'duration': duration,
      'riderRating': riderRating,
      'riderReview': riderReview,
    };
  }
}
