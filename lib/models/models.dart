import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String userId;
  final String name;
  final String avatar;
  final List<String> interests;
  final Map<String, String> skillLevels;

  User({
    required this.userId,
    required this.name,
    required this.avatar,
    required this.interests,
    required this.skillLevels,
  });
}

class LocationPoint {
  final double lat;
  final double lng;
  LocationPoint({required this.lat, required this.lng});

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class ActivityIntent {
  final String intentId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String activity;
  final String mode;
  final int playersNeeded;
  final LocationPoint location;
  final int radiusM;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String status;
  final String? description;
  final List<String> tags;
  final String skillLevel;
  final List<String> currentParticipants;

  ActivityIntent({
    required this.intentId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.activity,
    required this.mode,
    required this.playersNeeded,
    required this.location,
    required this.radiusM,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.description,
    this.tags = const [],
    this.skillLevel = 'Any',
    this.currentParticipants = const [],
  });

  factory ActivityIntent.fromJson(Map<String, dynamic> json) {
    return ActivityIntent(
      intentId: json['intentId'],
      userId: json['userId'],
      userName: json['userName'],
      userAvatar: json['userAvatar'],
      activity: json['activity'],
      mode: json['mode'] ?? 'spontaneous',
      playersNeeded: json['playersNeeded'],
      location: LocationPoint.fromJson(json['location']),
      radiusM: json['radiusM'],
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
      status: json['status'],
      description: json['description'],
      tags: List<String>.from(json['tags'] ?? []),
      skillLevel: json['skillLevel'] ?? 'Any',
      currentParticipants: List<String>.from(json['currentParticipants'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'intentId': intentId,
    'userId': userId,
    'userName': userName,
    'userAvatar': userAvatar,
    'activity': activity,
    'mode': mode,
    'playersNeeded': playersNeeded,
    'location': location.toJson(),
    'radiusM': radiusM,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'status': status,
    'description': description,
    'tags': tags,
    'skillLevel': skillLevel,
    'currentParticipants': currentParticipants,
  };

  Color get color {
    switch (activity.toLowerCase()) {
      case 'badminton':
        return const Color(0xFFFFFFFF); // Pure White
      case 'hostel':
        return const Color(0xFF1DE9B6); // Teal
      case 'coffee':
        return const Color(0xFFE0E0E0); // Light Gray
      case 'study':
        return const Color(0xFFBDBDBD); // Mid Gray
      default:
        return const Color(0xFF9E9E9E); // Darker Gray
    }
  }
}

class Session {
  final String sessionId;
  final String activity;
  final List<String> participants;
  final LocationPoint location;
  final String status;

  Session({
    required this.sessionId,
    required this.activity,
    required this.participants,
    required this.location,
    required this.status,
  });
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String text;
  final DateTime timestamp;
  final List<String> deliveredTo;
  final List<String> seenBy;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    required this.timestamp,
    this.deliveredTo = const [],
    this.seenBy = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String id) {
    return ChatMessage(
      id: id,
      senderId: json['senderId'],
      senderName: json['senderName'],
      senderAvatar: json['senderAvatar'],
      text: json['text'],
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      deliveredTo: List<String>.from(json['deliveredTo'] ?? []),
      seenBy: List<String>.from(json['seenBy'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'senderId': senderId,
    'senderName': senderName,
    'senderAvatar': senderAvatar,
    'text': text,
    'timestamp': FieldValue.serverTimestamp(),
    'deliveredTo': deliveredTo,
    'seenBy': seenBy,
  };
}
