import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/di/app_dependencies.dart';
import 'data/active_conversation_tracker.dart';
import 'data/chat_lifecycle_bridge.dart';
import 'data/chat_settings.dart';
import 'data/chat_transport.dart';
import 'data/repositories/conversations_repository.dart';
import 'data/users_cache.dart';
import 'entities/chat_message.dart';
import 'entities/conversation.dart';
import 'entities/presence.dart';

/// Boot the chat wire stack. Loads persisted settings, attaches the
/// transport to the MessagesRepository, opens the WebSocket if a URL
/// is configured, and keeps both wired together as settings change.
///
/// Idempotent — safe to call once from `main` after
/// `AppDependencies.bootstrap()`.
Future<void> bootChatTransport(AppDependencies deps) async {
  final settings = deps.chatSettings;
  final transport = deps.chatTransport;
  final messages = deps.messagesRepository;
  final conversations = deps.conversationsRepository;
  final presence = deps.presenceRepository;
  final remote = deps.chatsRemoteDataSource;

  await settings.load();
  messages.attachTransport(transport);

  // Bulk-hydrate presence from `GET /chats/presence` so avatar dots
  // and direct-conv subtitles paint with real state on the first
  // frame. Fire-and-forget — the call swallows errors internally.
  unawaited(presence.loadAll());

  // Resolve who we are from `/users/me` BEFORE wiring the repos so
  // `currentUserId` is the real backend id and the UsersCache has
  // self's name available for inbox tile / chat header rendering on
  // first paint (no waiting for the user to open the picker). Then
  // try to bulk-fetch `/users` so OTHER members' fullName also
  // resolves before `loadInbox()` runs — without this, the inbox
  // tiles render with raw numeric ids until the user opens the picker.
  //
  // Failures here are swallowed — the rest of the chat boot continues
  // with whatever the cache has (often just self).
  {
    final users = deps.usersRemoteDataSource;
    try {
      final meUser = await users.me();
      final displayName = meUser.fullName.trim().isEmpty
          ? meUser.email
          : meUser.fullName;
      unawaited(settings.setIdentity(
        userId: meUser.id,
        userName: displayName,
      ));
      UsersCache.instance.put(userId: meUser.id, name: displayName);
    } catch (_) {
      // Not signed in yet (401), no network, or tokens missing — fine.
    }
    try {
      final page = await users.listUsers(pageSize: 200);
      UsersCache.instance.putAll(
        page.items.where((u) => u.enabled).map((u) => (
              id: u.id,
              name: u.fullName.trim().isEmpty ? u.email : u.fullName,
              avatarUrl: null as String?,
            )),
      );
    } catch (_) {
      // 403 for CUSTOMER / STAFF roles, or auth not ready. Either way,
      // inbox + conversation pages will show ids for unresolved users
      // until the backend ships `name` on MemberDto or a public
      // `/users/{id}` endpoint.
    }
  }

  // Prompt 2 + 3 — wire the REST data source into both repos so
  // `loadInbox()` (conversations) and `loadForConversation(id)`
  // (messages) can pull real backend rows on demand. Done once here so
  // pages don't have to.
  conversations.setRemote(remote, currentUserId: settings.userId);
  messages.setRemote(remote);

  // Pump every inbound peer event straight into the repo. For
  // received messages (Slice 10.1.6), also push the conversation's
  // last-message preview + unread counter so the inbox tile updates
  // in real time. Skip the unread bump when the user is sitting on
  // that conversation's page (tracked by ActiveConversationTracker).
  transport.events.listen((event) async {
    if (event is MessageReceivedEvent) {
      // Slice 10.1.8 — drop messages that weren't addressed to us
      // before touching any local state. Empty targetIds = legacy
      // broadcast for back-compat with pre-10.1.8 clients on the wire.
      if (event.targetIds.isNotEmpty &&
          !event.targetIds.contains(settings.userId)) {
        return;
      }
      // Slice 10.1.8 — redirect inbound DIRECT messages onto the
      // receiver's local conv with the sender. The seed reuses ids
      // like conv-005 ("Pisey direct" on every device), so Vibol's
      // outgoing message tagged conv-005 would otherwise land in
      // Pisey's own self-direct slot instead of her chat-with-Vibol.
      // Group messages keep the wire conv id verbatim — group
      // creation broadcasts a shared id (Slice 10.1.7).
      ChatMessage m = event.message;
      final isDirectToMe = event.targetIds.length == 1 &&
          event.targetIds.first == settings.userId;
      if (isDirectToMe) {
        final localConv =
            await conversations.findDirectWith(m.senderId);
        if (localConv != null && localConv.id != m.conversationId) {
          m = m.copyWith(conversationId: localConv.id);
        }
      }
      unawaited(messages
          .applyInbound(MessageReceivedEvent(m, targetIds: event.targetIds)));
      final preview = _previewFor(m);
      // If the conv doesn't exist locally yet (peer started a fresh
      // direct conv we haven't seen, or backend pushed before our
      // first loadInbox), pull it from the backend so future messages
      // land in a real row and the inbox tile appears. Both
      // updateLastMessage and bumpUnread throw StateError when the
      // conv is missing — try once, fall back to refreshOne + retry,
      // and silently give up on the second failure (next loadInbox
      // will reconcile).
      unawaited(() async {
        Future<void> applyPreview() async {
          await conversations.updateLastMessage(
            id: m.conversationId,
            body: preview,
            senderId: m.senderId,
            senderName: m.senderName,
            type: m.type.name,
            at: m.sentAt,
          );
          if (!ActiveConversationTracker.instance
              .isActive(m.conversationId)) {
            await conversations.bumpUnread(m.conversationId);
          }
        }

        try {
          await applyPreview();
        } catch (_) {
          try {
            await conversations.refreshOne(m.conversationId);
            await applyPreview();
          } catch (_) {/* give up — next loadInbox reconciles */}
        }
      }());
    } else {
      unawaited(messages.applyInbound(event));
      if (event is ConversationCreatedEvent) {
        unawaited(_applyInboundGroup(event, conversations, settings));
      } else if (event is ConversationUpdatedEvent) {
        unawaited(_applyInboundConversationUpdate(
          event,
          conversations,
          settings,
        ));
      } else if (event is ProfileUpdatedEvent) {
        unawaited(_applyInboundProfileUpdate(event, conversations));
      } else if (event is ConversationAvatarUpdatedEvent) {
        unawaited(_applyInboundAvatarUpdate(
          event,
          conversations,
          settings,
        ));
      } else if (event is MessageReadEvent) {
        // Sync the conv-side member.lastReadMessageId in addition to
        // the message-side readByUserIds patched by applyInbound
        // above. Keeps both data axes consistent for any UI that
        // wants to show "Read by X up to Y".
        conversations.applyInboundRead(
          conversationId: event.conversationId,
          userId: event.userId,
          lastReadMessageId: event.lastReadMessageId,
        );
      } else if (event is PresenceUpdatedEvent) {
        try {
          presence.applyInboundPresence(Presence.fromJson(event.payload));
        } catch (_) {
          // Malformed payload — leave the cache alone; next loadAll
          // will reconcile.
        }
      } else if (event is ConversationRemovedEvent) {
        // Admin kicked us out of the group OR we left ourselves on a
        // different device. Drop the conv from the local cache so
        // the inbox tile disappears immediately. If we're currently
        // viewing the conv, the StreamBuilder<ChatConversation?> in
        // chat info / chat page yields null → page handles its own
        // "conv missing" empty state.
        unawaited(conversations.delete(event.conversationId));
      }
    }
  });

  // The call signalling service is constructed eagerly by
  // AppDependencies, so its transport listener is already wired before
  // any peer can place a call.

  // Slice 10.2.6 — re-kick the WebSocket whenever the app returns to
  // the foreground, in case the OS dropped it while we were
  // backgrounded. No-op when the socket is still alive.
  ChatLifecycleBridge(
    transport: transport,
    settings: settings,
    presence: presence,
    streamEngine: deps.streamCallEngine,
    signaling: deps.callSignalingService,
  ).attach();

  // Open the socket with the current settings, and re-open whenever
  // the user changes the URL or identity. After each (re)connect,
  // refresh the inbox from REST so the conversation list shows real
  // backend rows instead of seed data.
  //
  // URL resolution priority:
  //   1. `settings.apiBaseUrl` — explicit chat override (chat ⋮ menu)
  //   2. `Dio.options.baseUrl` minus `/api/v1` — same backend the REST
  //      calls already hit, so STOMP follows REST automatically. This
  //      is the line that fixes "A sends, B doesn't see anything":
  //      previously we passed `settings.relayUrl` (the legacy LAN demo
  //      URL, defaults to empty), so the STOMP socket never connected
  //      and inbound `/user/queue/inbox` + `/topic/conversations/{id}`
  //      frames had nowhere to land.
  //   3. `settings.relayUrl` — legacy demo fallback
  String resolveStompBase() {
    if (settings.apiBaseUrl.isNotEmpty) return settings.apiBaseUrl;
    {
      final dioBase = deps.dio.options.baseUrl;
      if (dioBase.isNotEmpty) {
        // Strip `/api/v1` (and any trailing slash) so the transport
        // can append `/ws` cleanly. `Uri.parse` keeps us safe against
        // missing scheme / path-only inputs.
        final uri = Uri.tryParse(dioBase);
        if (uri != null && uri.hasScheme) {
          final port = uri.hasPort ? ':${uri.port}' : '';
          return '${uri.scheme}://${uri.host}$port';
        }
      }
    }
    return settings.relayUrl;
  }

  Future<void> apply() async {
    await transport.updateConfig(
      url: resolveStompBase(),
      userId: settings.userId,
      userName: settings.userName,
    );
    // Re-bind in case the user id changed (sign-out → sign-in flip).
    conversations.setRemote(remote, currentUserId: settings.userId);
    unawaited(conversations.loadInbox());
    // Re-hydrate presence too — the STOMP broker may have advanced
    // its state while we were disconnected, and the global
    // `/topic/presence` subscription only delivers DELTAS once
    // we're connected (not the current snapshot).
    unawaited(presence.loadAll());
    // Reconcile any active call against the backend. If we were
    // mid-call when the socket dropped, peers may have hung up
    // while we couldn't hear them; `GET /chats/calls/{id}` gives
    // us the canonical state. No-op when no active call.
    unawaited(deps.callSignalingService.reconcileActive());
  }

  await apply();
  settings.watch().listen((_) => unawaited(apply()));
}

