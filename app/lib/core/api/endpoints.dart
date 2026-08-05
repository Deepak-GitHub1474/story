class Endpoints {
  const Endpoints._();

  static const String baseUrl = String.fromEnvironment(
    'STORY_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:9000/v1',
  );

  static const String health = '/health';
  static const String ready = '/health/ready';

  static const String signup = '/auth/signup';
  static const String signin = '/auth/signin';
  static const String refresh = '/auth/refresh';
  static const String signout = '/auth/signout';
  static const String signoutAll = '/auth/signout-all';
  static const String me = '/auth/me';
  static const String usernameAvailable = '/auth/username-available';
  static const String sessions = '/auth/sessions';
  static const String changePassword = '/auth/password/change';

  static const String interests = '/interests';
  static const String categories = '/communities/categories';
  static const String updateProfile = '/users/me';
  static const String regenerateAvatar = '/users/me/avatar/regenerate';

  static String publicProfile(String username) => '/users/$username';
}
