import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickride/data/models/user_model.dart';

class RiderModel extends UserModel {
  final String licenseNumber;
  final String plateNumber;
  final String motorcycleModel;
  final bool isAvailable;
  final GeoPoint currentLocation;
  final double rating;
  final int totalRides;

  RiderModel({
    required String id,
    required String name,
    required String phone,
    String? email,
    String? profileImageUrl,
    required DateTime createdAt,
    required DateTime updatedAt,
    required this.licenseNumber,
    required this.plateNumber,
    required this.motorcycleModel,
    this.isAvailable = false,
    required this.currentLocation,
    this.rating = 0.0,
    this.totalRides = 0,
  }) : super(
          id: id,
          name: name,
          phone: phone,
          email: email,
          userType: UserType.rider,
          profileImageUrl: profileImageUrl,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

  factory RiderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RiderModel(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'],
      profileImageUrl: data['profileImageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      licenseNumber: data['licenseNumber'] ?? '',
      plateNumber: data['plateNumber'] ?? '',
      motorcycleModel: data['motorcycleModel'] ?? '',
      isAvailable: data['isAvailable'] ?? false,
      currentLocation: data['currentLocation'] ?? const GeoPoint(0, 0),
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalRides: data['totalRides'] ?? 0,
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    final data = super.toFirestore();
    data.addAll({
      'licenseNumber': licenseNumber,
      'plateNumber': plateNumber,
      'motorcycleModel': motorcycleModel,
      'isAvailable': isAvailable,
      'currentLocation': currentLocation,
      'rating': rating,
      'totalRides': totalRides,
    });
    return data;
  }
}
