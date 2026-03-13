import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../providers/mock_data.dart';
import 'main_navigation.dart';
import 'package:geolocator/geolocator.dart';
import 'manage_ride_screen.dart';

class LiveEventsScreen extends StatelessWidget {
  final LocationPoint? userPos;
  final List<ActivityIntent> intents;

  LiveEventsScreen({Key? key, required this.userPos, required this.intents})
    : super(key: key);

  final FirebaseService _firebaseService = FirebaseService();

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

  void _handleManageRide(BuildContext context, ActivityIntent intent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManageRideScreen(
          intent: intent,
          currentUserId: currentUser.userId,
          onEndBroadcast: () {
            _firebaseService.expireIntent(intent.intentId);
          },
          onLeave: () {
            _firebaseService.leaveIntent(intent.intentId, currentUser.userId);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ActivityIntent> myActivities = intents
        .where(
          (intent) =>
              intent.userId == currentUser.userId && intent.status == 'active',
        )
        .toList();

    final List<ActivityIntent> otherActivities = intents.where((intent) {
      if (intent.userId == currentUser.userId) return false;
      if (intent.status != 'active') return false;
      if (userPos == null) return false;
      final dist = Geolocator.distanceBetween(
        userPos!.lat,
        userPos!.lng,
        intent.location.lat,
        intent.location.lng,
      );
      // Requirement: everyone within 2km sees the broadcast in feed
      return dist <= 2000;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text(
          'LIVE FEED',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFBFBFB),
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: userPos == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.black),
                  SizedBox(height: 16),
                  Text(
                    'Searching for location...',
                    style: TextStyle(color: Colors.black38),
                  ),
                ],
              ),
            )
          : (myActivities.isEmpty && otherActivities.isEmpty)
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.radar, size: 64, color: Colors.black12),
                  SizedBox(height: 16),
                  Text(
                    'No nearby broadcasts found',
                    style: TextStyle(color: Colors.black38),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '(Showing activities within 2km)',
                    style: TextStyle(color: Colors.black26, fontSize: 12),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (myActivities.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 12),
                    child: Text(
                      'My Activities',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  ...myActivities.map(
                    (intent) => _buildEventTile(
                      context,
                      intent,
                      _firebaseService,
                      userPos,
                      accent: intent.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (otherActivities.isNotEmpty) ...[
                  if (myActivities.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 12),
                      child: Text(
                        'Community Broadcasts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ...otherActivities.map(
                    (intent) => _buildEventTile(
                      context,
                      intent,
                      _firebaseService,
                      userPos,
                      accent: intent.color,
                    ),
                  ),
                ],
              ],
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
    FirebaseService firebaseService,
    LocationPoint? userPos, {
    Color accent = const Color(0xFF1DE9B6),
  }) {
    final bool isMyActivity = intent.userId == currentUser.userId;
    final bool isCab = intent.activity.toLowerCase().contains('cab');

    if (isCab) {
      return _buildCabEventTile(context, intent, firebaseService, userPos);
    }

    bool isTooFar = false;
    if (!isMyActivity && userPos != null) {
      double dist = Geolocator.distanceBetween(
        userPos.lat,
        userPos.lng,
        intent.location.lat,
        intent.location.lng,
      );
      if (dist > intent.radiusM) {
        isTooFar = true;
      }
    }

    final heroTag = 'avatar_${intent.intentId}';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                  child: Stack(
                    children: [
                      Container(
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
                          backgroundImage:
                              intent.userAvatar.startsWith('http') || kIsWeb
                              ? NetworkImage(intent.userAvatar) as ImageProvider
                              : FileImage(File(intent.userAvatar)),
                          backgroundColor: Colors.black.withOpacity(0.05),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DE9B6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
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
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      intent.userName,
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
              final bool isFull =
                  intent.currentParticipants.length >= intent.playersNeeded &&
                  !isJoined;

              if (isFull) return;
              if (isTooFar) return;

              if (!isJoined) {
                await firebaseService.joinIntent(
                  intent.intentId,
                  currentUser.userId,
                  intent.userId,
                );
              }
              // Jump to Chat tab (index 2)
              context.findAncestorStateOfType<MainNavigationState>()?.jumpToTab(
                2,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              width: double.infinity,
              decoration: BoxDecoration(
                color:
                    (intent.currentParticipants.contains(currentUser.userId) ||
                        isMyActivity)
                    ? Colors.black
                    : (intent.currentParticipants.length >=
                          intent.playersNeeded)
                    ? Colors.black12
                    : isTooFar
                    ? Colors.orangeAccent.withOpacity(0.1)
                    : accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      (intent.currentParticipants.contains(
                                currentUser.userId,
                              ) ||
                              isMyActivity)
                          ? 'OPEN CHAT'
                          : (intent.currentParticipants.length >=
                                intent.playersNeeded)
                          ? 'GROUP FULL'
                          : isTooFar
                          ? 'TOO FAR'
                          : 'JOIN & CHAT',
                      style: TextStyle(
                        color:
                            (intent.currentParticipants.contains(
                                  currentUser.userId,
                                ) ||
                                isMyActivity)
                            ? Colors.white
                            : (intent.currentParticipants.length >=
                                  intent.playersNeeded)
                            ? Colors.black26
                            : isTooFar
                            ? Colors.orangeAccent
                            : accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  if (isMyActivity &&
                      intent.activity.toLowerCase().contains('cab'))
                    Positioned(
                      right: 12,
                      child: GestureDetector(
                        onTap: () => _handleManageRide(context, intent),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DE9B6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.taxi_alert,
                                size: 12,
                                color: Colors.black,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'MANAGE',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCabEventTile(
    BuildContext context,
    ActivityIntent intent,
    FirebaseService firebaseService,
    LocationPoint? userPos,
  ) {
    final bool isMyActivity = intent.userId == currentUser.userId;
    final bool isJoined = intent.currentParticipants.contains(
      currentUser.userId,
    );
    final String destination =
        intent.description?.split('\n').first.replaceFirst('To: ', '') ??
        'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD600).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(intent.userAvatar),
                  backgroundColor: Colors.white10,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFD600),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_taxi,
                    size: 10,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CAB NEARBY',
                  style: TextStyle(
                    color: Color(0xFFFFD600),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  intent.activity.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'TO: ${destination.toUpperCase()}',
                  style: const TextStyle(
                    color: Color(0xFFFFD600),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              if (isMyActivity)
                GestureDetector(
                  onTap: () => _handleManageRide(context, intent),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DE9B6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'MANAGE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () async {
                    if (!isJoined && !isMyActivity) {
                      await firebaseService.joinIntent(
                        intent.intentId,
                        currentUser.userId,
                        intent.userId,
                      );
                    }
                    context
                        .findAncestorStateOfType<MainNavigationState>()
                        ?.jumpToTab(2);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD600),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isJoined ? 'CHAT' : 'JOIN',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (isMyActivity)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: () => _showDeleteConfirmDialog(
                    context,
                    firebaseService,
                    intent.intentId,
                  ),
                ),
            ],
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
