import 'package:flutter/material.dart';

class PastActivitiesScreen extends StatelessWidget {
  const PastActivitiesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Past Activities',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'History of Your Interactions',
          style: TextStyle(color: Colors.black45, fontSize: 16),
        ),
      ),
    );
  }
}
