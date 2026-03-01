import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/mock_data.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  final List<String> _avatarLibrary = [
    'https://i.pravatar.cc/150?u=sharda1',
    'https://i.pravatar.cc/150?u=sharda2',
    'https://i.pravatar.cc/150?u=sharda3',
    'https://i.pravatar.cc/150?u=sharda4',
    'https://i.pravatar.cc/150?u=sharda5',
    'https://i.pravatar.cc/150?u=sharda6',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&q=80',
    'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=150&q=80',
  ];

  void _handleSignOut(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _showUsernameDialog() {
    final TextEditingController _nameController = TextEditingController(
      text: currentUser.name,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Set Username',
          style: TextStyle(color: Colors.black),
        ),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.black),
          decoration: const InputDecoration(
            hintText: 'Enter new username',
            hintStyle: TextStyle(color: Colors.black26),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black38),
            ),
          ),
          TextButton(
            onPressed: () {
              if (_nameController.text.trim().isNotEmpty) {
                setState(() {
                  currentUser = User(
                    userId: currentUser.userId,
                    name: _nameController.text.trim(),
                    avatar: currentUser.avatar,
                    interests: currentUser.interests,
                    skillLevels: currentUser.skillLevels,
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFF1DE9B6)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Avatar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _avatarLibrary.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        currentUser = User(
                          userId: currentUser.userId,
                          name: currentUser.name,
                          avatar: _avatarLibrary[index],
                          interests: currentUser.interests,
                          skillLevels: currentUser.skillLevels,
                        );
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: currentUser.avatar == _avatarLibrary[index]
                              ? const Color(0xFF1DE9B6)
                              : Colors.transparent,
                          width: 2,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: NetworkImage(_avatarLibrary[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Or Upload from Device',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white70),
              title: const Text(
                'Pick from Gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  setState(() {
                    currentUser = User(
                      userId: currentUser.userId,
                      name: currentUser.name,
                      avatar: image.path,
                      interests: currentUser.interests,
                      skillLevels: currentUser.skillLevels,
                    );
                  });
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
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
                  child: imagePath.startsWith('http')
                      ? Image.network(imagePath, fit: BoxFit.contain)
                      : Image.file(File(imagePath), fit: BoxFit.contain),
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
                      child: Container(
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
                          backgroundImage: currentUser.avatar.startsWith('http')
                              ? NetworkImage(currentUser.avatar)
                                    as ImageProvider
                              : FileImage(File(currentUser.avatar)),
                          backgroundColor: Colors.black.withOpacity(0.05),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: GestureDetector(
                      onTap: _showAvatarPicker,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1DE9B6),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentUser.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      size: 20,
                      color: Colors.black26,
                    ),
                    onPressed: _showUsernameDialog,
                  ),
                ],
              ),
            ),
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
                    const Icon(
                      Icons.school,
                      size: 14,
                      color: Color(0xFF1DE9B6),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Sharda University Member',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Statistics Cards
            StreamBuilder<List<ActivityIntent>>(
              stream: _firebaseService.getintentsStream(),
              builder: (context, snapshot) {
                final hostedCount = snapshot.hasData
                    ? snapshot.data!
                          .where((i) => i.userId == currentUser.userId)
                          .length
                    : 0;

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Active Now',
                        hostedCount.toString(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard('Total Broadcasts', '1')),
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
            const Text(
              'Interests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
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
