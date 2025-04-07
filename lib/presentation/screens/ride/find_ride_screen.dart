import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:quickride/config/app_config.dart';
import 'package:quickride/data/providers/auth_provider.dart';
import 'package:quickride/data/providers/location_provider.dart';
import 'package:quickride/data/providers/ride_provider.dart';
import 'package:quickride/presentation/widgets/loading_overlay.dart';
import 'package:quickride/routes/app_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:quickride/utils/app_utils.dart';

class FindRideScreen extends StatefulWidget {
  const FindRideScreen({Key? key}) : super(key: key);

  @override
  State<FindRideScreen> createState() => _FindRideScreenState();
}

class _FindRideScreenState extends State<FindRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fareController = TextEditingController();
  
  bool _isLoading = false;
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  String _pickupAddress = '';
  String _dropoffAddress = '';
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  
  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      await _getCurrentLocation();
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.userModel != null) {
        final locationsProvider = Provider.of<LocationProvider>(context, listen: false);
        await locationsProvider.loadSavedLocations(authProvider.userModel!.id);
      }
    } catch (e) {
      showToast(context, 'Error initializing: ${e.toString()}', null, true);
    }
  }
  
  @override
  void dispose() {
    _fareController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
  
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      await locationProvider.getCurrentLocation();

      if (locationProvider.errorMessage != null) {
        showToast(context, locationProvider.errorMessage!, null, true);
      }

      if (locationProvider.currentLatLng != null) {
        setState(() {
          _pickupLocation = locationProvider.currentLatLng;
          _pickupAddress = 'Current Location';
          _updateMarkers();
        });
      }
    } catch (e) {
      showToast(context, 'Error getting location: ${e.toString()}', null, true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _updateMarkers() {
    final localizations = AppLocalizations.of(context)!;
    Set<Marker> markers = {};
    
    if (_pickupLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: localizations.pickupLocation)
        ),
      );
    }
    
    if (_dropoffLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: _dropoffLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: localizations.dropoffLocation)
        ),
      );
    }
    
    setState(() {
      _markers = markers;
    });
    
    // Adjust camera to show both markers
    if (_pickupLocation != null && _dropoffLocation != null && _mapController != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _pickupLocation!.latitude < _dropoffLocation!.latitude
              ? _pickupLocation!.latitude
              : _dropoffLocation!.latitude,
          _pickupLocation!.longitude < _dropoffLocation!.longitude
              ? _pickupLocation!.longitude
              : _dropoffLocation!.longitude,
        ),
        northeast: LatLng(
          _pickupLocation!.latitude > _dropoffLocation!.latitude
              ? _pickupLocation!.latitude
              : _dropoffLocation!.latitude,
          _pickupLocation!.longitude > _dropoffLocation!.longitude
              ? _pickupLocation!.longitude
              : _dropoffLocation!.longitude,
        ),
      );
      
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    } else if (_pickupLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _pickupLocation!,
            zoom: 15,
          ),
        ),
      );
    }
  }
  
  Future<void> _requestRide() async {
    final localizations = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    
    if (_pickupLocation == null || _dropoffLocation == null) {
      showToast(context, localizations.selectPickUpAndDropOffLocation, null, true);
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      final locationsProvider = Provider.of<LocationProvider>(context, listen: false);
      
      // Add locations to recent list
      if (_pickupAddress != 'Current Location') {
        await locationsProvider.addToRecentLocations(
          address: _pickupAddress,
          location: _pickupLocation!,
        );
      }

      await locationsProvider.addToRecentLocations(
        address: _dropoffAddress,
        location: _dropoffLocation!,
      );
      
      final success = await rideProvider.requestRide(
        passengerId: authProvider.userModel!.id,
        pickup: _pickupLocation!,
        dropoff: _dropoffLocation!,
        proposedFare: double.parse(_fareController.text),
      );
      
      if (success && rideProvider.currentRide != null) {
        showToast(context, localizations.rideRequestSent, null, false);
        
        // Navigate to ride details screen
        Navigator.of(context).pushReplacementNamed(
          AppRouter.rideDetails,
          arguments: {'rideId': rideProvider.currentRide!.id},
        );
      } else {
        showToast(context, rideProvider.errorMessage ?? localizations.failedToRequestRide, null, true);
      }
    } catch (e) {
      showToast(context, 'Error: ${e.toString()}', null, true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveCurrentLocation() async {
    final localizations = AppLocalizations.of(context)!;
    if (_pickupAddress == 'Current Location' || _pickupLocation == null) {
      showToast(context, localizations.pleaseUseSpecificLocationToSave, null, true);
      return;
    }
    
    // Show dialog to get location name
    final name = await _showSaveLocationDialog(_pickupAddress);
    
    if (name != null && name.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final locationsProvider = Provider.of<LocationProvider>(context, listen: false);
        
        final success = await locationsProvider.saveLocation(
          userId: authProvider.userModel!.id,
          name: name,
          address: _pickupAddress,
          location: _pickupLocation!,
        );
        
        if (success) {
          showToast(context, localizations.locationSaved, null, false);
        } else {
          showToast(context, locationsProvider.errorMessage ?? localizations.failedToSaveLocation, null, true);
        }
      } catch (e) {
        showToast(context, 'Error ${e.toString()}', null, true);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _showSaveLocationDialog(String address) async {
    final nameController = TextEditingController(
      text: address.split(',').first, // Use first part of address as default name
    );
    
    final localizations = AppLocalizations.of(context)!;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.saveLocation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${localizations.address}: $address'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: localizations.locationName,
                hintText: localizations.locationHint,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final locationProvider = Provider.of<LocationProvider>(context);
    if (locationProvider.errorMessage != null) {
      showToast(context, locationProvider.errorMessage!, null, true);
    }

    
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(localizations.findARide),
          elevation: 0,
          actions: [
            if (_pickupLocation != null && _pickupAddress != 'Current Location')
              IconButton(
                icon: const Icon(Icons.bookmark_add_outlined),
                tooltip: localizations.saveCurrentLocation,
                onPressed: _saveCurrentLocation,
              ),
          ],
        ),
        body: Column(
          children: [
            // Map
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: locationProvider.currentLatLng ?? 
                      const LatLng(-1.9442, 30.0619), // Kigali, Rwanda as default
                  zoom: 15,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                mapType: MapType.normal,
                markers: _markers,
                onMapCreated: (controller) {
                  _mapController = controller;
                  if (_pickupLocation != null) {
                    controller.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: _pickupLocation!,
                          zoom: 15,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            
            // Ride request form
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pickup location
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => _buildLocationSearchSheet(
                            context,
                            isPickup: true,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations.pickup,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    _pickupAddress.isNotEmpty
                                        ? _pickupAddress
                                        : localizations.currentLocation,
                                    style: const TextStyle(
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Dropoff location
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => _buildLocationSearchSheet(
                            context,
                            isPickup: false,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations.dropoff,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    _dropoffAddress.isNotEmpty
                                        ? _dropoffAddress
                                        : localizations.destination,
                                    style: const TextStyle(
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Fare input
                    TextFormField(
                      controller: _fareController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: localizations.proposeFare,
                        prefixIcon: const Icon(Icons.money_outlined),
                        suffixText: 'RWF',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizations.enterFareAmount;
                        }
                        final fare = double.tryParse(value);
                        if (fare == null || fare <= 0) {
                          return localizations.enterFareValidAmount;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Request ride button
                    ElevatedButton(
                      onPressed: _requestRide,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(localizations.requestRide),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLocationSearchSheet(BuildContext context, {required bool isPickup}) {
    final localizations = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).primaryColor,
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_outlined),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isPickup 
                          ? localizations.selectPickupLocation
                          : localizations.selectDestination,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Use the google_places_flutter package for location search
              GooglePlaceAutoCompleteTextField(
                textEditingController: TextEditingController(),
                googleAPIKey: AppConfig.mapKey,
                inputDecoration: InputDecoration(
                  hintText: localizations.searchLocation,
                  prefixIcon: const Icon(Icons.search_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                debounceTime: 800,
                countries: const ["rw"], // Rwanda
                isLatLngRequired: true,
                getPlaceDetailWithLatLng: (Prediction prediction) {
                  // Handle location selection with coordinates
                  final lat = double.parse(prediction.lat!);
                  final lng = double.parse(prediction.lng!);
                  
                  setState(() {
                    if (isPickup) {
                      _pickupLocation = LatLng(lat, lng);
                      _pickupAddress = prediction.description!;
                    } else {
                      _dropoffLocation = LatLng(lat, lng);
                      _dropoffAddress = prediction.description!;
                    }
                    _updateMarkers();
                  });
                  
                  Navigator.of(context).pop();
                },
                itemClick: (Prediction prediction) {
                },
              ),
              
              const SizedBox(height: 16),
              
              // Current location option for pickup
              if (isPickup)
                ListTile(
                  leading: Icon(
                    Icons.my_location_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(localizations.useCurrentLocation),
                  onTap: () async {
                    await _getCurrentLocation();
                    Navigator.of(context).pop();
                  },
                ),
              
              const SizedBox(height: 16),
              
              // Saved locations section
              Consumer<LocationProvider>(
                builder: (context, locationsProvider, child) {
                  final savedLocations = locationsProvider.savedLocations
                      .where((loc) => loc.isFavorite)
                      .toList();
                  
                  return savedLocations.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(left: 16, bottom: 8),
                              child: Text(
                                localizations.savedPlaces,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: savedLocations.length > 3 
                                  ? 3 
                                  : savedLocations.length,
                              itemBuilder: (context, index) {
                                final location = savedLocations[index];
                                return _buildLocationTile(
                                  location.name,
                                  location.address,
                                  isPickup,
                                  location.location,
                                  icon: Icons.star,
                                  iconColor: Colors.amber,
                                );
                              },
                            ),
                            if (savedLocations.length > 3)
                              TextButton(
                                onPressed: () {
                                  // Show more saved locations
                                  _showAllSavedLocationsDialog(isPickup);
                                },
                                child: Text(localizations.seeAllSavedPlaces)
                              ),
                          ],
                        )
                      : const SizedBox.shrink();
                },
              ),

              const SizedBox(height: 8),

              // Recent locations section
              Consumer<LocationProvider>(
                builder: (context, locationsProvider, child) {
                  final recentLocations = locationsProvider.recentLocations;
                  
                  return recentLocations.isNotEmpty
                      ? Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              localizations.recentLocations,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (recentLocations.length > 1)
                              TextButton(
                                onPressed: () {
                                  // Show dialog to confirm clearing history
                                  _showClearHistoryDialog();
                                },
                                child: Text(localizations.clear),
                              ),
                          ],
                        ),
                      )
                      : const SizedBox.shrink();
                },
              ),
              Expanded(
                child: Consumer<LocationProvider>(
                  builder: (context, locationsProvider, child) {
                    final recentLocations = locationsProvider.recentLocations;
                    return recentLocations.isNotEmpty ?
                      ListView.builder(
                        controller: scrollController,
                        itemCount: recentLocations.length,
                        itemBuilder: (context, index) {
                          final location = recentLocations[index];
                          return _buildLocationTile(
                            location.name,
                            location.address,
                            isPickup,
                            location.location,
                            icon: Icons.history_outlined,
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          localizations.noRecentLocations,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationTile(
    String name,
    String address,
    bool isPickup,
    LatLng location, {
    IconData icon = Icons.location_on_outlined,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? Theme.of(context).colorScheme.primary,
      ),
      title: Text(name),
      subtitle: Text(
        address,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        setState(() {
          if (isPickup) {
            _pickupLocation = location;
            _pickupAddress = address;
          } else {
            _dropoffLocation = location;
            _dropoffAddress = address;
          }
          _updateMarkers();
        });
        Navigator.of(context).pop();
      },
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () {
          _showLocationOptionsMenu(name, address, location);
        },
      ),
    );
  }

  void _showLocationOptionsMenu(String name, String address, LatLng location) {
    final locationsProvider = Provider.of<LocationProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final localizations = AppLocalizations.of(context)!;
    
    // Check if this location is already saved
    final isSaved = locationsProvider.savedLocations
        .any((loc) => loc.address == address);
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(name),
                subtitle: Text(address),
              ),
              const Divider(),
              if (!isSaved)
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: Text(localizations.saveThisLocation),
                  onTap: () async {
                    Navigator.pop(context);
                    final locationName = await _showSaveLocationDialog(address);
                    
                    if (locationName != null && locationName.isNotEmpty) {
                      await locationsProvider.saveLocation(
                        userId: authProvider.userModel!.id,
                        name: locationName,
                        address: address,
                        location: location,
                      );
                      
                      showToast(context, localizations.locationSaved, null, false);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAllSavedLocationsDialog(bool isPickup) {
    final localizations = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Consumer<LocationProvider>(
              builder: (context, locationsProvider, child) {
                final savedLocations = locationsProvider.savedLocations;
                
                return Column(
                  children: [
                    AppBar(
                      title: Text(localizations.savedPlaces),
                      automaticallyImplyLeading: false,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Expanded(
                      child: savedLocations.isEmpty
                          ? Center(child: Text(localizations.noSavedPlaces))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: savedLocations.length,
                              itemBuilder: (context, index) {
                                final location = savedLocations[index];
                                return _buildLocationTile(
                                  location.name,
                                  location.address,
                                  isPickup,
                                  location.location,
                                  icon: location.isFavorite
                                      ? Icons.star
                                      : Icons.place,
                                  iconColor: location.isFavorite
                                      ? Colors.amber
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showClearHistoryDialog() async {
    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.clearHistory),
        content: Text(localizations.confirmClearHistory),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel)
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(localizations.clear),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final locationsProvider = Provider.of<LocationProvider>(context, listen: false);
      await locationsProvider.clearRecentLocations();
      showToast(context, localizations.recentLocationsCleared, null, false);
    }
  }
}
