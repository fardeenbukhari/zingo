import 'package:flutter/material.dart';
import 'dart:io';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../providers/mock_data.dart';
import 'main_navigation.dart';

class LiveEventsScreen extends StatelessWidget {
  const LiveEventsScreen({Key? key}) : super(key: key);

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
                    child: imagePath.startsWith('http')
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
    final FirebaseService _firebaseService = FirebaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text(
          'Live Feed',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
      ),
      body: StreamBuilder<List<ActivityIntent>>(
        stream: _firebaseService.getintentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.black),
            );
          }

          final List<ActivityIntent> userIntents = snapshot.data ?? [];

          if (userIntents.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.radar, size: 64, color: Colors.black12),
                  SizedBox(height: 16),
                  Text(
                    'No real-time broadcasts found',
                    style: TextStyle(color: Colors.black38),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: userIntents.length,
            itemBuilder: (context, index) {
              final intent = userIntents[index];
              return _buildEventTile(
                context,
                intent,
                _firebaseService,
                accent: intent.color,
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIconForActivity(String activity) {
    switch (activity.toLowerCase()) {
      case 'badminton':
        return Icons.sports_tennis;
      case 'coffee':
        return Icons.coffee;
      case 'study':
        return Icons.book;
      case 'hostel':
        return Icons.apartment;
      default:
        return Icons.bolt;
    }
  }

  Widget _buildEventTile(
    BuildContext context,
    ActivityIntent intent,
    FirebaseService firebaseService, {
    Color accent = const Color(0xFF1DE9B6),
  }) {
    final bool isMyActivity = intent.userId == currentUser.userId;
    final heroTag = 'avatar_${intent.intentId}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () =>
                    _showFullScreenImage(context, intent.userAvatar, heroTag),
                child: Hero(
                  tag: heroTag,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage: intent.userAvatar.startsWith('http')
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${intent.userName} • ${intent.skillLevel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isMyActivity)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            _showDeleteConfirmDialog(
                              context,
                              firebaseService,
                              intent.intentId,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _getIconForActivity(intent.activity),
                          color: accent.withOpacity(0.5),
                          size: 16,
                        ),
                      ],
                    )
                  else
                    Icon(
                      _getIconForActivity(intent.activity),
                      color: accent.withOpacity(0.5),
                      size: 16,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${intent.playersNeeded} SLOTS',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final bool isJoined =
                  intent.currentParticipants.contains(currentUser.userId) ||
                  isMyActivity;
              if (!isJoined) {
                await firebaseService.joinIntent(
                  intent.intentId,
                  currentUser.userId,
                );
              }
              // Jump to Chat tab (index 2)
              context.findAncestorStateOfType<MainNavigationState>()?.jumpToTab(
                2,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              width: double.infinity,
              decoration: BoxDecoration(
                color:
                    (intent.currentParticipants.contains(currentUser.userId) ||
                        isMyActivity)
                    ? Colors.black
                    : accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  (intent.currentParticipants.contains(currentUser.userId) ||
                          isMyActivity)
                      ? 'OPEN CHAT'
                      : 'JOIN & CHAT',
                  style: TextStyle(
                    color:
                        (intent.currentParticipants.contains(
                              currentUser.userId,
                            ) ||
                            isMyActivity)
                        ? Colors.white
                        : accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
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
        backgroundColor: const Color(0xFFFFFFFF),
        title: const Text(
          'Delete Activity?',
          style: TextStyle(color: Colors.black),
        ),
        content: const Text(
          'This will end your radar broadcast and remove it from the feed.',
          style: TextStyle(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black26),
            ),
          ),
          TextButton(
            onPressed: () {
              service.expireIntent(id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Activity ended'),
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
}
