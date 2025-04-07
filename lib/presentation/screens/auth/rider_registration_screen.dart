import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickride/data/providers/auth_provider.dart';
import 'package:quickride/data/providers/location_provider.dart';
import 'package:quickride/presentation/widgets/loading_overlay.dart';
import 'package:quickride/routes/app_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:quickride/utils/app_utils.dart';

class RiderRegistrationScreen extends StatefulWidget {
  const RiderRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RiderRegistrationScreen> createState() => _RiderRegistrationScreenState();
}

class _RiderRegistrationScreenState extends State<RiderRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licenseController = TextEditingController();
  final _plateController = TextEditingController();
  final _motorcycleModelController = TextEditingController();
  
  bool _isProcessing = false;
  bool _isLocationLoading = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _licenseController.dispose();
    _plateController.dispose();
    _motorcycleModelController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      await locationProvider.getCurrentLocation();
      if (locationProvider.errorMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showToast(context, locationProvider.errorMessage!, null, true);
          }
        });

      }

    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showToast(context, 'Failed to get location: ${e.toString()}', null, true);
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
      }
    }
  }

  Future<void> _registerRider() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isProcessing = true;
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final locationProvider = Provider.of<LocationProvider>(context, listen: false);
        final localizations = AppLocalizations.of(context)!;
        
        // Check if location is available
        if (locationProvider.currentPosition == null) {
          await _getCurrentLocation();
          if (locationProvider.currentPosition == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                showToast(context, localizations.locationIsRequiredToRegisterAsRider, null, true);
              }
            });
            setState(() {
              _isProcessing = false;
            });
            return;
          }
        }
        if (locationProvider.errorMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showToast(context, locationProvider.errorMessage!, null, true);
            }
          });
        }

        
        // Create GeoPoint from current location
        final currentLocation = GeoPoint(
          locationProvider.currentPosition!.latitude,
          locationProvider.currentPosition!.longitude,
        );
        
        final success = await authProvider.registerRider(
          licenseNumber: _licenseController.text.trim(),
          plateNumber: _plateController.text.trim(),
          motorcycleModel: _motorcycleModelController.text.trim(),
          currentLocation: currentLocation,
        );

        if (success) {
          // Navigate to rider home screen
          Navigator.of(context).pushReplacementNamed(AppRouter.riderHome);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showToast(context, authProvider.errorMessage ?? localizations.failedToRegisterRider, null, true);
            }
          });
        }
      } catch (e) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showToast(context, e.toString(), null, true);
          }
        });
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return LoadingOverlay(
      isLoading: _isProcessing || _isLocationLoading,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(localizations.riderRegistration),
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    localizations.completeYourRiderProfile,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Subtitle
                  Text(
                    localizations.pleaseProvideMotorcycleDetails,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // License Number Field
                  TextFormField(
                    controller: _licenseController,
                    decoration: InputDecoration(
                      labelText: localizations.licenseNumber,
                      prefixIcon: const Icon(Icons.assignment_ind_outlined),
                      hintText: 'e.g. L12345678',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations.enterYourLicenseNumber;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Plate Number Field
                  TextFormField(
                    controller: _plateController,
                    decoration: InputDecoration(
                      labelText: localizations.plateNumber,
                      prefixIcon: const Icon(Icons.directions_bike_outlined),
                      hintText: 'e.g. RAB 123A',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations.enterYourPlateNumber;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Motorcycle Model Field
                  TextFormField(
                    controller: _motorcycleModelController,
                    decoration: InputDecoration(
                      labelText: localizations.motorcycleModel,
                      prefixIcon: const Icon(Icons.motorcycle),
                      hintText: 'e.g. Honda CG 125',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations.enterYourMotorcycleModel;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // Location Permission Info
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: Colors.amber),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(localizations.currentLocationWillBeUsedAsInitialPositionOnMap),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Register Button
                  ElevatedButton(
                    onPressed: _registerRider,
                    child: Text(localizations.registerButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
