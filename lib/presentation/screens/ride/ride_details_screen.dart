import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:quickride/data/models/ride_model.dart';
import 'package:quickride/data/models/user_model.dart';
import 'package:quickride/data/providers/auth_provider.dart';
import 'package:quickride/data/providers/location_provider.dart';
import 'package:quickride/data/providers/ride_provider.dart';
import 'package:quickride/presentation/widgets/loading_overlay.dart';
import 'package:quickride/routes/app_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:quickride/utils/app_utils.dart';
import 'package:geocoding/geocoding.dart';

class RideDetailsScreen extends StatefulWidget {
  final String rideId;

  const RideDetailsScreen({
    Key? key,
    required this.rideId,
  }) : super(key: key);

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  RideModel? _ride;
  UserModel? _passenger;
  UserModel? _rider;
  bool _isLoading = false;
  bool _isPerformingAction = false;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  StreamSubscription? _rideSubscription;
  final _counterOfferController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _pickupAddress;
  String? _dropoffAddress;
  double? _passengerProposedFare;
  double? _riderProposedFare;

  bool get isPassenger => Provider.of<AuthProvider>(context, listen: false).userModel?.userType == UserType.passenger;
  
  bool get isRider => Provider.of<AuthProvider>(context, listen: false).userModel?.userType == UserType.rider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRideDetails();
    });

  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _mapController?.dispose();
    _counterOfferController.dispose();
    super.dispose();
  }

  Future<void> _loadRideDetails() async {
    final localizations = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
    });
    try {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      
      await rideProvider.fetchRideDetails(widget.rideId);
      
      if (rideProvider.currentRide == null) {
        showToast(context, localizations.rideNotFound, null, true);
        Navigator.of(context).pop();
        return;
      }

      _ride = rideProvider.currentRide;

      // Initialize fare values
      _passengerProposedFare = _ride!.proposedFare;

      // Get rider's counter-offer if available
      if (_ride!.status == RideStatus.negotiating) {
        try {
          // Check if the riderProposedFare field exists in the document
          final rideDoc = await FirebaseFirestore.instance
              .collection('rides')
              .doc(widget.rideId)
              .get();
              
          if (rideDoc.exists) {
            final data = rideDoc.data();
            if (data != null && data.containsKey('riderProposedFare')) {
              _riderProposedFare = (data['riderProposedFare'] as num).toDouble();
            }
          }
        } catch (e) {
          print('Error fetching rider proposed fare: ${e.toString()}');
        }
      }
      
      // Listen for ride updates
      _listenToRideUpdates();
      
      // Load passenger and rider details
      await _loadUserDetails();
      
      // Setup map markers
      _updateMapMarkers();
      
      // Get location addresses
      await _getAddressesFromCoordinates();
    } catch (e) {
      showToast(context, 'Error loading ride details: ${e.toString()}', null, true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _listenToRideUpdates() {
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    _rideSubscription = rideProvider.listenToRideUpdates(widget.rideId).listen(
      (updatedRide) async{
        if (updatedRide.status == RideStatus.negotiating) {
          try {
            // Check for updated fare information
            final rideDoc = await FirebaseFirestore.instance
                .collection('rides')
                .doc(widget.rideId)
                .get();
                
            if (rideDoc.exists) {
              final data = rideDoc.data();
              if (data != null) {
                setState(() {
                  _passengerProposedFare = updatedRide.proposedFare;
                  
                  if (data.containsKey('riderProposedFare')) {
                    _riderProposedFare = (data['riderProposedFare'] as num).toDouble();
                  }
                });
              }
            }
          } catch (e) {
            print('Error updating fares: ${e.toString()}');
          }
        }
        setState(() {
          _ride = updatedRide;
          _updateMapMarkers();
        });
        
        // Check if rider got assigned while passenger is waiting
        if (isPassenger && 
            _ride?.riderId != null && 
            _rider == null && 
            _ride?.status == RideStatus.accepted) {
          _loadUserDetails();
        }
      },
      onError: (e) {
        showToast(context, 'Error receiving ride updates: ${e.toString()}', null, true);
      },
    );
  }

  Future<void> _loadUserDetails() async {
    try {
      if (_ride == null) return;
      
      // Load passenger details
      final passengerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_ride!.passengerId)
          .get();
      
      if (passengerDoc.exists) {
        setState(() {
          _passenger = UserModel.fromFirestore(passengerDoc);
        });
      }
      
      // Load rider details if available
      if (_ride!.riderId != null) {
        final riderDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_ride!.riderId)
            .get();
        
        if (riderDoc.exists) {
          setState(() {
            _rider = UserModel.fromFirestore(riderDoc);
          });
        }
      }
    } catch (e) {
      print('Error loading user details: ${e.toString()}');
    }
  }

  void _updateMapMarkers() {
    final localizations = AppLocalizations.of(context)!;

    if (_ride == null) return;
    
    Set<Marker> markers = {};
    
    // Add pickup marker
    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: _ride!.pickup,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: localizations.pickupLocation)
      ),
    );
    
    // Add dropoff marker
    markers.add(
      Marker(
        markerId: const MarkerId('dropoff'),
        position: _ride!.dropoff,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: localizations.dropoffLocation),
      ),
    );
    
    setState(() {
      _markers = markers;
    });
    
    // Adjust camera to show both markers
    if (_mapController != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _ride!.pickup.latitude < _ride!.dropoff.latitude
              ? _ride!.pickup.latitude
              : _ride!.dropoff.latitude,
          _ride!.pickup.longitude < _ride!.dropoff.longitude
              ? _ride!.pickup.longitude
              : _ride!.dropoff.longitude,
        ),
        northeast: LatLng(
          _ride!.pickup.latitude > _ride!.dropoff.latitude
              ? _ride!.pickup.latitude
              : _ride!.dropoff.latitude,
          _ride!.pickup.longitude > _ride!.dropoff.longitude
              ? _ride!.pickup.longitude
              : _ride!.dropoff.longitude,
        ),
      );
      
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }
  
  String _formatAddress(Placemark place) {
    List<String> addressParts = [];
    
    if (place.street != null && place.street!.isNotEmpty) {
      addressParts.add(place.street!);
    }
    
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      addressParts.add(place.subLocality!);
    }
    
    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }
    
    // Add this part only if nothing else is available
    if (addressParts.isEmpty && place.name != null && place.name!.isNotEmpty) {
      addressParts.add(place.name!);
    }
    
    return addressParts.join(', ');
  }

  Future<void> _getAddressesFromCoordinates() async {
    if (_ride == null) return;
    
    try {
      // Get pickup address
      List<Placemark> pickupPlacemarks = await placemarkFromCoordinates(
        _ride!.pickup.latitude,
        _ride!.pickup.longitude,
      );
      
      // Get dropoff address
      List<Placemark> dropoffPlacemarks = await placemarkFromCoordinates(
        _ride!.dropoff.latitude,
        _ride!.dropoff.longitude,
      );
      
      if (pickupPlacemarks.isNotEmpty) {
        final place = pickupPlacemarks.first;
        setState(() {
          _pickupAddress = _formatAddress(place);
        });
      }
      
      if (dropoffPlacemarks.isNotEmpty) {
        final place = dropoffPlacemarks.first;
        setState(() {
          _dropoffAddress = _formatAddress(place);
        });
      }
    } on PlatformException catch (e) {
      print('Error getting address: ${e.message}');
    } catch (e) {
      print('Unknown error: $e');
    }
  }

  Future<void> _acceptRideRequest() async {
    final localizations = AppLocalizations.of(context)!;

    if (_ride == null || !isRider) return;
    
    setState(() {
      _isPerformingAction = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      
      final success = await rideProvider.acceptRideRequest(
        _ride!.id,
        authProvider.userModel!.id,
      );
      
      if (success) {
        showToast(context, localizations.rideAccepted, null, false);
      } else {
        showToast(context, rideProvider.errorMessage ?? localizations.failedToAcceptRide, null, true);
      }
    } catch (e) {
      showToast(context, 'Error: ${e.toString()}', null, true);
    } finally {
      if (mounted) {
        setState(() {
          _isPerformingAction = false;
        });
      }
    }
  }

  Future<void> _startRide() async {
    final localizations = AppLocalizations.of(context)!;

    if (_ride == null || !isRider) return;
    
    setState(() {
      _isPerformingAction = true;
    });
    
    try {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      
      final success = await rideProvider.startRide(_ride!.id);
      
      if (success) {
        showToast(context, localizations.rideStarted, null, false);
      } else {
        showToast(context, rideProvider.errorMessage ?? localizations.failedToStartRide, null, true);
      }
    } catch (e) {
      showToast(context, 'Error: ${e.toString()}', null, true);
    } finally {
      if (mounted) {
        setState(() {
          _isPerformingAction = false;
        });
      }
    }
  }

  Future<void> _completeRide() async {
    final localizations = AppLocalizations.of(context)!;

    if (_ride == null || !isRider) return;
    
    setState(() {
      _isPerformingAction = true;
    });
    
    try {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      if (locationProvider.errorMessage != null) {
        showToast(context, locationProvider.errorMessage!, null, true);
      }

      // Calculate approximate distance and duration
      double? distance;
      double? duration;
      
      if (locationProvider.currentLatLng != null) {
        distance = locationProvider.calculateDistance(
          _ride!.pickup,
          _ride!.dropoff,
        );
        
        // Rough estimate: 3 minutes per kilometer
        duration = distance * 3;
      }
      
      final success = await rideProvider.completeRide(
        _ride!.id,
        distance,
        duration,
      );
      
      if (success) {
        showToast(context, localizations.rideCompleted, null, false);
        
        // Show rating dialog for passenger
        if (isPassenger) {
          _showRatingDialog();
        }
      } else {
        showToast(context, rideProvider.errorMessage ?? localizations.failedToCompleteRide, null, true);
      }
    } catch (e) {
      showToast(context, 'Error: ${e.toString()}', null, true);
    } finally {
      if (mounted) {
        setState(() {
          _isPerformingAction = false;
        });
      }
    }
  }

  Future<void> _cancelRide() async {
    final localizations = AppLocalizations.of(context)!;

    if (_ride == null) return;
    
    // Confirm cancellation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.cancelRide),
        content: Text(localizations.confirmCancelRide),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.no),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations.yes),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      _isPerformingAction = true;
    });
    
    try {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      
      final success = await rideProvider.cancelRide(_ride!.id);
      
      if (success) {
        showToast(context, localizations.rideCancelled, null, false);
        
        Navigator.of(context).pushReplacementNamed(
          isRider ? AppRouter.riderHome : AppRouter.home,
        );
      } else {
        showToast(context, rideProvider.errorMessage ?? localizations.failedToCancelRide, null, true);
      }
    } catch (e) {
      showToast(context, 'Error: ${e.toString()}', null, true);
    } finally {
      if (mounted) {
        setState(() {
          _isPerformingAction = false;
        });
      }
    }
  }

  void _showRatingDialog() {
    final localizations = AppLocalizations.of(context)!;

    if (_ride == null || !isPassenger) return;
    
    int rating = 5; // Default rating
    String review = '';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(localizations.rateYourRide),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(localizations.howWasYourRideExperience),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border_outlined,
                      color: index < rating ? Colors.amber : Colors.grey,
                      size: 36,
                    ),
                    onPressed: () {
                      setState(() {
                        rating = index + 1;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: localizations.addReview,
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) {
                  review = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizations.skip),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _submitRating(rating, review);
              },
              child: Text(localizations.submit),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating(int rating, String review) async {
    final localizations = AppLocalizations.of(context)!;

    if (_ride == null) return;
    
    setState(() {
      _isPerformingAction = true;
    });
    
    try {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      
      final success = await rideProvider.rateRide(
        _ride!.id,
        rating,
        review.isNotEmpty ? review : null,
      );
      
      if (success) {
        showToast(context, localizations.ratingSubmitted, null, false);
        
        Navigator.of(context).pushReplacementNamed(AppRouter.home);
      } else {
        showToast(context, rideProvider.errorMessage ?? localizations.failedToSubmitRating, null, true);
      }
    } catch (e) {
      showToast(context, 'Error: ${e.toString()}', null, true);
    } finally {
      if (mounted) {
        setState(() {
          _isPerformingAction = false;
        });
      }
    }
  }
  
  Future<void> _showFareNegotiationDialog() async {
    final localizations = AppLocalizations.of(context)!;

    if (_ride == null) return;
    
    _counterOfferController.text = _ride!.proposedFare.toString();
    
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.proposeCounterOffer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${localizations.passengersOffer}: ${_ride!.proposedFare} RWF'),
            const SizedBox(height: 16),
            TextField(
              controller: _counterOfferController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: localizations.yourCounterOffer,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final counterOffer = double.tryParse(_counterOfferController.text);
              if (counterOffer != null && counterOffer > 0) {
                Navigator.of(context).pop(counterOffer);
              } else {
                showToast(context, localizations.enterValidAmount, null, true);
              }
            },
            child: Text(localizations.propose),
          ),
        ],
      ),
    );
    
    if (result != null) {
      await _proposeFare(result);
    }
  }
  
  Future<void> _proposeFare(double fare) async {
    final localizations = AppLocalizations.of(context)!;

    if (_ride == null) return;
    
    setState(() {
      _isPerformingAction = true;
    });
    
    try {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      // Update the local state before sending to Firebase
      if (isRider) {
        setState(() {
          _riderProposedFare = fare;
        });
      } else {
        setState(() {
          _passengerProposedFare = fare;
        });
      }
      final success = await rideProvider.proposeFare(
        _ride!.id,
        fare,
        isRider,
      );
      
      if (success) {
        showToast(context, localizations.fareProposalSent, null, false);
      } else {
        showToast(context, rideProvider.errorMessage ?? localizations.failedToProposeFare, null, true);
      }
    } catch (e) {
      showToast(context, 'Error ${e.toString()}', null, true);
    } finally {
      if (mounted) {
        setState(() {
          _isPerformingAction = false;
        });
      }
    }
  }
  
  Future<void> _acceptFareProposal(double fare) async {
    final localizations = AppLocalizations.of(context)!;

    if (_ride == null) return;
    
    setState(() {
      _isPerformingAction = true;
    });
    
    try {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      
      final success = await rideProvider.acceptFareProposal(
        _ride!.id,
        fare,
      );
      
      if (success) {
        showToast(context, localizations.fareAccepted, null, false);
      } else {
        showToast(context, rideProvider.errorMessage ?? localizations.failedToAcceptFare, null, true);
      }
    } catch (e) {
      showToast(context, 'Error: ${e.toString()}', null, true);
    } finally {
      if (mounted) {
        setState(() {
          _isPerformingAction = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return LoadingOverlay(
      isLoading: _isLoading || _isPerformingAction,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(localizations.rideDetails),
          elevation: 0,
        ),
        body: _ride == null
            ? Center(child: Text(localizations.loadingRideDetails))
            : Column(
                children: [
                  // Map
                  Expanded(
                    flex: 3,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _ride!.pickup,
                        zoom: 15,
                      ),
                      myLocationEnabled: true,
                      markers: _markers,
                      polylines: _polylines,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _updateMapMarkers();
                      },
                    ),
                  ),
                  
                  // Ride details
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status card
                          _buildStatusCard(),
                          const SizedBox(height: 16),
                          
                          // Ride info card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations.rideInformation,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  
                                  // Locations
                                  _buildInfoRow(
                                    Icons.location_on,
                                    Colors.green,
                                    localizations.pickup,
                                    _pickupAddress ?? localizations.currentLocation
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.location_on,
                                    Colors.red,
                                    localizations.dropoff,
                                    _dropoffAddress ?? localizations.destination,
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // Fare
                                  _buildInfoRow(
                                    Icons.money,
                                    Colors.blue,
                                    localizations.fare,
                                      _getFareDisplayText(),
                                  ),
                                  
                                  if (_ride!.distance != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: _buildInfoRow(
                                        Icons.straighten,
                                        Colors.purple,
                                        localizations.distanceOnly,
                                        '${_ride!.distance!.toStringAsFixed(2)} km',
                                      ),
                                    ),
                                    
                                  if (_ride!.duration != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: _buildInfoRow(
                                        Icons.timer,
                                        Colors.orange,
                                        localizations.duration,
                                        '${_ride!.duration!.toStringAsFixed(0)} min',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // User info card
                          _buildUserInfoCard(),
                          const SizedBox(height: 16),
                          
                          // Action buttons
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
  
  Widget _buildStatusCard() {
    final localizations = AppLocalizations.of(context)!;
    if (_ride == null) return const SizedBox.shrink();
    
    String statusText = '';
    Color statusColor = Colors.grey;
    
    switch (_ride!.status) {
      case RideStatus.requested:
        statusText = localizations.rideRequested;
        statusColor = Colors.blue;
        break;
      case RideStatus.negotiating:
        statusText = localizations.fareNegotiation;
        statusColor = Colors.amber;
        break;
      case RideStatus.accepted:
        statusText = localizations.rideAccepted;
        statusColor = Colors.green;
        break;
      case RideStatus.inProgress:
        statusText = localizations.rideInProgress;
        statusColor = Colors.orange;
        break;
      case RideStatus.completed:
        statusText = localizations.rideCompleted;
        statusColor = Colors.purple;
        break;
      case RideStatus.cancelled:
        statusText = localizations.rideCancelled;
        statusColor = Colors.red;
        break;
    }
    
    return Card(
      color: statusColor.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _getStatusIcon(),
              color: statusColor,
              size: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: statusColor,
                    ),
                  ),
                  if (_ride!.status == RideStatus.requested)
                    Text(localizations.waitingForRiderToAcceptYourRequest),
                  if (_ride!.status == RideStatus.negotiating)
                    Text(localizations.discussingFareWithRider),
                  if (_ride!.status == RideStatus.accepted && isPassenger)
                    Text(localizations.riderIsOnTheWayToYourLocation),
                  if (_ride!.status == RideStatus.accepted && isRider)
                    Text(localizations.headingToPickupLocation),
                  if (_ride!.status == RideStatus.inProgress && isPassenger)
                    Text(localizations.onTheWayToYourDestination),
                  if (_ride!.status == RideStatus.inProgress && isRider)
                    Text(localizations.takingPassengerToDestination),
                  if (_ride!.status == RideStatus.completed)
                    Text(localizations.thankYouForRidingWithApp),
                  if (_ride!.status == RideStatus.cancelled)
                    Text(localizations.thisRideCancelled),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getStatusIcon() {
    if (_ride == null) return Icons.error_outline;
    
    switch (_ride!.status) {
      case RideStatus.requested:
        return Icons.search_outlined;
      case RideStatus.negotiating:
        return Icons.attach_money_outlined;
      case RideStatus.accepted:
        return Icons.motorcycle;
      case RideStatus.inProgress:
        return Icons.directions_outlined;
      case RideStatus.completed:
        return Icons.check_circle_outline;
      case RideStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  String _getFareDisplayText() {
    final localizations = AppLocalizations.of(context)!;
    if (_ride == null) return localizations.notAvailable;
    
    if (_ride!.agreedFare != null) {
      return '${_ride!.agreedFare} RWF (${localizations.agreed})';
    }
    
    if (_ride!.status == RideStatus.negotiating) {
      // In negotiation state, show both rider and passenger proposed fares if available
      if (isRider) {
        // Rider's view: show passenger's proposed fare
        return '${_ride!.proposedFare} RWF (${localizations.passengersOffer})';
      } else {
        // Passenger's view: show their own proposed fare
        return '${_ride!.proposedFare} RWF (${localizations.yourOffer})';
      }
    }
    
    // Default display for proposed fare
    return '${_ride!.proposedFare} RWF (${localizations.proposed})';
  }
  
  Widget _buildInfoRow(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildUserInfoCard() {
    final localizations = AppLocalizations.of(context)!;

    if (_ride == null) return const SizedBox.shrink();
    
    final bool showRider = isPassenger && _rider != null;
    final bool showPassenger = isRider && _passenger != null;
        
    if (!showRider && !showPassenger) {
      return const SizedBox.shrink();
    }
    
    final user = showRider ? _rider! : _passenger!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              showRider ? localizations.yourRider : localizations.yourPassenger,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey,
                  child: Icon(
                    Icons.person_outline,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        user.phone,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Call button
                IconButton(
                  icon: const Icon(Icons.phone_outlined),
                  color: Colors.green,
                  onPressed: () {
                    launchDialer(user.phone, context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButtons() {
    final localizations = AppLocalizations.of(context)!;

    if (_ride == null) return const SizedBox.shrink();
    
    // Passenger view - Ride requested
    if (isPassenger && _ride!.status == RideStatus.requested) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${localizations.waitingForRiderToAcceptYourRequest}...',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.onPrimary),
            label: Text(localizations.cancelRide),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: _cancelRide,
          ),
        ],
      );
    }
    
    // Passenger view - Negotiating
    if (isPassenger && _ride!.status == RideStatus.negotiating) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.fareNegotiation,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${localizations.yourOffer}: ${_passengerProposedFare ?? '0'} RWF'),
                  if (_riderProposedFare != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${localizations.ridersCounterOffer}: ${_riderProposedFare ?? '0'} RWF',
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_riderProposedFare != null)
                        Expanded(
                          child: ElevatedButton(
                            child: Text(localizations.acceptOffer),
                            onPressed: () => _acceptFareProposal(_riderProposedFare!),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          child: Text(localizations.counterOffer),
                          onPressed: () => _showFareNegotiationDialog,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.onPrimary),
            label: Text(localizations.cancelRide),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: _cancelRide,
          ),
        ],
      );
    }
    
    // Passenger view - Accepted
    if (isPassenger && _ride!.status == RideStatus.accepted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localizations.yourRideIsOnTheWay,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.onPrimary),
            label: Text(localizations.cancelRide),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: _cancelRide,
          ),
        ],
      );
    }
    
    // Passenger view - In progress
    if (isPassenger && _ride!.status == RideStatus.inProgress) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localizations.youAreOnYourWayToDestination,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      );
    }
    
    // Passenger view - Completed
    if (isPassenger && _ride!.status == RideStatus.completed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localizations.rideCompletedThanksForUsingApp,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          if (_ride!.riderRating == null)
            ElevatedButton.icon(
              icon: const Icon(Icons.star_outline),
              label: Text(localizations.rateThisRide),
              onPressed: _showRatingDialog,
            ),
        ],
      );
    }
    
    // Rider view - Ride requested
    if (isRider && _ride!.status == RideStatus.requested) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.rideRequest,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${localizations.passengersOffer}: ${_ride!.proposedFare} RWF'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          child: Text(localizations.acceptOffer),
                          onPressed: _acceptRideRequest,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          child: Text(localizations.counterOffer),
                          onPressed: _showFareNegotiationDialog,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.onPrimary),
            label: Text(localizations.rejectRequest),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: _cancelRide,
          ),
        ],
      );
    }
    
    // Rider view - Negotiating
    if (isRider && _ride!.status == RideStatus.negotiating) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.fareNegotiation,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${localizations.passengersOffer}: ${_passengerProposedFare ?? '0'} RWF'),
                  const SizedBox(height: 8),
                  if (_riderProposedFare != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${localizations.yourCounterOffer}: ${_riderProposedFare?.toStringAsFixed(0)} RWF',
                      ),
                    ),
                    const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          child: Text(localizations.acceptOffer),
                          onPressed: () => _acceptFareProposal(_passengerProposedFare!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _showFareNegotiationDialog,
                          child: Text(localizations.counterOffer),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.onPrimary),
            label: Text(localizations.rejectRequest),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: _cancelRide,
          ),
        ],
      );
    }
    
    // Rider view - Accepted
    if (isRider && _ride!.status == RideStatus.accepted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localizations.headToThePickupLocationToGetYourPassenger,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: Text(localizations.startRide),
                  onPressed: _startRide,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.onPrimary),
                  label: Text(localizations.cancel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: _cancelRide,
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    // Rider view - In progress
    if (isRider && _ride!.status == RideStatus.inProgress) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localizations.takeYourPassengerToDestination,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: Text(localizations.completeRide),
            onPressed: _completeRide,
          ),
        ],
      );
    }
    
    // Rider view - Completed
    if (isRider && _ride!.status == RideStatus.completed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localizations.thisRideCancelled,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      );
    }
    
    // Cancelled ride - both user types
    if (_ride!.status == RideStatus.cancelled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localizations.thisRideCancelled,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      );
    }
    
    return const SizedBox.shrink();
  }
}
