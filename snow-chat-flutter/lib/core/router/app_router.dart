import 'package:flutter/material.dart';

class AppRouter {
  static const String login = '/login';
  static const String chatList = '/chat';
  static const String chatDetail = '/chat/detail';
  static const String contact = '/contact';
  static const String profile = '/profile';
  static const String groupList = '/group';
  static const String groupDetail = '/group/detail';
  static const String addFriend = '/add-friend';
  static const String friendRequests = '/friend-requests';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case chatDetail:
        return MaterialPageRoute(builder: (_) => const Placeholder());
      case contact:
        return MaterialPageRoute(builder: (_) => const Placeholder());
      case profile:
        return MaterialPageRoute(builder: (_) => const Placeholder());
      case groupList:
        return MaterialPageRoute(builder: (_) => const Placeholder());
      case groupDetail:
        return MaterialPageRoute(builder: (_) => const Placeholder());
      case addFriend:
        return MaterialPageRoute(builder: (_) => const Placeholder());
      case friendRequests:
        return MaterialPageRoute(builder: (_) => const Placeholder());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
                child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
