import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../providers/mock_data.dart';
import '../widgets/radar_marker.dart';
import '../widgets/activity_card.dart';
import '../widgets/create_intent_sheet.dart';
import '../services/firebase_service.dart';
import '../widgets/remote_user_marker.dart';
import 'chat_room_screen.dart';

class MapScreen extends StatefulWidget {
  final LocationPoint? userPos;
  final Map<String, Map<String, dynamic>> otherUsers;
  final List<ActivityIntent> intents;
  final bool isUsingFallback;
  final bool isSearchingLocation;
  final VoidCallback onRetryLocation;
  final Function(int)? onTabChanged;
  final String? initialActivity;
  final VoidCallback? onActivityProcessed;

  const MapScreen({
    Key? key,
    required this.userPos,
    required this.otherUsers,
    required this.intents,
    required this.isUsingFallback,
    required this.isSearchingLocation,
    required this.onRetryLocation,
    this.onTabChanged,
    this.initialActivity,
    this.onActivityProcessed,
  }) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final FirebaseService _firebaseService = FirebaseService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Uuid uuid = const Uuid();
  final MapController _mapController = MapController();

  String? selectedIntentId;
  bool showCreate = false;

  late AnimationController _scanController;
  double _currentScanRadius = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scanController =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..addListener(() {
            setState(() {
              _currentScanRadius =
                  _scanController.value * 2000; // Scans up to 2km
            });
          })
          ..repeat();

