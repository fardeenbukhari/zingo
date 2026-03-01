# Zingoo

Zingoo is a dynamic, location-based interactive Flutter application. It allows users to discover live events, connect with people nearby, participate in hosted activities, and communicate in real-time. 

With an intuitive map-based interface, users can see activities around them and interact seamlessly with other local users. Built with an emphasis on modern UI/UX design, Zingoo leverages cutting-edge backend technologies including Firebase and WebSockets to provide a fast, real-time experience.

## Primary Features

* **Interactive Map:** View your current location and discover nearby users or live events in real-time using `flutter_map` and real-time backend updates.
* **Live Events & Activities:** Browse live events happening locally, view details, and participate seamlessly. Users can view past activities, live events, and their self-hosted activities.
* **Real-time Chat:** Includes a robust messaging system that supports individual chat rooms and lists recent conversations.
* **Authentication:** Secure user authentication handled effortlessly.
* **Profile Management:** Manage your personal details, custom avatars, and view your activity history.
* **Notifications:** Local notifications system built right in to keep users updated on new messages and event updates.

## Tech Stack & Architecture

- **Framework:** [Flutter](https://flutter.dev/)
- **State Management / Architecture:** Provider / Modular architecture.
- **Backend Services:**
  - **Firebase Authentication:** Handles secure user login and sign-up.
  - **Cloud Firestore:** Real-time database used to store users, chats, and event information.
- **Real-time Syncing:** WebSockets (`web_socket_channel`) are utilized for fast, bi-directional communication, ideal for plotting markers and chat data dynamically.
- **Mapping:** Powered by `flutter_map`, `latlong2`, and real-time geolocation provided by `geolocator`.

## Folder Structure

The project is structured logically around features and core principles of layered architecture:

* `/lib/screens/` - Contains all independent screen widgets (e.g., MapScreen, LoginScreen, ChatRoomScreen, ProfileScreen).
* `/lib/services/` - Houses the business logic services integrating things like `NotificationService`.
* `/lib/widgets/` - Reusable UI widgets and elements across screens.

## Getting Started

To run this project, make sure you have the following software installed:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Version >= 3.10.8)
- [Android Studio / Xcode](https://docs.flutter.dev/get-started/install/macos)

1. Clone this repository to your local machine:
   ```bash
   git clone https://github.com/fardeenbukhari/zingo.git
   ```
2. Enter the project directory:
   ```bash
   cd zingo
   ```
3. Fetch dependencies:
   ```bash
   flutter pub get
   ```
4. Setup Firebase:
   - Make sure your local project is correctly hooked to your Firebase console via `firebase_options.dart`.
5. Run the app:
   ```bash
   flutter run
   ```

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License

[MIT](https://choosealicense.com/licenses/mit/)
