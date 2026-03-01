import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';

import '../models/models.dart';
import '../providers/mock_data.dart';
import '../widgets/radar_marker.dart';
import '../widgets/activity_card.dart';
import '../widgets/create_intent_sheet.dart';
import '../services/firebase_service.dart';
import '../widgets/remote_user_marker.dart';
import 'main_navigation.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  List<ActivityIntent> intents = [];
  String? selectedIntentId;
  bool showCreate = false;
  final MapController _mapController = MapController();
  final Uuid uuid = const Uuid();
  LocationPoint? _userPos;
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription? _intentsSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _usersSubscription;
  bool _isUsingFallback = true;
  bool _isSearchingLocation = false;
  Map<String, Map<String, dynamic>> _otherUsers = {};
  final Set<String> _processedIntentIds = {};
  final DateTime _sessionStartTime = DateTime.now();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _heartbeatTimer;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _determinePosition();
    _listenToIntents();
    _listenToOtherUsers();

    // Heartbeat timer: Update 'lastActive' every 30 seconds even if stationary
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_userPos != null) {
        _firebaseService.updateUserLocation(
          userId: currentUser.userId,
          name: currentUser.name,
          avatar: currentUser.avatar,
          lat: _userPos!.lat,
          lng: _userPos!.lng,
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      // The moment user closes or hides the app, stop showing them nearby
      _firebaseService.clearMyLocation(currentUser.userId);
    } else if (state == AppLifecycleState.resumed) {
      // Re-upload when user comes back
      if (_userPos != null) {
        _firebaseService.updateUserLocation(
          userId: currentUser.userId,
          name: currentUser.name,
          avatar: currentUser.avatar,
          lat: _userPos!.lat,
          lng: _userPos!.lng,
        );
      }
    }
  }

  void _listenToOtherUsers() {
    _usersSubscription = _firebaseService
        .getOtherUsersStream(currentUser.userId)
        .listen((users) {
          if (mounted) {
            setState(() {
              _otherUsers = users;
            });
          }
        });
  }

  void _listenToIntents() {
    _intentsSubscription = _firebaseService.getintentsStream().listen((
      newIntents,
    ) {
      if (mounted) {
        // Detect NEW nearby intents for notifications
        for (var intent in newIntents) {
          if (intent.userId != currentUser.userId &&
              !_processedIntentIds.contains(intent.intentId) &&
              intent.createdAt.isAfter(_sessionStartTime)) {
            // Check proximity
            if (_userPos != null) {
              double dist = Geolocator.distanceBetween(
                _userPos!.lat,
                _userPos!.lng,
                intent.location.lat,
                intent.location.lng,
              );

              if (dist <= 5000) {
                _processedIntentIds.add(intent.intentId);
                _showNewIntentNotification(intent);
              }
            }
          }
        }

        setState(() {
          intents = newIntents;
        });
      }
    });
  }

  void _showNewIntentNotification(ActivityIntent intent) async {
    // Play a friendly "ping" sound
    try {
      await _audioPlayer.play(
        UrlSource(
          'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
        ),
      );
    } catch (e) {
      debugPrint("Sound error: $e");
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 30, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Accent
              Container(
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF1DE9B6),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1DE9B6).withOpacity(0.1),
                          ),
                        ),
                        CircleAvatar(
                          radius: 34,
                          backgroundImage: NetworkImage(intent.userAvatar),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${intent.userName} is nearby!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                        children: [
                          const TextSpan(text: 'Starting '),
                          TextSpan(
                            text: intent.activity.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                          const TextSpan(text: ' activity.'),
                        ],
                      ),
                    ),
                    if (intent.description != null &&
                        intent.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '"${intent.description}"',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.black38,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'DECLINE',
                              style: TextStyle(
                                color: Colors.black26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() {
                                selectedIntentId = intent.intentId;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF121212),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'VIEW RADAR',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _firebaseService.clearMyLocation(currentUser.userId);
    _intentsSubscription?.cancel();
    _positionSubscription?.cancel();
    _usersSubscription?.cancel();
    _audioPlayer.dispose();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    if (_isSearchingLocation) return;

    setState(() {
      _isSearchingLocation = true;
    });

    try {
      debugPrint("Location: Checking if services are enabled...");
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location: Services are disabled.");
        if (mounted) {
          setState(() {
            _userPos = mockLocation;
            _isUsingFallback = true;
            _isSearchingLocation = false;
          });
        }
        return;
      }

      debugPrint("Location: Checking permissions...");
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("Location: Permissions denied, requesting...");
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("Location: Permissions still denied.");
          if (mounted) {
            setState(() {
              _userPos = mockLocation;
              _isUsingFallback = true;
              _isSearchingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("Location: Permissions denied forever.");
        if (mounted) {
          setState(() {
            _userPos = mockLocation;
            _isUsingFallback = true;
            _isSearchingLocation = false;
          });
        }
        return;
      }

      debugPrint("Location: Attempting to get current position...");
      // Initial quick attempt with longer timeout
      final initialPosition =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 10),
          ).catchError((e) async {
            debugPrint(
              "Location: Current position failed: $e. Checking last known...",
            );
            final lastKnown = await Geolocator.getLastKnownPosition();
            if (lastKnown != null) return lastKnown;
            return Position(
              latitude: mockLocation.lat,
              longitude: mockLocation.lng,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            );
          });

      if (mounted) {
        debugPrint(
          "Location: Initial position set to: ${initialPosition.latitude}, ${initialPosition.longitude}",
        );
        setState(() {
          _userPos = LocationPoint(
            lat: initialPosition.latitude,
            lng: initialPosition.longitude,
          );
          _isUsingFallback =
              initialPosition.latitude == mockLocation.lat &&
              initialPosition.longitude == mockLocation.lng;
          _isSearchingLocation = false;
        });

        // Safety check for MapController
        if (_isMapReady) {
          _mapController.move(
            LatLng(initialPosition.latitude, initialPosition.longitude),
            17.5,
          );
        }
      }

      debugPrint("Location: Starting high-accuracy stream...");
      // Start high-accuracy real-time tracking
      _positionSubscription?.cancel();
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 2,
            ),
          ).listen((Position position) {
            debugPrint(
              "Location Stream: Got update: ${position.latitude}, ${position.longitude}",
            );
            if (mounted) {
              setState(() {
                _userPos = LocationPoint(
                  lat: position.latitude,
                  lng: position.longitude,
                );
                _isUsingFallback = false;
                _isSearchingLocation = false;
              });

              // Update location in Firebase
              _firebaseService.updateUserLocation(
                userId: currentUser.userId,
                name: currentUser.name,
                avatar: currentUser.avatar,
                lat: position.latitude,
                lng: position.longitude,
              );
            }
          });
    } catch (e) {
      debugPrint("Location error: $e");
      if (mounted) {
        setState(() {
          _userPos = mockLocation;
          _isUsingFallback = true;
          _isSearchingLocation = false;
        });
      }
    }
  }

  void _recenter() {
    if (_userPos != null) {
      _mapController.move(LatLng(_userPos!.lat, _userPos!.lng), 17.0);
    }
  }

  void _handleJoin(String intentId) async {
    await _firebaseService.joinIntent(intentId, currentUser.userId);

    setState(() {
      selectedIntentId = null;
    });

    // Jump to Chat tab (index 2)
    context.findAncestorStateOfType<MainNavigationState>()?.jumpToTab(2);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Successfully joined! Opening chat...'),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleCreate(
    String activity,
    String description,
    String skillLevel,
    int playersNeeded,
    int radiusM,
  ) {
    // Generate a new temporary id
    final id = 'int_${uuid.v4()}';

    // Add a randomized offset to simulate different exact locations
    // but close directly to the user
    final offsetLat = _userPos!.lat + (Random().nextDouble() - 0.5) * 0.005;
    final offsetLng = _userPos!.lng + (Random().nextDouble() - 0.5) * 0.005;

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
      skillLevel: skillLevel,
      currentParticipants: [
        currentUser.userId,
      ], // Automatically join your own session
    );

    // Check for existing active intent from this user
    final existingIntent = intents.cast<ActivityIntent?>().firstWhere(
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
      if (oldIntentId != null) {
        intents.removeWhere((i) => i.intentId == oldIntentId);
      }
      intents.add(newIntent);
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
    final activeIntents = intents.where((i) => i.status == 'active').toList();
    final bool hasActiveIntent = activeIntents.any(
      (i) => i.userId == currentUser.userId,
    );
    final ActivityIntent? selectedIntent = activeIntents
        .cast<ActivityIntent?>()
        .firstWhere((i) => i?.intentId == selectedIntentId, orElse: () => null);

    // Calculate nearby devices count within 5km (120-SECOND WINDOW for stability)
    int nearbyCount = 0;
    final now = DateTime.now();
    final threshold = now.subtract(const Duration(seconds: 120));

    _otherUsers.forEach((id, user) {
      if (_userPos != null && id != currentUser.userId) {
        final lastActive = user['lastActive'] as Timestamp?;
        if (lastActive != null && lastActive.toDate().isAfter(threshold)) {
          double distance = Geolocator.distanceBetween(
            _userPos!.lat,
            _userPos!.lng,
            user['lat'],
            user['lng'],
          );

          if (distance <= 5000) {
            nearbyCount++;
          }
        }
      }
    });

    final List<Marker> markers = [];

    // Add User marker (Me)
    if (_userPos != null) {
      markers.add(
        Marker(
          width: 80,
          height: 80,
          point: LatLng(_userPos!.lat, _userPos!.lng),
          child: UserLocationMarker(
            avatarUrl: currentUser.avatar,
            hasBroadcast: hasActiveIntent,
          ),
        ),
      );
    }

    // Add Other Users as DP Markers with potential Broadcast Blimps
    _otherUsers.forEach((id, user) {
      if (_userPos == null || id == currentUser.userId) return;

      // Use the same 120s threshold for consistency
      final lastActive = user['lastActive'] as Timestamp?;
      if (lastActive == null || !lastActive.toDate().isAfter(threshold)) return;

      double distance = Geolocator.distanceBetween(
        _userPos!.lat,
        _userPos!.lng,
        user['lat'],
        user['lng'],
      );

      if (distance > 5000) return; // Hide far away devices

      // Check if this user has an active broadcast
      final ActivityIntent? intent = activeIntents
          .cast<ActivityIntent?>()
          .firstWhere((i) => i?.userId == id, orElse: () => null);

      markers.add(
        Marker(
          width: 60,
          height: 60,
          point: LatLng(user['lat'], user['lng']),
          child: RemoteUserMarker(
            avatarUrl: user['avatar'],
            hasBroadcast: intent != null,
            onTap: () {
              if (intent != null) {
                // Select the intent for detail sheet
                setState(() {
                  selectedIntentId = intent.intentId;
                  showCreate = false;
                });

                // Jump to Live Broadcasts Page
                context
                    .findAncestorStateOfType<MainNavigationState>()
                    ?.jumpToTab(1);
              }
            },
          ),
        ),
      );
    });

    return Scaffold(
      body: _userPos == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                // Map Background
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(_userPos!.lat, _userPos!.lng),
                    initialZoom: 16.0,
                    onTap: (tapPosition, point) {
                      // Clicking map clears selections
                      if (selectedIntentId != null || showCreate) {
                        setState(() {
                          selectedIntentId = null;
                          showCreate = false;
                        });
                      }
                    },
                    onMapReady: () {
                      _isMapReady = true;
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.zingoo.app',
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(_userPos!.lat, _userPos!.lng),
                          radius: 100,
                          useRadiusInMeter: true,
                          color: Colors.transparent,
                          borderColor: Colors.black.withOpacity(0.2),
                          borderStrokeWidth: 1,
                        ),
                        CircleMarker(
                          point: LatLng(_userPos!.lat, _userPos!.lng),
                          radius: 300,
                          useRadiusInMeter: true,
                          color: Colors.transparent,
                          borderColor: Colors.black.withOpacity(0.1),
                          borderStrokeWidth: 1,
                        ),
                        CircleMarker(
                          point: LatLng(_userPos!.lat, _userPos!.lng),
                          radius: 500,
                          useRadiusInMeter: true,
                          color: Colors.transparent,
                          borderColor: Colors.black.withOpacity(0.05),
                          borderStrokeWidth: 1,
                        ),
                      ],
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),

                // Top Header (Light/White Theme)
                Positioned(
                  top: 50,
                  left: 20,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.black12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 32,
                                height: 32,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.map,
                                      color: Color(0xFF1DE9B6),
                                      size: 28,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Zingoo',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        // Nearby Count Indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1DE9B6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$nearbyCount nearby',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          backgroundImage: NetworkImage(currentUser.avatar),
                          radius: 18,
                          backgroundColor: Colors.black12,
                        ),
                      ],
                    ),
                  ),
                ),

                // Location Status Banner
                Positioned(
                  top: 110,
                  left: 20,
                  right: 20,
                  child: Visibility(
                    visible: _isUsingFallback,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isSearchingLocation
                            ? Colors.blue.withOpacity(0.9)
                            : Colors.orange.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isSearchingLocation
                                ? Icons.satellite_alt
                                : Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isSearchingLocation
                                  ? 'Acquiring high-accuracy GPS signal...'
                                  : 'Using Sharda University as fallback. Enable GPS for exact map.',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!_isSearchingLocation)
                            GestureDetector(
                              onTap: _determinePosition,
                              child: const Text(
                                'RETRY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Recenter Button
                if (selectedIntentId == null && !showCreate)
                  Positioned(
                    bottom: 110,
                    right: 20,
                    child: FloatingActionButton.small(
                      heroTag: 'recenter_btn',
                      onPressed: _recenter,
                      backgroundColor: Colors.white,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),

                // Action Floating Button
                if (selectedIntentId == null && !showCreate)
                  Positioned(
                    bottom: 40,
                    right: 20,
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      tween: Tween(begin: 0, end: 1),
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: FloatingActionButton(
                        heroTag: 'add_btn',
                        onPressed: hasActiveIntent
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'You are already broadcasting! End your current activity to start a new one.',
                                    ),
                                    backgroundColor: Colors.white10,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            : () {
                                setState(() {
                                  showCreate = true;
                                });
                              },
                        backgroundColor: hasActiveIntent
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFFFFFFF),
                        child: Icon(
                          hasActiveIntent ? Icons.check : Icons.add,
                          size: 32,
                          color: hasActiveIntent
                              ? Colors.white30
                              : const Color(0xFF121212),
                        ),
                      ),
                    ),
                  ),

                // Details Bottom Sheet overlay
                if (selectedIntent != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ActivityCard(
                      intent: selectedIntent,
                      onClose: () {
                        setState(() => selectedIntentId = null);
                      },
                      onJoin: _handleJoin,
                      onDelete: () {
                        _firebaseService.expireIntent(selectedIntent.intentId);
                        setState(() {
                          intents.removeWhere(
                            (i) => i.intentId == selectedIntent.intentId,
                          );
                          selectedIntentId = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Activity broadcast ended'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),

                // Create Intent overlay
                if (showCreate)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: CreateIntentSheet(
                      onClose: () {
                        setState(() => showCreate = false);
                      },
                      onCreate: _handleCreate,
                    ),
                  ),
              ],
            ),
    );
  }
}
