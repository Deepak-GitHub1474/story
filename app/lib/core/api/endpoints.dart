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

  static const String stories = '/stories';
  static const String feed = '/stories/feed';
  static const String myStories = '/stories/mine';

  static String publicProfile(String username) => '/users/$username';

  static String userStories(String username) => '/users/$username/stories';

  static String story(String id) => '/stories/$id';

  static String publishStory(String id) => '/stories/$id/publish';

  static String unpublishStory(String id) => '/stories/$id/unpublish';

  static String storyLike(String id) => '/stories/$id/like';

  static String storyShare(String id) => '/stories/$id/share';

  static String storyComments(String id) => '/stories/$id/comments';

  static String comment(String id) => '/comments/$id';

  static String commentReplies(String id) => '/comments/$id/replies';

  static String commentLike(String id) => '/comments/$id/like';

  static const String communities = '/communities';
  static const String myCommunities = '/communities/me';

  static String community(String slug) => '/communities/$slug';

  static String communityJoin(String slug) => '/communities/$slug/join';

  static String communityStories(String slug) => '/communities/$slug/stories';

  static String connection(String username) => '/connections/$username';

  static const String following = '/connections/following';
  static const String followers = '/connections/followers';
  static const String blocked = '/connections/blocked';
  static const String search = '/search';
  static const String reports = '/reports';

  static const String keys = '/users/me/keys';
  static const String chatIdentity = '/chat/identity';
  static const String chatBackup = '/chat/backup';
  static const String chatUnread = '/chat/unread-count';
  static const String chatPresence = '/chat/presence';

  static String chatTyping(String id) => '/chat/conversations/$id/typing';
  static const String chatConversations = '/chat/conversations';
  static const String chatPeople = '/chat/people';

  static String chatIdentityOf(String username) => '/chat/identity/$username';

  static String chatConversation(String id) => '/chat/conversations/$id';

  static String chatAccept(String id) => '/chat/conversations/$id/accept';

  static String chatKeys(String id) => '/chat/conversations/$id/keys';

  static String chatMessages(String id) => '/chat/conversations/$id/messages';

  static String chatRead(String id) => '/chat/conversations/$id/read';

  static String chatMessage(String id, String messageId) =>
      '/chat/conversations/$id/messages/$messageId';

  static String chatReaction(String id, String messageId) =>
      '/chat/conversations/$id/messages/$messageId/reaction';

  static const String tickets = '/tickets';
  static const String securityActivity = '/security-activity';
  static const String vaultOverview = '/vault/overview';
  static const String vaultPasscodes = '/vault/passcodes';
  static const String realtimeTicket = '/realtime/ticket';
  static const String suggestions = '/suggestions';
  static const String aiPolish = '/ai/polish';
  static const String aiDraft = '/ai/draft';
  static const String mediaImages = '/media/images';
  static const String vaultItems = '/vault/items';
  static const String vaultSearch = '/vault/search';

  static String vaultItem(String id) => '/vault/items/$id';

  static String vaultItemComplete(String id) => '/vault/items/$id/complete';

  static String vaultItemDownload(String id) => '/vault/items/$id/download';

  static const String email = '/users/me/email';
  static const String emailVerify = '/users/me/email/verify';
  static const String emailResend = '/users/me/email/resend';
  static const String resetRequest = '/auth/password-reset/request';
  static const String resetVerify = '/auth/password-reset/verify';
  static const String resetComplete = '/auth/password-reset/complete';
  static const String deactivate = '/users/me/deactivate';
  static const String deleteAccount = '/users/me/delete';
  static const String cancelDeletion = '/users/me/delete/cancel';

  static const String notifications = '/notifications';
  static const String unreadCount = '/notifications/unread-count';
  static const String markAllNotificationsRead = '/notifications/read-all';

  static String markNotificationRead(String id) => '/notifications/$id/read';
}
