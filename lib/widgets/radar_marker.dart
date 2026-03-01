import 'package:flutter/material.dart';
import 'dart:io';

class RadarMarker extends StatefulWidget {
  final int number;
  final Color color;
  final VoidCallback onTap;
  final String? avatarUrl;

  const RadarMarker({
    Key? key,
    required this.number,
    required this.color,
    required this.onTap,
    this.avatarUrl,
  }) : super(key: key);

  @override
  _RadarMarkerState createState() => _RadarMarkerState();
}

class _RadarMarkerState extends State<RadarMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Expanding ring
              Container(
                width: 32 + (_controller.value * 48),
                height: 32 + (_controller.value * 48),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withOpacity(1 - _controller.value),
                    width: 2,
                  ),
                ),
              ),
              // Avatar part
              if (widget.avatarUrl != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.color, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundImage: widget.avatarUrl!.startsWith('http')
                          ? NetworkImage(widget.avatarUrl!) as ImageProvider
                          : FileImage(File(widget.avatarUrl!)),
                    ),
                  ),
                ),
              // Inner solid dot with the number
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.color, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.number}',
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class UserLocationMarker extends StatefulWidget {
  final String? avatarUrl;
  final bool hasBroadcast;

  const UserLocationMarker({
    Key? key,
    this.avatarUrl,
    this.hasBroadcast = false,
  }) : super(key: key);

  @override
  _UserLocationMarkerState createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Outer Pulsing Glow
              Container(
                width: 16 + (_controller.value * 24),
                height: 16 + (_controller.value * 24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withOpacity(
                    (1 - _controller.value) * 0.3,
                  ),
                ),
              ),
              // Solid Center Core
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),

              // Broadcast Blimp for Self (Positioned Above the dot)
              if (widget.hasBroadcast && widget.avatarUrl != null)
                Positioned(
                  bottom: 45, // Moved up above center
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blueAccent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.network(
                        widget.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Label for Self
              Positioned(
                bottom: 30, // Just above the dot
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: const Text(
                    'ME',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
