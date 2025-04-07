import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickride/data/providers/auth_provider.dart';
import 'package:quickride/data/providers/ride_provider.dart';
import 'package:quickride/data/models/user_model.dart';
import 'package:quickride/routes/app_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Simulate splash screen delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Check if user is logged in
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.isAuthenticated) {
      final userModel = authProvider.userModel;
      
      if (userModel != null) {
        // Check if user has any active rides
        final rideProvider = Provider.of<RideProvider>(context, listen: false);
        await rideProvider.checkForActiveRide(
          userModel.id, 
          userModel.userType,
        );
        
        // Navigate based on user type
        if (userModel.userType == UserType.rider) {
          Navigator.of(context).pushReplacementNamed(AppRouter.riderHome);
        } else {
          Navigator.of(context).pushReplacementNamed(AppRouter.home);
        }
      } else {
        // User is authenticated but no user model exists, go to login
        Navigator.of(context).pushReplacementNamed(AppRouter.login);
      }
    } else {
      // User is not logged in, go to login screen
      Navigator.of(context).pushReplacementNamed(AppRouter.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.motorcycle,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            
            // App name
            Text(
              localizations.appTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
