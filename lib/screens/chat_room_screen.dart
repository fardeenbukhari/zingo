import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../providers/mock_data.dart';
import 'manage_ride_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final ActivityIntent intent;

  const ChatRoomScreen({Key? key, required this.intent}) : super(key: key);

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _markAllAsDelivered();
  }

  void _markAllAsDelivered() {
    _firebaseService.markAllAsDelivered(
      widget.intent.intentId,
      currentUser.userId,
    );
  }

  void _playSound() async {
    try {
      await _audioPlayer.play(
        UrlSource(
          'https://assets.mixkit.co/active_storage/sfx/2354/2354-preview.mp3',
        ),
      );
    } catch (e) {
      debugPrint("Sound error: $e");
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final message = ChatMessage(
      id: '',
      senderId: currentUser.userId,
      senderName: currentUser.name,
      senderAvatar: currentUser.avatar,
      text: _messageController.text.trim(),
      timestamp: DateTime.now(),
    );

    _firebaseService.sendChatMessage(widget.intent.intentId, message);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(widget.intent.userAvatar),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.intent.activity,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Hosted by ${widget.intent.userName}',
                  style: const TextStyle(color: Colors.black45, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (widget.intent.userId == currentUser.userId &&
              widget.intent.activity.toLowerCase().contains('cab'))
            IconButton(
              icon: const Icon(Icons.manage_accounts, color: Colors.black),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManageRideScreen(
                      intent: widget.intent,
                      currentUserId: currentUser.userId,
                      onEndBroadcast: () {
                        _firebaseService.expireIntent(widget.intent.intentId);
                      },
                      onLeave: () {
                        _firebaseService.leaveIntent(
                          widget.intent.intentId,
                          currentUser.userId,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _firebaseService.getChatStream(widget.intent.intentId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  );
                }

                final messages = snapshot.data!;

                // Track unread messages and play sound
                if (messages.length > _lastMessageCount) {
                  final lastMessage = messages.first;
                  if (lastMessage.senderId != currentUser.userId) {
                    _playSound();
                  }
                  _lastMessageCount = messages.length;
                }

                // Mark messages as seen
                for (var msg in messages) {
                  if (msg.senderId != currentUser.userId &&
                      !msg.seenBy.contains(currentUser.userId)) {
                    _firebaseService.markMessageAsSeen(
                      widget.intent.intentId,
                      msg.id,
                      currentUser.userId,
                    );
                  }
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final bool isMe = message.senderId == currentUser.userId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe) ...[
                                CircleAvatar(
                                  radius: 14,
                                  backgroundImage: NetworkImage(
                                    message.senderAvatar,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? Colors.black
                                        : const Color(0xFFF1F3F5),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(
                                        isMe ? 16 : 4,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMe ? 4 : 16,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Text(
                                            message.senderName,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black.withOpacity(
                                                0.3,
                                              ),
                                            ),
                                          ),
                                        ),
                                      Text(
                                        message.text,
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isMe)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, right: 4),
                              child: _buildStatusIndicator(message),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(ChatMessage message) {
    bool isSeen = message.seenBy.isNotEmpty;
    bool isDelivered = message.deliveredTo.isNotEmpty;

    if (isSeen) {
      return const Icon(Icons.done_all, size: 14, color: Color(0xFF1DE9B6));
    } else if (isDelivered) {
      return const Icon(Icons.done_all, size: 14, color: Colors.black26);
    } else {
      return const Icon(Icons.done, size: 14, color: Colors.black26);
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.black26),
                filled: true,
                fillColor: const Color(0xFFF1F3F5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
