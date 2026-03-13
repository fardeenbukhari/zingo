import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Save/Update User Profile
  Future<void> saveUserProfile(User user) async {
    await _db.collection('users').doc(user.userId).set({
      'name': user.name,
      'email': user.email,
      'avatar': user.avatar,
      if (user.gender != null) 'gender': user.gender,
      'interests': user.interests,
      'skillLevels': user.skillLevels,
      'pingPoints': user.pingPoints,
      'intentsCreated': user.intentsCreated,
      'intentsJoined': user.intentsJoined,
      'totalParticipantsEngaged': user.totalParticipantsEngaged,
      'isVerified': user.isVerified,
      'isAadhaarVerified': user.isAadhaarVerified,
      if (user.linkedAadhaar != null) 'linkedAadhaar': user.linkedAadhaar,
      if (user.organization != null) 'organization': user.organization,
      'joinedAt': user.joinedAt.toIso8601String(),
    }, SetOptions(merge: true));
  }

  // Check if an Aadhaar number is already linked to an account
  Future<bool> isAadhaarLinked(String aadhaarNumber) async {
    final query = await _db
        .collection('users')
        .where('linkedAadhaar', isEqualTo: aadhaarNumber)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  // Fetch User Profile
  Future<User?> getUserProfile(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    return User(
      userId: userId,
      name: data['name'] ?? 'User',
      email: data['email'] ?? '',
      avatar: data['avatar'] ?? 'https://i.pravatar.cc/150?u=$userId',
      gender: data['gender'],
      interests: List<String>.from(data['interests'] ?? []),
      skillLevels: Map<String, String>.from(data['skillLevels'] ?? {}),
      pingPoints: data['pingPoints'] ?? data['zingPoints'] ?? 0,
      intentsCreated: data['intentsCreated'] ?? 0,
      intentsJoined: data['intentsJoined'] ?? 0,
      totalParticipantsEngaged: data['totalParticipantsEngaged'] ?? 0,
      isVerified: data['isVerified'] ?? false,
      isAadhaarVerified: data['isAadhaarVerified'] ?? false,
      linkedAadhaar: data['linkedAadhaar'],
      organization: data['organization'],
      joinedAt: data['joinedAt'] != null
          ? DateTime.parse(data['joinedAt'])
          : DateTime.now(),
    );
  }

  // Stream User Profile
  Stream<User?> getUserProfileStream(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      return User(
        userId: userId,
        name: data['name'] ?? 'User',
        email: data['email'] ?? '',
        avatar: data['avatar'] ?? 'https://i.pravatar.cc/150?u=$userId',
        gender: data['gender'],
        interests: List<String>.from(data['interests'] ?? []),
        skillLevels: Map<String, String>.from(data['skillLevels'] ?? {}),
        pingPoints: data['pingPoints'] ?? data['zingPoints'] ?? 0,
        intentsCreated: data['intentsCreated'] ?? 0,
        intentsJoined: data['intentsJoined'] ?? 0,
        totalParticipantsEngaged: data['totalParticipantsEngaged'] ?? 0,
        isVerified: data['isVerified'] ?? false,
        isAadhaarVerified: data['isAadhaarVerified'] ?? false,
        linkedAadhaar: data['linkedAadhaar'],
        organization: data['organization'],
        joinedAt: data['joinedAt'] != null
            ? DateTime.parse(data['joinedAt'])
            : DateTime.now(),
      );
    });
  }

  // Fetch all organizations
  Future<List<Organization>> getOrganizations() async {
    final snapshot = await _db.collection('organizations').get();
    return snapshot.docs
        .map((doc) => Organization.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

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
    final batch = _db.batch();

    // 1. Create the intent
    batch.set(_db.collection('intents').doc(intent.intentId), intent.toJson());

    // 2. Increment user's created counter (Ping Score)
    batch.update(_db.collection('users').doc(intent.userId), {
      'intentsCreated': FieldValue.increment(1),
    });

    await batch.commit();
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
  Future<void> joinIntent(
    String intentId,
    String userId,
    String creatorId,
  ) async {
    final batch = _db.batch();

    // 1. Add current user to intent participants
    batch.update(_db.collection('intents').doc(intentId), {
      'currentParticipants': FieldValue.arrayUnion([userId]),
    });

    // 2. Increment joining user's participation counter
    batch.update(_db.collection('users').doc(userId), {
      'intentsJoined': FieldValue.increment(1),
    });

    // 3. Increment creator's engagement counter
    batch.update(_db.collection('users').doc(creatorId), {
      'totalParticipantsEngaged': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // Leave an intent
  Future<void> leaveIntent(String intentId, String userId) async {
    await _db.collection('intents').doc(intentId).update({
      'currentParticipants': FieldValue.arrayRemove([userId]),
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