/// Slice 10.1.7 — hydrate a peer-created group on this device.
///
/// Filters out:
///   * non-group conversations (direct convs are created implicitly
///     on first message, no envelope needed)
///   * envelopes that don't list us in `participantIds` (relay is
///     broadcast-only, so every connected client sees every envelope)
///   * duplicates — `findById` short-circuits if we already have the
///     conversation locally, so peers re-broadcasting the same id is
///     a no-op
Future<void> _applyInboundGroup(
  ConversationCreatedEvent event,
  ConversationsRepository conversations,
  ChatSettings settings,
) async {
  // Hydrate any inbound conv (direct OR group) from the backend so
  // members[] arrives with full info (role, lastReadMessageId, etc.)
  // and names resolve via UsersCache. This is the fix for "group
  // members don't show until the first message" — without it we
  // would build participantPreviews from only the bare participant
  // ids in the event, then wait for the conversation to come back
  // through the next loadInbox (or a message arrival) to fill them.
  //
  // refreshOne is a no-op when the conv already exists in the cache
  // and `_remote` is bound, so we don't bother deduping here.
  await conversations.refreshOne(event.conversationId);
  // If refresh failed silently (e.g. backend 404 on a fresh conv
  // that hasn't propagated yet), fall through to the legacy build
  // so SOMETHING shows up.
  final existing = await conversations.findById(event.conversationId);
  if (existing != null) return;
  if (!event.isGroup) return;
  final me = settings.userId;
  if (!event.participantIds.contains(me)) return;

  // Legacy fallback path — build participantPreviews from the
  // directory ids carried in the event. Names resolve via UsersCache
  // when populated; unknown ids land as `User #<id>` placeholders.
  final previews = <ChatParticipantPreview>[];
  for (final id in event.participantIds) {
    if (id == me) continue;
    final cachedName = UsersCache.instance.nameOf(id);
    previews.add(ChatParticipantPreview(
      employeeId: id,
      name: cachedName ?? 'User #$id',
      avatarUrl: UsersCache.instance.avatarOf(id),
    ));
  }
  final online = previews
      .where((p) => p.presence == PresenceStatus.online)
      .length;

  await conversations.create(ChatConversation(
    id: event.conversationId,
    name: event.name,
    isGroup: true,
    isMuted: false,
    unreadCount: 0,
    createdAt: event.createdAt,
    updatedAt: event.createdAt,
    participantPreviews: previews,
    totalMembers: event.participantIds.length,
    onlineCount: online,
  ));
}