    if (widget.initialActivity != null) {
      showCreate = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.onActivityProcessed != null) widget.onActivityProcessed!();
      });
    }
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialActivity != null &&
        widget.initialActivity != oldWidget.initialActivity) {
      setState(() {
        showCreate = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.onActivityProcessed != null) widget.onActivityProcessed!();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _firebaseService.clearMyLocation(currentUser.userId);
    } else if (state == AppLifecycleState.resumed) {
      if (widget.userPos != null) {
        _firebaseService.updateUserLocation(
          userId: currentUser.userId,
          name: currentUser.name,
          avatar: currentUser.avatar,
          lat: widget.userPos!.lat,
          lng: widget.userPos!.lng,
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _firebaseService.clearMyLocation(currentUser.userId);
    _scanController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _recenter() {
    if (widget.userPos != null) {
      _mapController.move(
        LatLng(widget.userPos!.lat, widget.userPos!.lng),
        17.0,
      );
    }
  }

  void _handleJoin(ActivityIntent intent) async {
    await _firebaseService.joinIntent(
      intent.intentId,
      currentUser.userId,
      intent.userId,
    );
    setState(() => selectedIntentId = null);
    if (widget.onTabChanged != null) {
      widget.onTabChanged!(2);
    }
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatRoomScreen(intent: intent)),
      );
    }
  }

  void _handleCreate(
    String activity,
    String description,
    int playersNeeded,
    int radiusM,
  ) {
    final id = 'int_${uuid.v4()}';
    final offsetLat =
        widget.userPos!.lat + (Random().nextDouble() - 0.5) * 0.005;
    final offsetLng =
        widget.userPos!.lng + (Random().nextDouble() - 0.5) * 0.005;

    final newIntent = ActivityIntent(
      intentId: id,
      userId: currentUser.userId,
      userName: currentUser.name,
      userAvatar: currentUser.avatar,
      activity: activity,
      mode: 'spontaneous',
      playersNeeded: playersNeeded,
      location: LocationPoint(lat: offsetLat, lng: offsetLng),
      radiusM: radiusM,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      status: 'active',
      description: description.isNotEmpty ? description : null,
      tags: [],
      currentParticipants: [currentUser.userId],
    );

    final existingIntent = widget.intents.cast<ActivityIntent?>().firstWhere(
      (i) => i?.status == 'active' && i?.userId == currentUser.userId,
      orElse: () => null,
    );

    if (existingIntent != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF181818),
          title: const Text(
            'Limit Reached',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'You are already broadcasting "${existingIntent.activity}". To create a new one, your previous activity will be ended. Continue?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white38),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _performCreate(newIntent, existingIntent.intentId);
              },
              child: const Text(
                'Replace',
                style: TextStyle(color: Color(0xFF1DE9B6)),
              ),
            ),
          ],
        ),
      );
    } else {
      _performCreate(newIntent);
    }
  }

  void _performCreate(ActivityIntent newIntent, [String? oldIntentId]) {
    setState(() {
      // Logic for adding locally before FireStore updates if needed
      showCreate = false;
    });

    if (oldIntentId != null) {
      _firebaseService.expireIntent(oldIntentId);
    }
    _firebaseService.createIntent(newIntent);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          oldIntentId != null
              ? 'Previous activity replaced!'
              : 'Activity broadcasted!',
        ),
        backgroundColor: Colors.white10,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userPos == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final activeIntents = widget.intents
        .where((i) => i.status == 'active')
        .toList();
    final bool hasActiveIntent = activeIntents.any(
      (i) => i.userId == currentUser.userId,
    );
    final ActivityIntent? selectedIntent = activeIntents
        .cast<ActivityIntent?>()
        .firstWhere((i) => i?.intentId == selectedIntentId, orElse: () => null);

    int nearbyCount = 0;
    final now = DateTime.now();
    final threshold = now.subtract(const Duration(seconds: 120));

    widget.otherUsers.forEach((id, user) {
      if (id != currentUser.userId) {
        final lastActive = user['lastActive'] as Timestamp?;
        if (lastActive != null && lastActive.toDate().isAfter(threshold)) {
          double dist = Geolocator.distanceBetween(
            widget.userPos!.lat,
            widget.userPos!.lng,
            user['lat'],
            user['lng'],
          );
          if (dist <= 2000) nearbyCount++;
        }
      }
    });

    final List<Marker> markers = [];
    markers.add(
      Marker(
        width: 80,
        height: 80,
        point: LatLng(widget.userPos!.lat, widget.userPos!.lng),
        child: UserLocationMarker(
          avatarUrl: currentUser.avatar,
          hasBroadcast: hasActiveIntent,
          onTap: hasActiveIntent
              ? () {
                  final myIntent = activeIntents.firstWhere(
                    (i) => i.userId == currentUser.userId,
                  );
                  setState(() {
                    selectedIntentId = myIntent.intentId;
                    showCreate = false;
                  });
                }
              : () => setState(() => showCreate = true),
        ),
      ),
    );

    widget.otherUsers.forEach((id, user) {
      if (id == currentUser.userId) return;
      final lastActive = user['lastActive'] as Timestamp?;
      if (lastActive == null || !lastActive.toDate().isAfter(threshold)) return;

      double distance = Geolocator.distanceBetween(
        widget.userPos!.lat,
        widget.userPos!.lng,
        user['lat'],
        user['lng'],
      );

      // Show all users globally on the map as per request
      // if (distance > 2000) return;

      final ActivityIntent? intent = activeIntents
          .cast<ActivityIntent?>()
          .firstWhere((i) => i?.userId == id, orElse: () => null);

      final bool isWithinRange = intent != null && distance <= 2000;

      markers.add(
        Marker(
          width: 70, // Slightly larger for highlight effects
          height: 70,
          point: LatLng(user['lat'], user['lng']),
          child: RemoteUserMarker(
            avatarUrl: user['avatar'],
            hasBroadcast: isWithinRange,
            scanRadius: _currentScanRadius,
            distance: distance,
            onTap: () {
              if (isWithinRange) {
                setState(() {
                  selectedIntentId = intent.intentId;
                  showCreate = false;
                });
                if (widget.onTabChanged != null) {
                  widget.onTabChanged!(1);
                }
              }
            },
          ),
        ),
      );
    });

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(widget.userPos!.lat, widget.userPos!.lng),
              initialZoom: 16.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onTap: (tapPosition, point) {
                if (selectedIntentId != null || showCreate) {
                  setState(() {
                    selectedIntentId = null;
                    showCreate = false;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              CircleLayer(
                circles: [
                  // Animated Scan Wave (The expanding wake)
                  CircleMarker(
                    point: LatLng(widget.userPos!.lat, widget.userPos!.lng),
                    radius: _currentScanRadius,
                    useRadiusInMeter: true,
                    color: const Color(
                      0xFF1DE9B6,
                    ).withOpacity((1 - _scanController.value) * 0.15),
                    borderColor: const Color(
                      0xFF1DE9B6,
                    ).withOpacity((1 - _scanController.value) * 0.4),
                    borderStrokeWidth: 2,
                  ),
                  // Subtle secondary pulse
                  CircleMarker(
                    point: LatLng(widget.userPos!.lat, widget.userPos!.lng),
                    radius: (_currentScanRadius * 0.7) % 2000,
                    useRadiusInMeter: true,
                    color: Colors.transparent,
                    borderColor: const Color(0xFF1DE9B6).withOpacity(
                      (1 - _scanController.value).clamp(0, 1) * 0.1,
                    ),
                    borderStrokeWidth: 1,
                  ),
                  CircleMarker(
                    point: LatLng(widget.userPos!.lat, widget.userPos!.lng),
                    radius: 500,
                    useRadiusInMeter: true,
                    color: Colors.transparent,
                    borderColor: Colors.black.withOpacity(0.05),
                    borderStrokeWidth: 0.5,
                  ),
                  CircleMarker(
                    point: LatLng(widget.userPos!.lat, widget.userPos!.lng),
                    radius: 1000,
                    useRadiusInMeter: true,
                    color: Colors.transparent,
                    borderColor: Colors.black.withOpacity(0.05),
                    borderStrokeWidth: 0.5,
                  ),
                  CircleMarker(
                    point: LatLng(widget.userPos!.lat, widget.userPos!.lng),
                    radius: 2000,
                    useRadiusInMeter: true,
                    color: Colors.transparent,
                    borderColor: Colors.black.withOpacity(0.05),
                    borderStrokeWidth: 0.5,
                  ),
                ],
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            top: 60,
            left: 24,
            right: 24,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 30,
                    spreadRadius: 0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DE9B6).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.radar,
                      color: Color(0xFF121212),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'MapPingr Radar',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Scanning nearby students...',
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (activeIntents.isNotEmpty) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1DE9B6),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '$nearbyCount NEARBY',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: selectedIntent != null || showCreate ? 300 : 40,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  heroTag: 'recenter',
                  onPressed: _recenter,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Colors.black),
                ),
              ],
            ),
          ),
          if (selectedIntent != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ActivityCard(
                intent: selectedIntent,
                userPos: widget.userPos,
                onClose: () => setState(() => selectedIntentId = null),
                onJoin: _handleJoin,
                onDelete: () {
                  _firebaseService.expireIntent(selectedIntent.intentId);
                  setState(() {
                    selectedIntentId = null;
                  });
                },
              ),
            ),
          if (showCreate)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CreateIntentSheet(
                initialActivity: widget.initialActivity,
                onClose: () => setState(() => showCreate = false),
                onCreate: _handleCreate,
              ),
            ),
        ],
      ),
    );
  }
}
