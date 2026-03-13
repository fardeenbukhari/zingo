import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../providers/mock_data.dart';
import 'manage_ride_screen.dart';

class HostedActivitiesScreen extends StatelessWidget {
  const HostedActivitiesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final FirebaseService _firebaseService = FirebaseService();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Managed Broadcasts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF181818),
        elevation: 0,
      ),
      body: StreamBuilder<List<ActivityIntent>>(
        stream: _firebaseService.getintentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final myIntents =
              snapshot.data
                  ?.where((i) => i.userId == currentUser.userId)
                  .toList() ??
              [];

          if (myIntents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.radar,
                    size: 64,
                    color: Colors.white.withOpacity(0.05),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Active Broadcasts',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start one from the Radar map',
                    style: TextStyle(color: Colors.white24, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myIntents.length,
            itemBuilder: (context, index) {
              final intent = myIntents[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.all(20),
                      leading: CircleAvatar(
                        backgroundColor: intent.color.withOpacity(0.1),
                        child: Icon(Icons.bolt, color: intent.color),
                      ),
                      title: Text(
                        intent.activity.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      subtitle: Text(
                        'Broadcasting to ${intent.radiusM}m radius',
                        style: const TextStyle(color: Colors.white38),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _showDeleteConfirmDialog(
                          context,
                          _firebaseService,
                          intent.intentId,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Row(
                        children: [
                          _buildChip(
                            '${intent.playersNeeded} slots',
                            Colors.white10,
                          ),
                          const SizedBox(width: 8),
                          _buildChip(intent.mode, Colors.white10),
                          const Spacer(),
                          if (intent.activity.toLowerCase().contains('cab'))
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ManageRideScreen(
                                        intent: intent,
                                        currentUserId: currentUser.userId,
                                        onEndBroadcast: () {
                                          _firebaseService.expireIntent(
                                            intent.intentId,
                                          );
                                        },
                                        onLeave: () {
                                          _firebaseService.leaveIntent(
                                            intent.intentId,
                                            currentUser.userId,
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.taxi_alert,
                                  color: Color(0xFF1DE9B6),
                                  size: 16,
                                ),
                                label: const Text(
                                  'MANAGE RIDE',
                                  style: TextStyle(
                                    color: Color(0xFF1DE9B6),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Color(0xFF1DE9B6),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    FirebaseService service,
    String id,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: const Text(
          'End Broadcast?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will remove your activity from the radar for all users.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white24),
            ),
          ),
          TextButton(
            onPressed: () {
              service.expireIntent(id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Broadcast ended successfully'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
