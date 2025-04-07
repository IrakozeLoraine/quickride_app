import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickride/data/providers/auth_provider.dart';
import 'package:quickride/data/providers/location_provider.dart';
import 'package:quickride/data/providers/ride_provider.dart';
import 'package:quickride/routes/app_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickride/data/models/ride_model.dart';
import 'package:quickride/presentation/widgets/loading_overlay.dart';
import 'package:quickride/utils/app_utils.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({Key? key}) : super(key: key);

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  GoogleMapController? _mapController;
  bool _isLoading = false;
  bool _isOnline = false;
  Timer? _locationUpdateTimer;
  StreamSubscription? _rideRequestSubscription;
  List<RideModel> _nearbyRequests = [];

  // Maps configuration
  MapType _currentMapType = MapType.normal;
  bool _trafficEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkForActiveRide();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _locationUpdateTimer?.cancel();
    _rideRequestSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkForActiveRide() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      
      if (authProvider.userModel != null) {
        await rideProvider.checkForActiveRide(
          authProvider.userModel!.id,
          authProvider.userModel!.userType,
        );
        
        if (rideProvider.hasActiveRide && rideProvider.currentRide != null) {
          // Navigate to ride details screen if there is an active ride
          Navigator.of(context).pushNamed(
            AppRouter.rideDetails,
            arguments: {'rideId': rideProvider.currentRide!.id},
          );
        }
      }
    } catch (e) {
      showToast(context, 'Error: ${e.toString()}', null, true);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      await locationProvider.getCurrentLocation();
      
      if (locationProvider.currentLatLng != null && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: locationProvider.currentLatLng!,
              zoom: 16,
            ),
          ),
        );
      }
    } catch (e) {
      showToast(context, 'Error getting location: ${e.toString()}', null, true);
    }
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal 
          ? MapType.satellite 
          : MapType.normal;
    });
  }
  
  void _toggleTraffic() {
    setState(() {
      _trafficEnabled = !_trafficEnabled;
    });
  }

  void _toggleOnlineStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (_isOnline) {
      // Going offline
      _locationUpdateTimer?.cancel();
      _rideRequestSubscription?.cancel();
      
      // Update rider status in Firestore
      try {
        await FirebaseFirestore.instance
            .collection('riders')
            .doc(authProvider.user!.uid)
            .update({
          'isAvailable': false,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      } catch (e) {
        showToast(context, 'Error updating status: ${e.toString()}', null, true);
      }
    } else {
      // Going online
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final localizations = AppLocalizations.of(context)!;
      await locationProvider.getCurrentLocation();
      
      if (locationProvider.currentPosition == null) {
        showToast(context, localizations.cannotGoOnlineLocationUnavailable, null, true);
        return;
      }
      
      // Update rider status and location in Firestore
      try {
        await FirebaseFirestore.instance
            .collection('riders')
            .doc(authProvider.user!.uid)
            .update({
          'isAvailable': true,
          'currentLocation': GeoPoint(
            locationProvider.currentPosition!.latitude,
            locationProvider.currentPosition!.longitude,
          ),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
        
        // Start periodic location updates
        _locationUpdateTimer = Timer.periodic(
          const Duration(minutes: 1),
          (_) => _updateRiderLocation(),
        );
        
        // Listen for nearby ride requests
        _listenForRideRequests();
      } catch (e) {
        showToast(context, 'Error updating status: ${e.toString()}', null, true);
      }
    }
    
    setState(() {
      _isOnline = !_isOnline;
    });
  }

  Future<void> _updateRiderLocation() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      
      await locationProvider.getCurrentLocation();
      await locationProvider.updateRiderLocation(authProvider.user!.uid);
    } catch (e) {
      print('Error updating location: ${e.toString()}');
    }
  }

  void _listenForRideRequests() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.currentPosition == null) return;
    
    // Search radius (in degrees, approximately 5km)
    const double searchRadiusDegrees = 0.045;
    
    final currentLat = locationProvider.currentPosition!.latitude;
    final currentLng = locationProvider.currentPosition!.longitude;
    
    // Query for ride requests within radius that are in 'requested' status
    _rideRequestSubscription = FirebaseFirestore.instance
        .collection('rides')
        .where('status', isEqualTo: RideStatus.requested.index)
        .where('riderId', isNull: true)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isEmpty) {
            setState(() {
              _nearbyRequests = [];
            });
            return;
          }
          
          // Filter by distance
          final nearbyRides = snapshot.docs
              .map((doc) => RideModel.fromFirestore(doc))
              .where((ride) {
                final pickupLat = ride.pickup.latitude;
                final pickupLng = ride.pickup.longitude;
                
                // Rough distance check (Manhattan distance)
                return (pickupLat - currentLat).abs() <= searchRadiusDegrees &&
                       (pickupLng - currentLng).abs() <= searchRadiusDegrees;
              })
              .toList();
          
          setState(() {
            _nearbyRequests = nearbyRides;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final locationProvider = Provider.of<LocationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(localizations.appTitle),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.of(context).pushNamed(AppRouter.rideHistory);
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      authProvider.userModel?.name ?? 'Rider',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      authProvider.userModel?.phone ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(localizations.profile),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(AppRouter.profile);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(localizations.rideHistory),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(AppRouter.rideHistory);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: Text(localizations.settings),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(AppRouter.setting);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(localizations.logout),
                onTap: () async {
                  Navigator.pop(context);
                  
                  // Go offline before logout
                  if (_isOnline) {
                    _toggleOnlineStatus();
                  }
                  
                  await authProvider.signOut();
                  Navigator.of(context).pushReplacementNamed(AppRouter.login);
                },
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Online/Offline Status Switch
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: _isOnline ? Colors.green.shade700 : Colors.grey.shade700,
              child: Row(
                children: [
                  Icon(
                    _isOnline ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isOnline 
                      ? localizations.availableForRides 
                      : localizations.unavailableForRides,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _isOnline,
                    onChanged: (_) => _toggleOnlineStatus(),
                    activeColor: Colors.white,
                    activeTrackColor: Colors.green.shade300,
                  ),
                ],
              ),
            ),
            
            // Map
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: locationProvider.currentLatLng ?? 
                          const LatLng(-1.9442, 30.0619), // Kigali, Rwanda as default
                      zoom: 16,
                    ),
                    myLocationEnabled: true, // Shows the blue dot for current location
                    myLocationButtonEnabled: false, // We'll add our own button for better customization
                    mapType: _currentMapType, // Standard map with roads, buildings, etc.
                    trafficEnabled: _trafficEnabled, // Traffic data layer
                    buildingsEnabled: true, // 3D building models where available
                    compassEnabled: true, // Compass indicator for orientation
                    zoomControlsEnabled: false, // We'll add custom zoom controls
                    indoorViewEnabled: true, // Indoor maps for supported buildings
                    mapToolbarEnabled: false, // Disable default map toolbar
                    tiltGesturesEnabled: true, // Allow tilting the map with gestures
                    rotateGesturesEnabled: true, // Allow rotating the map with gestures
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (locationProvider.currentLatLng != null) {
                        controller.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: locationProvider.currentLatLng!,
                              zoom: 16,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  
                  // Custom Map Controls
                  Positioned(
                    right: 16,
                    bottom: 240,
                    child: Column(
                      children: [
                        // My Location Button
                        FloatingActionButton.small(
                          heroTag: 'my_location',
                          backgroundColor: Colors.white,
                          onPressed: _getCurrentLocation,
                          child: const Icon(Icons.my_location, color: Colors.blue),
                        ),
                        const SizedBox(height: 8),
                        
                        // Zoom In
                        FloatingActionButton.small(
                          heroTag: 'zoom_in',
                          backgroundColor: Colors.white,
                          onPressed: () {
                            _mapController?.animateCamera(CameraUpdate.zoomIn());
                          },
                          child: const Icon(Icons.add, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        
                        // Zoom Out
                        FloatingActionButton.small(
                          heroTag: 'zoom_out',
                          backgroundColor: Colors.white,
                          onPressed: () {
                            _mapController?.animateCamera(CameraUpdate.zoomOut());
                          },
                          child: const Icon(Icons.remove, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        
                        // Toggle Map Type (Normal/Satellite)
                        FloatingActionButton.small(
                          heroTag: 'map_type',
                          backgroundColor: Colors.white,
                          onPressed: _toggleMapType,
                          child: const Icon(Icons.layers, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        
                        // Toggle Traffic
                        FloatingActionButton.small(
                          heroTag: 'traffic',
                          backgroundColor: _trafficEnabled ? Colors.blue : Colors.white,
                          onPressed: _toggleTraffic,
                          child: Icon(
                            Icons.traffic,
                            color: _trafficEnabled ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Nearby requests panel
                  if (_isOnline && _nearbyRequests.isNotEmpty)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                '${localizations.rideRequest} (${_nearbyRequests.length})',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _nearbyRequests.length,
                                itemBuilder: (context, index) {
                                  final request = _nearbyRequests[index];
                                  return ListTile(
                                    title: Text(
                                      '${localizations.rideRequest} #${request.id.substring(0, 4)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      '${localizations.fare}: ${request.proposedFare} RWF',
                                    ),
                                    trailing: ElevatedButton(
                                      child: Text(localizations.view),
                                      onPressed: () {
                                        Navigator.of(context).pushNamed(
                                          AppRouter.rideDetails,
                                          arguments: {'rideId': request.id},
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        // floatingActionButton: FloatingActionButton.extended(
        //   onPressed: _toggleOnlineStatus,
        //   icon: Icon(_isOnline ? Icons.pause : Icons.play_arrow),
        //   label: Text(_isOnline ? localizations.goOffline : localizations.goOnline),
        //   backgroundColor: _isOnline ? Colors.red : Colors.green,
        // ),
      ),
    );
  }
}