/// Slice 10.3.4 — peer admin renamed a group on their device. Apply
/// the new name locally so every member's inbox tile + AppBar stays
/// in sync. Filters on participantIds the same way Slice 10.1.7 does
/// — we only care if we're a member.
Future<void> _applyInboundConversationUpdate(
  ConversationUpdatedEvent event,
  ConversationsRepository conversations,
  ChatSettings settings,
) async {
  if (event.participantIds.isNotEmpty &&
      !event.participantIds.contains(settings.userId)) {
    return;
  }
  // Always pull the full conv from the backend. This handles:
  //   * rename                — old code path
  //   * avatar URL change     — old code path missed it
  //   * add / remove members  — bug: old code returned early when the
  //                             name didn't change, so new members
  //                             never appeared in peers' chat info
  //                             until they hit loadInbox (next boot).
  //   * fresh conv for a just-added member — `refreshOne` upserts so
  //                             the conv appears even when it wasn't
  //                             in the cache.
  // refreshOne swallows GET errors internally; nothing to handle here.
  await conversations.refreshOne(event.conversationId);
}

/// Slice 10.3.4 — peer changed their display name. Rename our local
/// direct conversation with them so the AppBar + inbox tile pick up
/// the new label without us having to restart the app.
Future<void> _applyInboundProfileUpdate(
  ProfileUpdatedEvent event,
  ConversationsRepository conversations,
) async {
  final localConv = await conversations.findDirectWith(event.userId);
  if (localConv == null || localConv.name == event.newName) return;
  try {
    await conversations.rename(localConv.id, event.newName);
  } catch (_) {}
}

