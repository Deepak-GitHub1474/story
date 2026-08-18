import '../../routing/routes.dart';

String? routeForPush(Map<String, dynamic> data) {
  final target = data['target_id'] as String? ?? '';
  switch (data['target_kind'] as String? ?? '') {
    case 'conversation':
      return target.isEmpty ? Routes.chats : '${Routes.chat}/$target';
    case 'story':
      return target.isEmpty ? Routes.activity : '${Routes.story}/$target';
    case 'user':
      final username = data['username'] as String? ?? '';
      return username.isEmpty ? Routes.activity : '${Routes.user}/$username';
    default:
      return data.isEmpty ? null : Routes.activity;
  }
}
