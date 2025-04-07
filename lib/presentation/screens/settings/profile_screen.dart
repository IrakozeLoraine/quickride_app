import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickride/data/providers/auth_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;
    final rider = authProvider.riderModel;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.profile),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile avatar
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey,
              child: Icon(
                Icons.person_outline,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            
            // User name
            Text(
              user?.name ?? localizations.user,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            
            // User type badge
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                user?.userType.toString().split('.').last.toUpperCase() ?? localizations.passenger,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Personal information card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.personalInformation,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    
                    // Phone
                    ListTile(
                      leading: const Icon(Icons.phone_outlined),
                      title: Text(localizations.phoneNumber),
                      subtitle: Text(user?.phone ?? localizations.notAvailable),
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    // Email
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: Text(localizations.email),
                      subtitle: Text(user?.email ?? localizations.notAvailable),
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    // Account created date
                    if (user?.createdAt != null)
                      ListTile(
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: Text(localizations.memberSince),
                        subtitle: Text(
                          '${user!.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Rider information (if applicable)
            if (rider != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.riderInformation,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(),
                      
                      // License number
                      ListTile(
                        leading: const Icon(Icons.credit_card_outlined),
                        title: Text(localizations.licenseNumber),
                        subtitle: Text(rider.licenseNumber),
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      // Plate number
                      ListTile(
                        leading: const Icon(Icons.directions_bike_outlined),
                        title: Text(localizations.plateNumber),
                        subtitle: Text(rider.plateNumber),
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      // Motorcycle model
                      ListTile(
                        leading: const Icon(Icons.motorcycle),
                        title: Text(localizations.motorcycleModel),
                        subtitle: Text(rider.motorcycleModel),
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      // Rating
                      ListTile(
                        leading: const Icon(Icons.star, color: Colors.amber),
                        title: Text(localizations.rating),
                        subtitle: Text(
                          '${rider.rating.toStringAsFixed(1)} ★ (${rider.totalRides} ${localizations.rides})',
                        ),
                        contentPadding: EdgeInsets.zero,
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
}
