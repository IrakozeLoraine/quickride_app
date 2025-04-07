import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SavedLocation {
  final String id;
  final String userId;
  final String name;
  final String address;
  final LatLng location;
  final DateTime createdAt;
  final bool isFavorite;

  SavedLocation({
    required this.id,
    required this.userId,
    required this.name,
    required this.address,
    required this.location,
    required this.createdAt,
    this.isFavorite = false,
  });

  // Create from Firestore document
  factory SavedLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final GeoPoint geoPoint = data['location'] as GeoPoint;
    
    return SavedLocation(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      location: LatLng(geoPoint.latitude, geoPoint.longitude),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isFavorite: data['isFavorite'] ?? false,
    );
  }

  // Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'address': address,
      'location': GeoPoint(location.latitude, location.longitude),
      'createdAt': Timestamp.fromDate(createdAt),
      'isFavorite': isFavorite,
    };
  }

  // Create a copy with updated fields
  SavedLocation copyWith({
    String? id,
    String? userId,
    String? name,
    String? address,
    LatLng? location,
    DateTime? createdAt,
    bool? isFavorite,
  }) {
    return SavedLocation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      address: address ?? this.address,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
