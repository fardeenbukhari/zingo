import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
              // Multiple expanding rings for depth
              for (int i = 0; i < 3; i++)
                Opacity(
                  opacity: (1 - ((_controller.value + (i * 0.33)) % 1)) * 0.5,
                  child: Container(
                    width: 32 + ((((_controller.value + (i * 0.33)) % 1)) * 60),
                    height:
                        32 + ((((_controller.value + (i * 0.33)) % 1)) * 60),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.color, width: 1.5),
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
                      backgroundImage:
                          widget.avatarUrl!.startsWith('http') || kIsWeb
                          ? NetworkImage(widget.avatarUrl!) as ImageProvider
                          : FileImage(File(widget.avatarUrl!)),
                    ),
                  ),
                ),
              // Inner solid dot with the number
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.color, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.number}',
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
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
    this.onTap,
  }) : super(key: key);

  final VoidCallback? onTap;

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
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 80,
        height: 80,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Multi-layered Pulsing Background
                for (int i = 0; i < 2; i++)
                  Container(
                    width: 16 + (((_controller.value + (i * 0.5)) % 1) * 40),
                    height: 16 + (((_controller.value + (i * 0.5)) % 1) * 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1DE9B6).withOpacity(
                        (1 - ((_controller.value + (i * 0.5)) % 1)) * 0.4,
                      ),
                    ),
                  ),
                // Solid Center Core
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DE9B6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1DE9B6).withOpacity(0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),

                // Label for Self
                Positioned(
                  bottom: 32, // Just above the dot
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.hasBroadcast) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1DE9B6),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const Text(
                          'YOU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
