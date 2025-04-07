import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickride/data/models/ride_model.dart';
import 'package:quickride/data/providers/auth_provider.dart';
import 'package:quickride/data/providers/ride_provider.dart';
import 'package:quickride/presentation/widgets/loading_overlay.dart';
import 'package:quickride/routes/app_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickride/utils/app_utils.dart';

class RideRequestsScreen extends StatefulWidget {
  const RideRequestsScreen({Key? key}) : super(key: key);

  @override
  State<RideRequestsScreen> createState() => _RideRequestsScreenState();
}

class _RideRequestsScreenState extends State<RideRequestsScreen> {
  bool _isLoading = true;
  List<RideModel> _pendingRequests = [];
  
  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }
  
  Future<void> _loadPendingRequests() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
      final snapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('passengerId', isEqualTo: authProvider.userModel!.id)
          .where('status', whereIn: [
            RideStatus.requested.index,
            RideStatus.negotiating.index,
          ])
          .orderBy('createdAt', descending: true)
          .get();
      
      setState(() {
        _pendingRequests = snapshot.docs
            .map((doc) => RideModel.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      showToast(context, 'Error loading ride requests: ${e.toString()}', null, true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _cancelRideRequest(String rideId) async {
    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.cancelRide),
        content: Text(localizations.confirmCancelRide),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.no)
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations.yes)
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      
      final success = await rideProvider.cancelRide(rideId);
      
      if (success) {
        showToast(context, localizations.rideCancelled, null, false);
        // Refresh list
        await _loadPendingRequests();
      } else {
        showToast(context, rideProvider.errorMessage ?? localizations.failedToCancelRide, null, true);
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
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: Text(localizations.myRideRequest),
          elevation: 0,
        ),
        body: RefreshIndicator(
          onRefresh: _loadPendingRequests,
          child: _pendingRequests.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _pendingRequests.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final request = _pendingRequests[index];
                    return _buildRequestCard(request);
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
              Icons.motorcycle_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              localizations.noPendingRideRequests,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localizations.yourPendingRideRequestsWillAppearHere,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text(localizations.refresh),
              onPressed: _loadPendingRequests,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(localizations.requestNewRide),
              onPressed: () {
                Navigator.of(context).pushNamed(AppRouter.findRide);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRequestCard(RideModel request) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    final timeAgo = _getTimeAgo(request.createdAt);
    final localization = AppLocalizations.of(context)!;
    final statusColor = request.status == RideStatus.requested
        ? Colors.blue
        : Colors.amber;
    final statusText = request.status == RideStatus.requested
        ? localization.waitingForRider
        : localization.fareNegotiation;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            AppRouter.rideDetails,
            arguments: {'rideId': request.id},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    request.status == RideStatus.requested
                        ? Icons.schedule
                        : Icons.attach_money,
                    color: statusColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.attach_money, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        '${localization.proposedFare}: ${request.proposedFare.toStringAsFixed(0)} RWF',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '(${request.pickup.latitude.toStringAsFixed(2)}, ${request.pickup.longitude.toStringAsFixed(2)})',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '(${request.dropoff.latitude.toStringAsFixed(2)}, ${request.dropoff.longitude.toStringAsFixed(2)})',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${localization.requested}: ${dateFormat.format(request.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.visibility),
                          label: Text(localization.view),
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              AppRouter.rideDetails,
                              arguments: {'rideId': request.id},
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.cancel, color: Colors.white),
                          label: Text(localization.cancel),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () => _cancelRideRequest(request.id),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
