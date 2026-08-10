import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/providers/chat_providers.dart';
import '../../features/communities/providers/community_providers.dart';
import '../../features/notifications/providers/notification_providers.dart';
import '../../features/search/providers/search_providers.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../features/vault/providers/recovery_providers.dart';
import '../../features/stories/providers/story_providers.dart';
import '../../features/vault/providers/vault_providers.dart';
import '../../features/settings/providers/theme_provider.dart';

Future<void> forgetSession(Ref ref) async {
  await ref.read(feedCacheProvider).clear();

  for (final provider in userScopedProviders) {
    ref.invalidate(provider);
  }
}

final userScopedProviders = <ProviderOrFamily>[
  feedProvider,
  myStoriesProvider,
  storyDetailProvider,
  commentsProvider,
  notificationsProvider,
  unreadCountProvider,
  conversationsProvider,
  conversationProvider,
  chatUnreadProvider,
  chatPeopleProvider,
  chatIdentityProvider,
  chatLockedProvider,
  chatStarterProvider,
  chatCryptoProvider,
  myCommunitiesProvider,
  communityBrowseProvider,
  publicProfileProvider,
  suggestionsProvider,
  searchProvider,
  sessionsProvider,
  securityActivityProvider,
  ticketsProvider,
  vaultItemsProvider,
  vaultOverviewProvider,
  vaultSessionProvider,
  vaultUploadProvider,
  vaultTransferProvider,
];
