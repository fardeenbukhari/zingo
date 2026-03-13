import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../providers/mock_data.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<List<ActivityIntent>>(
        stream: _firebaseService.getintentsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.black),
            );
          }

          // Filter only intents where the current user is a participant or the host
          final myChats = snapshot.data!.where((intent) {
            return intent.userId == currentUser.userId ||
                intent.currentParticipants.contains(currentUser.userId);
          }).toList();

          if (myChats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.black.withOpacity(0.1),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No active chats yet',
                    style: TextStyle(
                      color: Colors.black45,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Join an activity to start chatting!',
                    style: TextStyle(color: Colors.black26, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: myChats.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final intent = myChats[index];
              return _ChatListTile(intent: intent);
            },
          );
        },
      ),
    );
  }
}

class _ChatListTile extends StatelessWidget {
  final ActivityIntent intent;

  const _ChatListTile({Key? key, required this.intent}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isCab = intent.activity.toLowerCase().contains('cab');
    final String destination =
        intent.description?.split('\n').first.replaceFirst('To: ', '') ??
        'Unknown';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(intent: intent),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isCab ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(intent.userAvatar),
                  backgroundColor: Colors.black.withOpacity(0.05),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isCab
                          ? const Color(0xFFFFD600)
                          : const Color(0xFF1DE9B6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCab ? const Color(0xFF1A1A1A) : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isCab ? Icons.local_taxi : Icons.circle,
                      size: isCab ? 10 : 8,
                      color: isCab ? Colors.black : Colors.white,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isCab ? 'CAB SHARING' : intent.activity.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: isCab
                              ? const Color(0xFFFFD600)
                              : const Color(0xFF1DE9B6),
                        ),
                      ),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCab
                              ? Colors.redAccent.withOpacity(0.8)
                              : Colors.black26,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    intent.userName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isCab ? Colors.white : Colors.black,
                    ),
                  ),
                  if (isCab) ...[
                    const SizedBox(height: 2),
                    Text(
                      'TO: ${destination.toUpperCase()}',
                      style: const TextStyle(
                        color: Color(0xFFFFD600),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  StreamBuilder<int>(
                    stream: FirebaseService().getUnreadCount(
                      intent.intentId,
                      currentUser.userId,
                    ),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${intent.currentParticipants.length + 1} participants in group',
                              style: TextStyle(
                                fontSize: 13,
                                color: isCab ? Colors.white38 : Colors.black45,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (count > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isCab
                                    ? const Color(0xFFFFD600)
                                    : const Color(0xFF1DE9B6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                count.toString(),
                                style: TextStyle(
                                  color: isCab ? Colors.black : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: isCab ? Colors.white24 : Colors.black12,
            ),
          ],
        ),
      ),
    );
  }
}
