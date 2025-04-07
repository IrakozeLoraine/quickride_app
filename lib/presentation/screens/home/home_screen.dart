import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:quickride/data/models/ride_model.dart';
import 'package:quickride/data/providers/auth_provider.dart';
import 'package:quickride/data/providers/ride_provider.dart';
import 'package:quickride/presentation/widgets/location_permission_handler.dart';
import 'package:quickride/routes/app_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:quickride/data/providers/location_provider.dart';
import 'package:quickride/presentation/widgets/loading_overlay.dart';
import 'package:quickride/utils/app_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  GoogleMapController? _mapController;
  bool _isLoading = false;
  int _pendingRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    _checkForActiveRide();
    _getCurrentLocation();
    _checkPendingRequests();
  }

  @override
  void dispose() {
    _mapController?.dispose();
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
      if (locationProvider.errorMessage != null) {
        showToast(context, locationProvider.errorMessage!, null, true);
      }
      await locationProvider.getCurrentLocation();
      
      if (locationProvider.currentLatLng != null && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: locationProvider.currentLatLng!,
              zoom: 15,
            ),
          ),
        );
      }
    } catch (e) {
      showToast(context, 'Error getting location ${e.toString()}', null, true);
    }
  }

  Future<void> _checkPendingRequests() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.userModel == null) return;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('passengerId', isEqualTo: authProvider.userModel!.id)
          .where('status', whereIn: [
            RideStatus.requested.index,
            RideStatus.negotiating.index,
          ])
          .get();
      
      if (mounted) {
        setState(() {
          _pendingRequestsCount = snapshot.docs.length;
        });
      }
    } catch (e) {
      print('Error checking pending requests: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final locationProvider = Provider.of<LocationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    // Check if location permission is denied
    if (locationProvider.errorMessage != null && 
        locationProvider.errorMessage!.contains('Location permissions')) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(localizations.appTitle),
        ),
        body: LocationPermissionHandler(
          message: locationProvider.errorMessage!,
          onRetry: () async {
            LocationPermission permission = await Geolocator.requestPermission();
            if (permission != LocationPermission.denied && 
                permission != LocationPermission.deniedForever) {
              locationProvider.clearError();
              locationProvider.getCurrentLocation();
            }
          },
        ),
      );
    }

    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(localizations.appTitle),
          elevation: 0,
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.pending_actions),
                  tooltip: localizations.myRideRequest,
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRouter.rideRequests);
                  },
                ),
                if (_pendingRequestsCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _pendingRequestsCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.history_outlined),
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
                        Icons.person_outline,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      authProvider.userModel?.name ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      authProvider.userModel?.email ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
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
                leading: const Icon(Icons.pending_actions),
                title: Row(
                  children: [
                    Text(localizations.myRideRequest),
                    if (_pendingRequestsCount > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _pendingRequestsCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(AppRouter.rideRequests);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(localizations.profile),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(AppRouter.profile);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: Text(localizations.rideHistory),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(AppRouter.rideHistory);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(localizations.settings),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(AppRouter.setting);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout_outlined),
                title: Text(localizations.logout),
                onTap: () async {
                  Navigator.pop(context);
                  await authProvider.signOut();
                  Navigator.of(context).pushReplacementNamed(AppRouter.login);
                },
              ),
            ],
          ),
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            // Home Tab
            Column(
              children: [
                // Map
                Expanded(
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: locationProvider.currentLatLng ?? 
                              const LatLng(-1.9442, 30.0619), // Kigali, Rwanda as default
                          zoom: 15,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        mapType: MapType.normal,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          if (locationProvider.currentLatLng != null) {
                            controller.animateCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(
                                  target: locationProvider.currentLatLng!,
                                  zoom: 15,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      
                      // Find a ride button
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          children: [
                            if (_pendingRequestsCount > 0)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.pending_actions),
                                  label: Text('${localizations.checkRideRequests} ($_pendingRequestsCount)', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        color: Theme.of(context).colorScheme.primary,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(AppRouter.rideRequests);
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                            // Find a ride button
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.motorcycle),
                                label: Text(localizations.findARide),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pushNamed(AppRouter.findRide);
                                },
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Profile Tab
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRouter.profile);
                },
                child: Text(localizations.profile),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
