import 'package:flutter/material.dart';

class RemoteUserMarker extends StatelessWidget {
  final String? avatarUrl;
  final bool hasBroadcast;
  final VoidCallback onTap;
  final double scanRadius;
  final double distance;

  const RemoteUserMarker({
    Key? key,
    this.avatarUrl,
    this.hasBroadcast = false,
    required this.onTap,
    this.scanRadius = 0,
    this.distance = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if the wave is "touching" this marker (within a 10m threshold)
    final bool isHighlighted = (scanRadius - distance).abs() < 25;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: isHighlighted ? 70 : 60,
        height: isHighlighted ? 70 : 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Highlight Ring (Only visible when "touched")
            if (isHighlighted)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                builder: (context, value, child) {
                  return Container(
                    width: 34 + (value * 20),
                    height: 34 + (value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1DE9B6).withOpacity(1 - value),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),

            // Main Core
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isHighlighted ? 38 : 34,
              height: isHighlighted ? 38 : 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isHighlighted ? const Color(0xFF1DE9B6) : Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isHighlighted
                        ? const Color(0xFF1DE9B6).withOpacity(0.4)
                        : Colors.black.withOpacity(0.15),
                    blurRadius: isHighlighted ? 15 : 8,
                    spreadRadius: isHighlighted ? 2 : 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.black.withOpacity(0.05),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.person,
                              size: 20,
                              color: Colors.black12,
                            ),
                      )
                    : const Icon(Icons.person, size: 20, color: Colors.black12),
              ),
            ),

            // Broadcast Indicator
            if (hasBroadcast)
              Positioned(
                top: isHighlighted ? 6 : 10,
                right: isHighlighted ? 6 : 10,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DE9B6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
