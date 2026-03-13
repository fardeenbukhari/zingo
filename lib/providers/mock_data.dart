import '../models/models.dart';

User currentUser = User(
  userId: "guest_user",
  name: "Guest",
  email: "guest@sharda.ac.in",
  avatar: "", // Default person icon until Google Sync
  interests: ["Exploration", "Social", "Events"],
  pingPoints: 120,
  joinedAt: DateTime.now().subtract(const Duration(days: 30)),
);

final mockLocation = LocationPoint(
  lat: 28.4731,
  lng: 77.4827,
); // Sharda University, India

final List<ActivityIntent> initialIntents =
    []; // Start with empty, fetch from Firebase
