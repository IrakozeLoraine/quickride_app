import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickride/data/models/ride_model.dart';
import 'package:quickride/data/providers/auth_provider.dart';
import 'package:quickride/data/providers/ride_provider.dart';
import 'package:quickride/presentation/widgets/loading_overlay.dart';
import 'package:quickride/routes/app_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:quickride/utils/app_utils.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({Key? key}) : super(key: key);

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  bool _isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadRideHistory();
  }
  
  Future<void> _loadRideHistory() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      
      if (authProvider.userModel != null) {
        await rideProvider.fetchRideHistory(
          authProvider.userModel!.id,
          authProvider.userModel!.userType,
        );
      }
    } catch (e) {
      showToast(context, 'Error loading ride history: ${e.toString()}', null, true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final rideProvider = Provider.of<RideProvider>(context);
    
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(localizations.rideHistory),
          elevation: 0,
        ),
        body: RefreshIndicator(
          onRefresh: _loadRideHistory,
          child: rideProvider.rideHistory.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: rideProvider.rideHistory.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final ride = rideProvider.rideHistory[index];
                    return _buildRideCard(ride);
                  },
                ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    final localizations = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              localizations.noRideHistory,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localizations.yourCompletedRidesWillAppearHere,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh_outlined, color: Colors.white),
              label: Text(localizations.refresh),
              onPressed: _loadRideHistory,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRideCard(RideModel ride) {
    final dateFormat = DateFormat('MMM d, yyyy - h:mm a');
    final bool isCompleted = ride.status == RideStatus.completed;
    final localizations = AppLocalizations.of(context)!;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            AppRouter.rideDetails,
            arguments: {'rideId': ride.id},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status and date
              Row(
                children: [
                  _buildStatusIndicator(ride.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getStatusText(ride.status),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    dateFormat.format(ride.createdAt),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Divider(),
              
              // Fare
              Row(
                children: [
                  const Icon(Icons.attach_money_outlined, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    '${localizations.fare}: ${(isCompleted && ride.agreedFare != null) ? ride.agreedFare : ride.proposedFare} RWF',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Distance if available
              if (ride.distance != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.straighten_outlined, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        localizations.distance(double.parse(ride.distance!.toStringAsFixed(2))),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              
              // Rating if available
              if (isCompleted && ride.riderRating != null)
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      '${localizations.rating}: ${ride.riderRating}/5',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusIndicator(RideStatus status) {
    Color color;
    
    switch (status) {
      case RideStatus.requested:
        color = Colors.blue;
        break;
      case RideStatus.negotiating:
        color = Colors.amber;
        break;
      case RideStatus.accepted:
        color = Colors.green;
        break;
      case RideStatus.inProgress:
        color = Colors.orange;
        break;
      case RideStatus.completed:
        color = Colors.purple;
        break;
      case RideStatus.cancelled:
        color = Colors.red;
        break;
    }
    
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
  
  String _getStatusText(RideStatus status) {
    final localizations = AppLocalizations.of(context)!;

    switch (status) {
      case RideStatus.requested:
        return localizations.requested;
      case RideStatus.negotiating:
        return localizations.negotiating;
      case RideStatus.accepted:
        return localizations.accepted;
      case RideStatus.inProgress:
        return localizations.inProgress;
      case RideStatus.completed:
        return localizations.completed;
      case RideStatus.cancelled:
        return localizations.cancelled;
    }
  }
}
