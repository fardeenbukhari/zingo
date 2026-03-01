import 'package:flutter/material.dart';
import 'dart:io';
import '../models/models.dart';
import '../providers/mock_data.dart';

class ActivityCard extends StatelessWidget {
  final ActivityIntent intent;
  final VoidCallback onClose;
  final Function(String) onJoin;
  final VoidCallback? onDelete;

  const ActivityCard({
    Key? key,
    required this.intent,
    required this.onClose,
    required this.onJoin,
    this.onDelete,
  }) : super(key: key);

  void _showFullScreenImage(
    BuildContext context,
    String imagePath,
    String tag,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) => Scaffold(
          backgroundColor: Colors.black.withOpacity(0.9),
          body: Stack(
            children: [
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Hero(
                    tag: tag,
                    child: imagePath.startsWith('http')
                        ? Image.network(imagePath, fit: BoxFit.contain)
                        : Image.file(File(imagePath), fit: BoxFit.contain),
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

  @override
  Widget build(BuildContext context) {
    final bool isMyActivity = intent.userId == currentUser.userId;
    final heroTag = 'avatar_card_${intent.intentId}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isMyActivity && onDelete != null)
                TextButton.icon(
                  onPressed: () {
                    _showDeleteConfirmDialog(context);
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  label: const Text(
                    'END BROADCAST',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black26, size: 20),
                onPressed: onClose,
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () =>
                    _showFullScreenImage(context, intent.userAvatar, heroTag),
                child: Hero(
                  tag: heroTag,
                  child: CircleAvatar(
                    radius: 32,
                    backgroundImage: intent.userAvatar.startsWith('http')
                        ? NetworkImage(intent.userAvatar) as ImageProvider
                        : FileImage(File(intent.userAvatar)),
                    backgroundColor: Colors.black.withOpacity(0.05),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      intent.activity.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Host: ${intent.userName} • ${intent.skillLevel}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (intent.description != null) ...[
            const SizedBox(height: 16),
            Text(
              intent.description!,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          if (intent.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: intent.tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    Icons.people,
                    '${intent.playersNeeded} slots',
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.location_on,
                    '${intent.radiusM}m',
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.access_time,
                    '${intent.expiresAt.difference(DateTime.now()).inMinutes}m left',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!isMyActivity)
            ElevatedButton(
              onPressed: () => onJoin(intent.intentId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DE9B6),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'JOIN INSTANTLY',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          else
            const Center(
              child: Text(
                'YOUR ACTIVE BROADCAST',
                style: TextStyle(
                  color: Color(0xFF1DE9B6),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: const Text(
          'End Broadcast?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to stop this activity? It will disappear from the radar for everyone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white24),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onDelete != null) onDelete!();
            },
            child: const Text(
              'End Broadcast',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF1DE9B6)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
