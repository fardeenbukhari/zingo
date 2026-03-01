import 'package:flutter/material.dart';

import 'map_screen.dart';
import 'profile_screen.dart';
import 'live_events_screen.dart';
import 'chat_list_screen.dart';
import '../models/models.dart';

import '../services/firebase_service.dart';
import '../providers/mock_data.dart';
import '../services/notification_service.dart';
import 'dart:async';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  MainNavigationState createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final FirebaseService _firebaseService = FirebaseService();
  final Map<String, StreamSubscription> _messageSubscriptions = {};

  @override
  void initState() {
    super.initState();
    _listenToAllChats();
  }

  @override
  void dispose() {
    for (var sub in _messageSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }

  void _listenToAllChats() {
    // Listen to all intents to find which ones the user is part of
    _firebaseService.getintentsStream().listen((intents) {
      final myChats = intents.where((intent) {
        return intent.userId == currentUser.userId ||
            intent.currentParticipants.contains(currentUser.userId);
      }).toList();

      for (var chat in myChats) {
        if (!_messageSubscriptions.containsKey(chat.intentId)) {
          // Track message count to only notify on NEW messages
          int lastCount = -1;

          _messageSubscriptions[chat.intentId] = _firebaseService
              .getChatStream(chat.intentId)
              .listen((messages) {
                if (lastCount != -1 && messages.length > lastCount) {
                  final newMessage = messages.first;
                  // Only notify if NOT sent by me
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

  final List<Widget> _screens = [
    const MapScreen(),
    const LiveEventsScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
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