/// Slice 10.3.6 — admin set or cleared a group's avatar on their
/// device. We decode the base64 bytes, write them to our app cache
/// dir under a deterministic name keyed by conversationId (so the
/// next sync overwrites the same file rather than leaking copies),
/// and point our local conv at that path. A null `avatarBase64`
/// means "remove the photo" — we delete the cache file and clear
/// the path.
///
/// Filters on participantIds like every other group envelope so a
/// peer that's not in the group is a silent no-op.
Future<void> _applyInboundAvatarUpdate(
  ConversationAvatarUpdatedEvent event,
  ConversationsRepository conversations,
  ChatSettings settings,
) async {
  if (event.participantIds.isNotEmpty &&
      !event.participantIds.contains(settings.userId)) {
    return;
  }
  final existing = await conversations.findById(event.conversationId);
  if (existing == null) return;
  // Remove path branch — null bytes means the admin cleared the photo.
  if (event.avatarBase64 == null) {
    try {
      await conversations.setAvatarPath(event.conversationId, null);
    } catch (_) {}
    return;
  }
  try {
    final bytes = base64Decode(event.avatarBase64!);
    final ext = (event.fileExtension == null || event.fileExtension!.isEmpty)
        ? '.jpg'
        : (event.fileExtension!.startsWith('.')
            ? event.fileExtension!
            : '.${event.fileExtension!}');
    final dir = await getApplicationCacheDirectory();
    final file = File('${dir.path}/chat_avatar_${event.conversationId}$ext');
    await file.writeAsBytes(bytes, flush: true);
    await conversations.setAvatarPath(event.conversationId, file.path);
  } catch (_) {
    // Corrupt payload or filesystem issue — leave the existing
    // avatar alone rather than crashing the listener.
  }
}

/// Slice 10.1.6 — short preview text for the inbox tile, matching
/// what we already do for outgoing messages on the conversation page
/// (file → 📎 filename, voice → 🎤 …, image → 📷 Photo, text → body).
String _previewFor(ChatMessage m) {
  switch (m.type) {
    case ChatMessageType.text:
      return m.body ?? '';
    case ChatMessageType.voice:
      final d = m.voiceDurationSeconds ?? 0;
      final mm = (d ~/ 60).toString().padLeft(1, '0');
      final ss = (d % 60).toString().padLeft(2, '0');
      return '🎤 Voice message · $mm:$ss';
    case ChatMessageType.image:
      return '📷 Photo';
    case ChatMessageType.file:
      return '📎 ${m.fileName ?? 'File'}';
    case ChatMessageType.system:
      return m.body ?? '';
  }
}
