import 'package:flutter/material.dart';

import 'map_screen.dart';
import 'profile_screen.dart';
import 'live_events_screen.dart';
import 'chat_list_screen.dart';
import 'broadcast_selection_screen.dart';
import 'manage_ride_screen.dart';
import '../widgets/create_intent_sheet.dart';
import '../models/models.dart';

import '../services/firebase_service.dart';
import '../providers/mock_data.dart';
import '../services/notification_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  MainNavigationState createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  final FirebaseService _firebaseService = FirebaseService();
  final Map<String, StreamSubscription> _messageSubscriptions = {};

  // Real-time location state
  LocationPoint? _userPos;
  LocationPoint? get userPos => _userPos;
  Map<String, Map<String, dynamic>> _otherUsers = {};
  bool _isUsingFallback = true;
  bool _isSearchingLocation = false;
  String? _selectedActivity;

  // Subscriptions
  StreamSubscription? _positionSubscription;
  StreamSubscription? _usersSubscription;
  StreamSubscription? _intentsSubscription;
  Timer? _heartbeatTimer;

  // Audio for notifications
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Tracking
  final Set<String> _processedIntentIds = {};
  final DateTime _sessionStartTime = DateTime.now();
  final Uuid uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToAllChats();
    _determinePosition();
    _listenToOtherUsers();
    _listenToNearbyIntents();

    // Global heartbeat to keep location fresh in Firebase
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.security, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reminder: Never share your personal contact details with others.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.black87,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          ),
        );

        // Wait a small delay to let intents stream populate
        Future.delayed(const Duration(seconds: 2), () async {
          if (!mounted) return;

          final snapshot = await _firebaseService.getintentsStream().first;
          final myActiveIntents = snapshot
              .where(
                (i) => i.userId == currentUser.userId && i.status == 'active',
              )
              .toList();

          if (myActiveIntents.isEmpty && mounted) {
            _showAutoCreateSheet();
          }
        });
      }
    });
  }

  void _showAutoCreateSheet() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateIntentSheet(
        onClose: () => Navigator.pop(context),
        onCreate: (activity, description, players, radius) {
          final id = 'int_${uuid.v4()}';
          final newIntent = ActivityIntent(
            intentId: id,
            userId: currentUser.userId,
            userName: currentUser.name,
            userAvatar: currentUser.avatar,
            activity: activity,
            mode: 'Looking for Players',
            playersNeeded: players,
            location: _userPos ?? LocationPoint(lat: 28.6139, lng: 77.2090),
            radiusM: radius,
            createdAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(hours: 2)),
            status: 'active',
            description: description.isNotEmpty ? description : null,
            tags: [activity.toLowerCase().replaceAll(' ', '')],
          );
          _firebaseService.createIntent(newIntent);
          Navigator.pop(context);
          jumpToTab(2); // Jump to broadcast tab
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var sub in _messageSubscriptions.values) {
      sub.cancel();
    }
    _positionSubscription?.cancel();
    _usersSubscription?.cancel();
    _intentsSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _firebaseService.clearMyLocation(currentUser.userId);
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App has come to the foreground, re-check location permissions
      _determinePosition();
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

  void _listenToNearbyIntents() {
    _intentsSubscription = _firebaseService.getintentsStream().listen((
      newIntents,
    ) {
      if (!mounted) return;

      for (var intent in newIntents) {
        if (intent.userId != currentUser.userId &&
            !_processedIntentIds.contains(intent.intentId) &&
            intent.createdAt.isAfter(_sessionStartTime)) {
          if (_userPos != null) {
            final dist = Geolocator.distanceBetween(
              _userPos!.lat,
              _userPos!.lng,
              intent.location.lat,
              intent.location.lng,
            );

            if (dist <= 2000) {
              _processedIntentIds.add(intent.intentId);

              // Interest Match logic:
              // 1. Check if activity name matches any interest
              bool activityMatch = currentUser.interests.any(
                (i) => i.toLowerCase() == intent.activity.toLowerCase(),
              );

              // 2. Check if any intent tags match any user interests
              bool tagMatch = intent.tags.any(
                (tag) => currentUser.interests.any(
                  (interest) => interest.toLowerCase() == tag.toLowerCase(),
                ),
              );

              bool hasInterest = activityMatch || tagMatch;

              if (hasInterest) {
                _playPingSound();
                _showNewIntentNotification(intent);
                NotificationService().showNotification(
                  id: intent.intentId.hashCode,
                  title: 'New activity nearby: ${intent.activity}',
                  body:
                      '${intent.userName} needs ${intent.playersNeeded} players.',
                );
              } else {
                debugPrint(
                  "MapPingr: Intent ${intent.activity} is nearby but not in user interests. Silencing.",
                );
              }
            }
          }
        }
      }
    });
  }

  void _playPingSound() async {
    try {
      await _audioPlayer.play(
        UrlSource(
          'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
        ),
      );
    } catch (e) {
      debugPrint("Sound error: $e");
    }
  }

  void _showNewIntentNotification(ActivityIntent intent) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.notifications_active,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'New ${intent.activity} nearby from ${intent.userName}!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => _handleJoinNotification(intent),
              child: const Text(
                'Join',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blueGrey,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      ),
    );
  }

  void _handleJoinNotification(ActivityIntent intent) {
    // Navigate to the map screen and potentially highlight the intent
    jumpToTab(0); // Assuming MapScreen is at index 0
    // In a real app, you might pass the intent ID to MapScreen to highlight it
    // Navigator.of(context).push(MaterialPageRoute(builder: (_) => MapScreen(highlightIntentId: intent.intentId)));
    debugPrint('User wants to join intent: ${intent.activity}');
  }

  Future<void> _determinePosition() async {
    if (_isSearchingLocation) return;
    setState(() => _isSearchingLocation = true);

    try {
      debugPrint('MapPingr: Starting location determination...');

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('MapPingr: Location services are disabled.');
        _useFallbackLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('MapPingr: Requesting location permission...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('MapPingr: Permission denied by user.');
          _useFallbackLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('MapPingr: Permission denied forever.');
        _useFallbackLocation();
        return;
      }

      // Fresh position - Giving it more time for the browser fix
      debugPrint('MapPingr: Attempting to get current position...');
      Position? freshPosition;
      try {
        freshPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10), // Increased from 3s to 10s
        );
      } catch (e) {
        debugPrint('MapPingr: Get current position failed or timed out: $e');
      }

      if (freshPosition != null && mounted) {
        final pos = freshPosition; // Capture for closure
        debugPrint('MapPingr: Successfully fetched fresh location.');
        setState(() {
          _userPos = LocationPoint(lat: pos.latitude, lng: pos.longitude);
          _isUsingFallback = false;
          _isSearchingLocation = false;
        });
      } else {
        // Try last known as a secondary backup
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          debugPrint('MapPingr: Using last known location.');
          setState(() {
            _userPos = LocationPoint(
              lat: lastKnown.latitude,
              lng: lastKnown.longitude,
            );
            _isUsingFallback = false;
            _isSearchingLocation = false;
          });
        } else {
          debugPrint('MapPingr: No location found, using fallback.');
          _useFallbackLocation();
        }
      }

      // Continuous stream
      _positionSubscription?.cancel();
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 2,
            ),
          ).listen((Position position) {
            if (mounted) {
              setState(() {
                _userPos = LocationPoint(
                  lat: position.latitude,
                  lng: position.longitude,
                );
                _isUsingFallback = false;
                _isSearchingLocation = false;
              });
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
      debugPrint('MapPingr: Unexpected location error: $e');
      _useFallbackLocation();
    }
  }

  void _useFallbackLocation() {
    if (mounted) {
      setState(() {
        if (_userPos == null) {
          _userPos = mockLocation;
          _isUsingFallback = true;
        }
        _isSearchingLocation = false;
      });
    }
  }

  void _listenToAllChats() {
    _firebaseService.getintentsStream().listen((intents) {
      final myChats = intents.where((intent) {
        return intent.userId == currentUser.userId ||
            intent.currentParticipants.contains(currentUser.userId);
      }).toList();

      for (var chat in myChats) {
        if (!_messageSubscriptions.containsKey(chat.intentId)) {
          int lastCount = -1;

          _messageSubscriptions[chat.intentId] = _firebaseService
              .getChatStream(chat.intentId)
              .listen((messages) {
                if (lastCount != -1 && messages.length > lastCount) {
                  final newMessage = messages.first;
                  if (newMessage.senderId != currentUser.userId) {
                    NotificationService().showNotification(
                      id: chat.intentId.hashCode,
                      title: 'New message in ${chat.activity}',
                      body: '${newMessage.senderName}: ${newMessage.text}',
                    );
                  }
                }
                lastCount = messages.length;
              });
        }
      }
    });
  }

  void jumpToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  List<Widget> _buildScreens(List<ActivityIntent> intents) {
    return [
      MapScreen(
        userPos: _userPos,
        otherUsers: _otherUsers,
        intents: intents,
        isUsingFallback: _isUsingFallback,
        isSearchingLocation: _isSearchingLocation,
        onRetryLocation: _determinePosition,
        onTabChanged: jumpToTab,
        initialActivity: _selectedActivity,
        onActivityProcessed: () {
          setState(() => _selectedActivity = null);
        },
      ),
      LiveEventsScreen(userPos: _userPos, intents: intents),
      // Broadcast Screen (Index 2): Context-aware (Selection vs Management)
      () {
        final activeIntent = intents.firstWhere(
          (i) =>
              i.status == 'active' &&
              i.currentParticipants.contains(currentUser.userId),
          orElse: () => ActivityIntent(
            intentId: '',
            userId: '',
            userName: '',
            userAvatar: '',
            activity: '',
            mode: '',
            playersNeeded: 0,
            location: LocationPoint(lat: 0, lng: 0),
            radiusM: 0,
            createdAt: DateTime.now(),
            expiresAt: DateTime.now(),
            status: '',
          ),
        );

        if (activeIntent.intentId.isNotEmpty) {
          return ManageRideScreen(
            intent: activeIntent,
            currentUserId: currentUser.userId,
            onEndBroadcast: () =>
                _firebaseService.expireIntent(activeIntent.intentId),
            onLeave: () => _firebaseService.leaveIntent(
              activeIntent.intentId,
              currentUser.userId,
            ),
            isTab: true,
          );
        }

        return BroadcastSelectionScreen(
          onCreate: (activity, description, players, radius) {
            final id = 'int_${uuid.v4()}';
            final existing = intents.firstWhere(
              (i) => i.status == 'active' && i.userId == currentUser.userId,
              orElse: () => ActivityIntent(
                intentId: '',
                userId: '',
                userName: '',
                userAvatar: '',
                activity: '',
                mode: '',
                playersNeeded: 0,
                location: LocationPoint(lat: 0, lng: 0),
                radiusM: 0,
                createdAt: DateTime.now(),
                expiresAt: DateTime.now(),
                status: '',
              ),
            );

            if (existing.intentId.isNotEmpty) {
              _firebaseService.expireIntent(existing.intentId);
            }

            final newIntent = ActivityIntent(
              intentId: id,
              userId: currentUser.userId,
              userName: currentUser.name,
              userAvatar: currentUser.avatar,
              activity: activity,
              mode: 'spontaneous',
              playersNeeded: players,
              location: _userPos ?? LocationPoint(lat: 0, lng: 0),
              radiusM: radius,
              createdAt: DateTime.now(),
              expiresAt: DateTime.now().add(const Duration(minutes: 30)),
              status: 'active',
              description: description,
              tags: [],
              currentParticipants: [currentUser.userId],
            );

            _firebaseService.createIntent(newIntent);
            // Stay on the broadcast tab (index 2) so it switches to ManageRide
          },
          onClose: () => jumpToTab(0),
        );
      }(),
      const ChatListScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<ActivityIntent>>(
        stream: _firebaseService.getintentsStream(),
        builder: (context, snapshot) {
          final intents = snapshot.data ?? [];
          return IndexedStack(
            index: _currentIndex,
            children: _buildScreens(intents),
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<List<ActivityIntent>>(
        stream: _firebaseService.getintentsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final myChats = snapshot.data!.where((intent) {
              return intent.userId == currentUser.userId ||
                  intent.currentParticipants.contains(currentUser.userId);
            }).toList();

            return _buildBottomBar(context, myChats);
          }
          return _buildBottomBar(context, []);
        },
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, List<ActivityIntent> myChats) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      backgroundColor: const Color(0xFFFFFFFF),
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black38,
      type: BottomNavigationBarType.fixed,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
        const BottomNavigationBarItem(
          icon: Icon(Icons.flash_on),
          label: 'Live',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.radar, size: 32),
          label: 'Broadcast',
        ),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.chat_bubble_outline),
              if (myChats.isNotEmpty)
                ...myChats
                    .map(
                      (intent) => StreamBuilder<int>(
                        stream: _firebaseService.getUnreadCount(
                          intent.intentId,
                          currentUser.userId,
                        ),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          if (count > 0) {
                            return Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1DE9B6),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 10,
                                  minHeight: 10,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    )
                    .toList(),
            ],
          ),
          label: 'Chat',
        ),

        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
