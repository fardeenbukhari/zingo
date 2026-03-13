import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/ping_score_calculator.dart';

class User {
  final String userId;
  final String name;
  final String email;
  final String avatar;
  final String? gender;
  final List<String> interests;
  final int pingPoints;
  final int intentsCreated;
  final int intentsJoined;
  final int totalParticipantsEngaged;
  final bool isVerified;
  final bool isAadhaarVerified;
  final String? linkedAadhaar;
  final Map<String, String> skillLevels;

  final String? organization;
  final DateTime joinedAt;

  User({
    required this.userId,
    required this.name,
    required this.email,
    required this.avatar,
    this.gender,
    required this.interests,
    this.skillLevels = const {},
    this.pingPoints = 0,
    this.intentsCreated = 0,
    this.intentsJoined = 0,
    this.totalParticipantsEngaged = 0,
    this.isVerified = false,
    this.isAadhaarVerified = false,
    this.linkedAadhaar,
    this.organization,
    required this.joinedAt,
  });

  User copyWith({
    String? userId,
    String? name,
    String? email,
    String? avatar,
    String? gender,
    List<String>? interests,
    int? pingPoints,
    int? intentsCreated,
    int? intentsJoined,
    int? totalParticipantsEngaged,
    bool? isVerified,
    bool? isAadhaarVerified,
    String? linkedAadhaar,
    String? organization,
    DateTime? joinedAt,
    Map<String, String>? skillLevels,
  }) {
    return User(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      pingPoints: pingPoints ?? this.pingPoints,
      intentsCreated: intentsCreated ?? this.intentsCreated,
      intentsJoined: intentsJoined ?? this.intentsJoined,
      totalParticipantsEngaged:
          totalParticipantsEngaged ?? this.totalParticipantsEngaged,
      isVerified: isVerified ?? this.isVerified,
      isAadhaarVerified: isAadhaarVerified ?? this.isAadhaarVerified,
      linkedAadhaar: linkedAadhaar ?? this.linkedAadhaar,
      organization: organization ?? this.organization,
      skillLevels: skillLevels ?? this.skillLevels,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  int get totalPingPoints {
    return PingScoreCalculator.calculateScore(
      joinedAt: joinedAt,
      intentsCreated: intentsCreated,
      totalParticipantsEngaged: totalParticipantsEngaged,
      intentsJoined: intentsJoined,
    );
  }

  String get rank => PingScoreCalculator.getRank(totalPingPoints);
}

class Organization {
  final String id;
  final String name;
  final String domain;
  final LocationPoint? location;

  Organization({
    required this.id,
    required this.name,
    required this.domain,
    this.location,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'],
      name: json['name'],
      domain: json['domain'],
      location: json['location'] != null
          ? LocationPoint.fromJson(json['location'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'domain': domain,
    'location': location?.toJson(),
  };
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
    'currentParticipants': currentParticipants,
  };

  Color get color {
    switch (activity.toLowerCase()) {
      case 'badminton':
        return const Color(0xFF1DE9B6); // Brand Green
      case 'hostel':
        return const Color(0xFF7C4DFF); // Deep Purple
      case 'coffee':
        return const Color(0xFFFF9100); // Amber/Orange
      case 'study':
        return const Color(0xFF2979FF); // Blue
      default:
        return const Color(0xFF00B0FF); // Light Blue
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
