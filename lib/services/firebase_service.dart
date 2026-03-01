import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of all active intents
  Stream<List<ActivityIntent>> getintentsStream() {
    return _db
        .collection('intents')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ActivityIntent.fromJson({
                  ...doc.data(),
                  'intentId': doc.id,
                }),
              )
              .toList(),
        );
  }

  // Create a new intent
  Future<void> createIntent(ActivityIntent intent) async {
    await _db.collection('intents').doc(intent.intentId).set(intent.toJson());
  }

  // Delete/Expire an intent
  Future<void> expireIntent(String intentId) async {
    await _db.collection('intents').doc(intentId).update({'status': 'expired'});
  }

  // Debug: Wipe all active intents
  Future<void> clearAllIntents() async {
    final snapshot = await _db
        .collection('intents')
        .where('status', isEqualTo: 'active')
        .get();
    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'status': 'expired'});
    }
    await batch.commit();
  }

  // Debug: Wipe all location trails
  Future<void> clearAllLocations() async {
    final snapshot = await _db.collection('locations').get();
    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Update user location for real-time tracking
  Future<void> updateUserLocation({
    required String userId,
    required String name,
    required String avatar,
    required double lat,
    required double lng,
  }) async {
    await _db.collection('locations').doc(userId).set({
      'userId': userId,
      'name': name,
      'avatar': avatar,
      'lat': lat,
      'lng': lng,
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Remove current user's location trail
  Future<void> clearMyLocation(String userId) async {
    await _db.collection('locations').doc(userId).delete();
  }

  // Stream of other users' locations
  Stream<Map<String, Map<String, dynamic>>> getOtherUsersStream(
    String currentUserId,
  ) {
    return _db.collection('locations').snapshots().map((snapshot) {
      final Map<String, Map<String, dynamic>> users = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (doc.id != currentUserId) {
          users[doc.id] = data;
        }
      }
      return users;
    });
  }

  // Join an intent
  Future<void> joinIntent(String intentId, String userId) async {
    await _db.collection('intents').doc(intentId).update({
      'currentParticipants': FieldValue.arrayUnion([userId]),
    });
  }

  // Send a chat message
  Future<void> sendChatMessage(String intentId, ChatMessage message) async {
    await _db
        .collection('intents')
        .doc(intentId)
        .collection('chat')
        .add(message.toJson());
  }

  // Stream messages for an intent
  Stream<List<ChatMessage>> getChatStream(String intentId) {
    return _db
        .collection('intents')
        .doc(intentId)
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  // Mark message as seen
  Future<void> markMessageAsSeen(
    String intentId,
    String messageId,
    String userId,
  ) async {
    await _db
        .collection('intents')
        .doc(intentId)
        .collection('chat')
        .doc(messageId)
        .update({
          'seenBy': FieldValue.arrayUnion([userId]),
        });
  }

  // Mark all messages as delivered for a user
  Future<void> markAllAsDelivered(String intentId, String userId) async {
    final batch = _db.batch();
    final messages = await _db
        .collection('intents')
        .doc(intentId)
        .collection('chat')
        .where('senderId', isNotEqualTo: userId)
        .get();

    for (var doc in messages.docs) {
      final deliveredTo = List<String>.from(doc.data()['deliveredTo'] ?? []);
      if (!deliveredTo.contains(userId)) {
        batch.update(doc.reference, {
          'deliveredTo': FieldValue.arrayUnion([userId]),
        });
      }
    }
    await batch.commit();
  }

  // Get unread count for a user in an intent
  Stream<int> getUnreadCount(String intentId, String userId) {
    return _db
        .collection('intents')
        .doc(intentId)
        .collection('chat')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.where((doc) {
            final data = doc.data();
            if (data['senderId'] == userId) return false;
            final seenBy = List<String>.from(data['seenBy'] ?? []);
            return !seenBy.contains(userId);
          }).length;
        });
  }
}
