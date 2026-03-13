import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/models.dart';
import '../providers/mock_data.dart';
import 'package:geolocator/geolocator.dart';
import '../screens/manage_ride_screen.dart';
import '../services/firebase_service.dart';

class ActivityCard extends StatelessWidget {
  final ActivityIntent intent;
  final VoidCallback onClose;
  final Function(ActivityIntent) onJoin;
  final VoidCallback? onDelete;
  final LocationPoint? userPos;

  const ActivityCard({
    Key? key,
    required this.intent,
    required this.onClose,
    required this.onJoin,
    this.onDelete,
    this.userPos,
  }) : super(key: key);

  void _showFullScreenImage(
    BuildContext context,
    String imagePath,
    String tag,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) => Scaffold(
          backgroundColor: Colors.black.withOpacity(0.9),
          body: Stack(
            children: [
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Hero(
                    tag: tag,
                    child: imagePath.startsWith('http') || kIsWeb
                        ? Image.network(imagePath, fit: BoxFit.contain)
                        : Image.file(File(imagePath), fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 50,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMyActivity = intent.userId == currentUser.userId;

    bool isTooFar = false;
    if (!isMyActivity && userPos != null) {
      double dist = Geolocator.distanceBetween(
        userPos!.lat,
        userPos!.lng,
        intent.location.lat,
        intent.location.lng,
      );
      if (dist > 2000) {
        isTooFar = true;
      }
    }

    final heroTag = 'avatar_card_${intent.intentId}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () =>
                    _showFullScreenImage(context, intent.userAvatar, heroTag),
                child: Hero(
                  tag: heroTag,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1DE9B6).withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundImage:
                          intent.userAvatar.startsWith('http') || kIsWeb
                          ? NetworkImage(intent.userAvatar) as ImageProvider
                          : FileImage(File(intent.userAvatar)),
                      backgroundColor: Colors.black.withOpacity(0.05),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      intent.activity.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      intent.userName,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isMyActivity && onDelete != null)
                TextButton.icon(
                  onPressed: () => _showDeleteConfirmDialog(context),
                  icon: const Icon(
                    Icons.stop_circle_outlined,
                    color: Colors.redAccent,
                    size: 16,
                  ),
                  label: const Text(
                    'END',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              if (isMyActivity && intent.activity.toLowerCase().contains('cab'))
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManageRideScreen(
                          intent: intent,
                          currentUserId:
                              intent.userId, // since isMyActivity is true
                          onEndBroadcast: () {
                            if (onDelete != null) onDelete!();
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
                    'MANAGE',
                    style: TextStyle(
                      color: Color(0xFF1DE9B6),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black26, size: 24),
                onPressed: onClose,
              ),
            ],
          ),
          if (intent.description != null) ...[
            const SizedBox(height: 16),
            Text(
              intent.description!,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          if (intent.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: intent.tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    Icons.people,
                    '${intent.playersNeeded} slots',
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.location_on,
                    '${intent.radiusM}m',
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.access_time,
                    '${intent.expiresAt.difference(DateTime.now()).inMinutes}m left',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!isMyActivity)
            (() {
              final isFull =
                  intent.currentParticipants.length >= intent.playersNeeded;
              final isJoined = intent.currentParticipants.contains(
                currentUser.userId,
              );

              if (isJoined) {
                if (intent.activity.toLowerCase().contains('cab')) {
                  return ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ManageRideScreen(
                            intent: intent,
                            currentUserId: currentUser.userId,
                            onEndBroadcast: () {}, // Host only function
                            onLeave: () {
                              FirebaseService().leaveIntent(
                                intent.intentId,
                                currentUser.userId,
                              );
                            },
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1DE9B6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(
                          color: Color(0xFF1DE9B6),
                          width: 2,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'MANAGE RIDE',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                } else {
                  return const Center(
                    child: Text(
                      'YOU HAVE JOINED',
                      style: TextStyle(
                        color: Color(0xFF1DE9B6),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
              }

              return ElevatedButton(
                onPressed: (isFull || isTooFar) ? null : () => onJoin(intent),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isFull || isTooFar)
                      ? Colors.grey[300]
                      : const Color(0xFF1DE9B6),
                  foregroundColor: (isFull || isTooFar)
                      ? Colors.grey[500]
                      : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isFull
                      ? 'GROUP FULL'
                      : isTooFar
                      ? 'TOO FAR'
                      : 'JOIN INSTANTLY',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            })()
          else
            const Center(
              child: Text(
                'YOUR ACTIVE BROADCAST',
                style: TextStyle(
                  color: Color(0xFF1DE9B6),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: const Text(
          'End Broadcast?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to stop this activity? It will disappear from the radar for everyone.',
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
              Navigator.pop(context);
              if (onDelete != null) onDelete!();
            },
            child: const Text(
              'End Broadcast',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF1DE9B6)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
