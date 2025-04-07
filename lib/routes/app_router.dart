import 'package:flutter/material.dart';
import 'package:quickride/presentation/screens/auth/forgot_password_screen.dart';
import 'package:quickride/presentation/screens/auth/login_screen.dart';
import 'package:quickride/presentation/screens/auth/registration_screen.dart';
import 'package:quickride/presentation/screens/auth/rider_registration_screen.dart';
import 'package:quickride/presentation/screens/auth/user_type_selection_screen.dart';
import 'package:quickride/presentation/screens/home/home_screen.dart';
import 'package:quickride/presentation/screens/home/rider_home_screen.dart';
import 'package:quickride/presentation/screens/ride/find_ride_screen.dart';
import 'package:quickride/presentation/screens/ride/ride_details_screen.dart';
import 'package:quickride/presentation/screens/ride/ride_history_screen.dart';
import 'package:quickride/presentation/screens/ride/ride_requests_screen.dart';
import 'package:quickride/presentation/screens/settings/language_selection_screen.dart';
import 'package:quickride/presentation/screens/settings/profile_screen.dart';
import 'package:quickride/presentation/screens/settings/settings_screen.dart';
import 'package:quickride/presentation/screens/splash/splash_screen.dart';

class AppRouter {
  // Route names
  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String userTypeSelection = '/user-type-selection';
  static const String registration = '/registration';
  static const String riderRegistration = '/rider-registration';
  static const String home = '/home';
  static const String riderHome = '/rider-home';
  static const String findRide = '/find-ride';
  static const String rideDetails = '/ride-details';
  static const String rideHistory = '/ride-history';
  static const String rideRequests = '/ride-requests';
  static const String profile = '/profile';
  static const String setting = '/settings';
  static const String languageSelection = '/language-selection';

  // Route generator
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      
      case userTypeSelection:
        return MaterialPageRoute(builder: (_) => const UserTypeSelectionScreen());
      
      case registration:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => RegistrationScreen(
            userType: args['userType'],
          ),
        );
      
      case riderRegistration:
        return MaterialPageRoute(builder: (_) => const RiderRegistrationScreen());
      
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      
      case riderHome:
        return MaterialPageRoute(builder: (_) => const RiderHomeScreen());
      
      case findRide:
        return MaterialPageRoute(builder: (_) => const FindRideScreen());
      
      case rideDetails:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => RideDetailsScreen(
            rideId: args?['rideId'] ?? '',
          ),
        );
      
      case rideHistory:
        return MaterialPageRoute(builder: (_) => const RideHistoryScreen());

      case rideRequests:
        return MaterialPageRoute(builder: (_) => const RideRequestsScreen());
      
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      
      case setting:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      
      case languageSelection:
        return MaterialPageRoute(builder: (_) => const LanguageSelectionScreen());
      
      default:
        // If the route is not found, return an error page
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: const Text('Error'),
            ),
            body: const Center(
              child: Text('Route not found!'),
            ),
          ),
        );
    }
  }
}
