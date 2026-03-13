import 'package:flutter/material.dart';
import '../providers/mock_data.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'verification_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _handleSignOut(BuildContext context) async {
    try {
      debugPrint("MapPingr: Starting sign-out process...");

      // 1. Clear location from Firestore so user disappears from radar
      try {
        await FirebaseService().clearMyLocation(currentUser.userId);
      } catch (e) {
        debugPrint("Error clearing location: $e");
      }

      // 2. Sign out from Firebase Auth
      try {
        await auth.FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint("Error signing out from Firebase: $e");
      }

      // 3. Sign out from Google (if applicable)
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
        }
      } catch (e) {
        debugPrint("Error signing out from Google: $e");
      }

      // 3.5 Clear persisted session
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('session_uid');
      } catch (e) {
        debugPrint("Error clearing persisted session: $e");
      }

      // 4. Reset the global user state to Guest
      currentUser = User(
        userId: "guest_user",
        name: "Guest",
        email: "guest@sharda.ac.in",
        avatar: "",
        interests: ["Exploration", "Social", "Events"],
        pingPoints: 120,
        joinedAt: DateTime.now().subtract(const Duration(days: 30)),
      );

      debugPrint("MapPingr: Local state reset. Navigating to Login...");

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      debugPrint("MapPingr: Critical error during sign out: $e");
      // Fallback navigation in case of weird errors
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  void _showFullScreenImage(BuildContext context, String imagePath) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) => Scaffold(
          backgroundColor: Colors.black.withOpacity(0.9),
          body: Stack(
            children: [
              Center(
                child: Hero(
                  tag: 'avatar_hero',
                  child: Image.network(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image,
                      size: 100,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 50,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editInterests() {
    final List<String> availableInterests = [
      'Badminton',
      'Chess',
      'Cricket',
      'Coffee',
      'Study',
      'Basketball',
      'Football',
      'Running',
      'Gym',
      'Gaming',
      'Music',
    ];
    List<String> tempInterests = List.from(currentUser.interests);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFBFBFB),
              surfaceTintColor: Colors.transparent,
              title: const Text(
                'Edit Interests',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableInterests.map((interest) {
                    final isSelected = tempInterests.contains(interest);
                    return FilterChip(
                      label: Text('#$interest'),
                      selected: isSelected,
                      selectedColor: const Color(0xFF1DE9B6),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            tempInterests.add(interest);
                          } else {
                            tempInterests.remove(interest);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() {
                      currentUser = currentUser.copyWith(
                        interests: tempInterests,
                      );
                    });
                    await FirebaseService().saveUserProfile(currentUser);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DE9B6),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseService _firebaseService = FirebaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 24,
          left: 24,
          right: 24,
          bottom: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Meta Header
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () =>
                        _showFullScreenImage(context, currentUser.avatar),
                    child: Hero(
                      tag: 'avatar_hero',
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF1DE9B6).withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 64,
                              backgroundImage: NetworkImage(currentUser.avatar),
                              backgroundColor: Colors.black.withOpacity(0.05),
                              onBackgroundImageError: (e, s) =>
                                  debugPrint('MapPingr: Avatar error'),
                              child: currentUser.avatar.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.black12,
                                    )
                                  : null,
                            ),
                          ),
                          StreamBuilder<List<ActivityIntent>>(
                            stream: _firebaseService.getintentsStream(),
                            builder: (context, snapshot) {
                              final hasActive =
                                  snapshot.data?.any(
                                    (i) =>
                                        i.userId == currentUser.userId &&
                                        i.status == 'active',
                                  ) ??
                                  false;
                              if (!hasActive) return const SizedBox.shrink();
                              return Positioned(
                                right: 12,
                                bottom: 12,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1DE9B6),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                currentUser.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            if (currentUser.gender != null &&
                currentUser.gender!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  currentUser.gender!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      currentUser.isAadhaarVerified
                          ? Icons.verified
                          : Icons.school,
                      size: 14,
                      color: const Color(0xFF1DE9B6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentUser.isAadhaarVerified
                          ? 'Verified by Aadhaar'
                          : 'Sharda University Member',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Ping Score / Authenticity Score Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 40,
                    spreadRadius: 0,
                    offset: const Offset(0, 20),
                  ),
                  BoxShadow(
                    color: const Color(0xFF1DE9B6).withOpacity(0.05),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PING SCORE',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '${currentUser.totalPingPoints}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                              if (currentUser.isVerified) ...[
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1DE9B6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.verified,
                                    color: Colors.black,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (!currentUser.isVerified) ...[
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const VerificationScreen(),
                                ),
                              ),
                              child: Text(
                                'VERIFY IDENTITY >',
                                style: TextStyle(
                                  color: const Color(
                                    0xFF1DE9B6,
                                  ).withOpacity(0.8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: const Text(
                          'A+ AUTHENTIC',
                          style: TextStyle(
                            color: Color(0xFF1DE9B6),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Progress bar to next level
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: (currentUser.totalPingPoints % 100) / 100,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1DE9B6), Color(0xFF00BFA5)],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniStat(
                        Icons.emoji_events_outlined,
                        'ENGAGEMENT',
                        '${currentUser.totalParticipantsEngaged}',
                      ),
                      _buildMiniStat(
                        Icons.calendar_today_outlined,
                        'DAYS ACTIVE',
                        '${DateTime.now().difference(currentUser.joinedAt).inDays}',
                      ),
                      _buildMiniStat(
                        Icons.workspace_premium_outlined,
                        'RANK',
                        currentUser.rank.toUpperCase(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Statistics Cards
            StreamBuilder<List<ActivityIntent>>(
              stream: _firebaseService.getintentsStream(),
              builder: (context, snapshot) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Broadcasts',
                        currentUser.intentsCreated.toString(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Intents Joined',
                        currentUser.intentsJoined.toString(),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            const Text(
              'About Me',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Available for community activities and collaborations. Let's make something happen!",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Interests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.black54),
                  onPressed: _editInterests,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: currentUser.interests.map((interest) {
                return Chip(
                  label: Text('#$interest'),
                  labelStyle: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                  ),
                  backgroundColor: const Color(0xFFFFFFFF),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  side: const BorderSide(color: Colors.black12),
                );
              }).toList(),
            ),

            const SizedBox(height: 48),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _handleSignOut(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.black26,
                side: const BorderSide(color: Colors.black12),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white38, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white24, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black38,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
