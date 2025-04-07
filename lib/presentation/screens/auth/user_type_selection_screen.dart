// File: lib/presentation/screens/auth/user_type_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:quickride/data/models/user_model.dart';
import 'package:quickride/routes/app_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class UserTypeSelectionScreen extends StatelessWidget {
  const UserTypeSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.registerTitle),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              
              // Title
              Text(
                '${localizations.howDoYouWantToUse} QuickRide?',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Passenger Option
              _UserTypeCard(
                icon: Icons.person_outline,
                title: localizations.continueAsPassenger,
                description: localizations.findMotorcycleRidersForQuickAndAffordableRides,
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AppRouter.registration,
                    arguments: {'userType': UserType.passenger},
                  );
                },
              ),
              const SizedBox(height: 24),
              
              // Rider Option
              _UserTypeCard(
                icon: Icons.motorcycle,
                title: localizations.continueAsRider,
                description: localizations.offerMotorcyleRidesAndEarnMoney,
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AppRouter.registration,
                    arguments: {'userType': UserType.rider},
                  );
                },
              ),

              // Language Selection
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.language_outlined),
                  label: Text(localizations.language),
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRouter.languageSelection);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _UserTypeCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                icon,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
