import 'package:flutter/material.dart';

class CreateIntentSheet extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String activity, String description, int players, int radius)
  onCreate;
  final String? initialActivity;

  const CreateIntentSheet({
    Key? key,
    required this.onClose,
    required this.onCreate,
    this.initialActivity,
  }) : super(key: key);

  @override
  _CreateIntentSheetState createState() => _CreateIntentSheetState();
}

class _CreateIntentSheetState extends State<CreateIntentSheet> {
  final _activityController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _players = 2;
  int _radius = 2000;

  @override
  void initState() {
    super.initState();
    if (widget.initialActivity != null) {
      _activityController.text = widget.initialActivity!;
    }
  }

  @override
  void dispose() {
    _activityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_activityController.text.trim().isEmpty) return;

    widget.onCreate(
      _activityController.text.trim(),
      _descriptionController.text.trim(),
      _players,
      _radius,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF), // Pure white overlay
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Start Activity',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Activity',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children:
                    [
                      {'name': 'Badminton', 'icon': Icons.sports_tennis},
                      {'name': 'Chess', 'icon': Icons.grid_view},
                      {'name': 'Cricket', 'icon': Icons.sports_cricket},
                      {'name': 'Coffee', 'icon': Icons.coffee},
                      {'name': 'Study', 'icon': Icons.menu_book},
                      {'name': 'Cab Sharing', 'icon': Icons.local_taxi},
                    ].map((act) {
                      final bool isSelected =
                          _activityController.text == act['name'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _activityController.text = act['name'] as String;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.black
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                act['icon'] as IconData,
                                size: 14,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black54,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                act['name'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _activityController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'e.g. Badminton, Coffee, Study...',
                  hintStyle: const TextStyle(color: Colors.black26),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF121212),
                    ), // Matte Black
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Description (Optional)',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.black),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText:
                      'e.g. Looking for an intermediate sparring partner...',
                  hintStyle: const TextStyle(color: Colors.black26),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF121212),
                    ), // Matte Black
                  ),
                ),
              ),

              const SizedBox(height: 20),
              // Responsive Inputs Grid
              Wrap(
                spacing: 12,
                runSpacing: 20,
                children: [
                  // Players Input
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Players Needed',
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _players,
                          dropdownColor: const Color(0xFFFFFFFF),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.04),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: [2, 3, 4, 5, 6, 8, 10, 12, 15, 20]
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    '$e',
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _players = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF121212,
                  ), // Matte Black Action
                  foregroundColor: const Color(0xFFFFFFFF), // White Text
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                icon: const Icon(Icons.send),
                label: const Text('Broadcast Radar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
