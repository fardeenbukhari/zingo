import '../models/models.dart';

User currentUser = User(
  userId: "guest_user",
  name: "Guest",
  avatar: "https://i.pravatar.cc/150?u=zingo_guest",
  interests: ["Exploration", "Social", "Events"],
  skillLevels: {},
);

final mockLocation = LocationPoint(
  lat: 28.4731,
  lng: 77.4827,
); // Sharda University, India

final List<ActivityIntent> initialIntents =
    []; // Start with empty, fetch from Firebase
