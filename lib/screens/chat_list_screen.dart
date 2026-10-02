// lib/screens/chat_list_screen.dart
//
// Home screen for a logged-in Teacher/Student: the chat list itself, not a
// menu screen in front of it. Shows every chat where this user is a
// participant, sorted by most recent activity, with three tabs (All /
// Individual / Groups) and a total-unread indicator in the AppBar -
// WhatsApp-style. Each row bolds itself with a green unread-count badge
// when there's something unseen, and shows a sent/read tick on the last
// message whenever the current user sent it.
//
// This screen doubles as the role "dashboard": TeacherDashboard and
// StudentDashboard just configure it with a role-specific FloatingActionButton
// (Create Group Chat / Find a Teacher) and AppBar color instead of showing
// a separate button menu first.
//
// Two list-visibility rules, both applied before a chat ever reaches
// _buildRow():
//   - A chat with no `lastMessage` yet (created by tapping "Message" on a
//     profile/search result, before anyone's actually sent anything) is
//     hidden entirely - it used to show up as "Start the conversation...",
//     which was just clutter for a conversation nobody started yet.
//   - A chat the current user deleted "for me" (chats/{id}.deletedFor.{uid},
//     a Timestamp) stays hidden only until `lastUpdated` moves past that
//     timestamp - i.e. it reappears automatically the moment anyone sends a
//     new message, same as WhatsApp. No rules change needed for this - the
//     existing chats/{id} update rule already lets any participant write any
//     field except `participants` freely, same as lastRead/unreadCount.
//
// Long-press a row for "Delete for Me" (the above) or "Delete for Everyone"
// (hard-deletes the chat doc + every message, for every participant - only
// offered for a 1:1 chat or if you're the group's groupAdmin, matching
// firestore.rules' chats/{id} `allow delete`).

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_strings.dart';
import '../utils/push_notifications.dart';
import '../utils/unread_badge.dart';
import '../widgets/empty_state.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class _OtherUserInfo {
  final String name;
  final String? role;

  const _OtherUserInfo(this.name, this.role);
}

/// Fixed content rendered above the tabs/list - typically a [DashboardHeader]
/// built from the counts this screen already computes, so a role dashboard
/// gets real "home" content for free instead of an extra Firestore query.
typedef ChatListHomeHeaderBuilder =
    Widget Function(
      BuildContext context, {
      required int totalUnread,
      required int totalChats,
      required int totalGroups,
    });

class ChatListScreen extends StatefulWidget {
  final Widget? floatingActionButton;
  final Color appBarColor;
  final List<Widget>? extraActions;
  final ChatListHomeHeaderBuilder? homeHeader;

  const ChatListScreen({
    super.key,
    this.floatingActionButton,
    this.appBarColor = Colors.blue,
    this.extraActions,
    this.homeHeader,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _lastNotifiedUnread = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_OtherUserInfo> _getOtherUserInfo(String otherUid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherUid)
        .get();
    final data = doc.data();
    return _OtherUserInfo(data?['name'] ?? 'User', data?['role'] as String?);
  }

  String _formatTime(dynamic rawTimestamp) {
    if (rawTimestamp is! Timestamp) return '';
    final dt = rawTimestamp.toDate();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Tick for the last message preview: only shown when the current user
  /// sent it. Blue double tick once every other participant has read it
  /// (all of them, for group chats), grey single tick otherwise.
  Widget? _buildLastMessageTick(Map<String, dynamic> data, String currentUid) {
    if (data['lastSenderId'] != currentUid) return null;

    final lastUpdated = data['lastUpdated'];
    if (lastUpdated is! Timestamp) return null;

    final participants = List<String>.from(data['participants'] ?? []);
    final lastRead = Map<String, dynamic>.from(data['lastRead'] ?? {});
    final otherUids = participants.where((uid) => uid != currentUid).toList();

    final readByAll =
        otherUids.isNotEmpty &&
        otherUids.every((uid) {
          final readTs = lastRead[uid];
          if (readTs is! Timestamp) return false;
          return !readTs.toDate().isBefore(lastUpdated.toDate());
        });

    return Icon(
      readByAll ? Icons.done_all : Icons.done,
      size: 15,
      color: readByAll ? Colors.blue : Colors.grey,
    );
  }

  int _unreadFor(Map<String, dynamic> data, String currentUid) {
    return (data['unreadCount'] as Map<String, dynamic>?)?[currentUid]
            as int? ??
        0;
  }

  bool _isVisible(Map<String, dynamic> data, String currentUid) {
    if (data['lastMessage'] == null) return false;

    final deletedAt =
        (data['deletedFor'] as Map<String, dynamic>?)?[currentUid]
            as Timestamp?;
    if (deletedAt == null) return true;

    final lastUpdated = data['lastUpdated'] as Timestamp?;
    if (lastUpdated == null) return true;
    return lastUpdated.toDate().isAfter(deletedAt.toDate());
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showDeleteOptions(
    BuildContext context,
    String chatId,
    Map<String, dynamic> data,
    String currentUid,
  ) {
    final isGroup = data['isGroup'] == true;
    final canDeleteForEveryone = !isGroup || data['groupAdmin'] == currentUid;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(context.tr('Delete for Me')),
              subtitle: Text(
                context.tr('Removes this chat from your list only'),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDeleteForMe(context, chatId, currentUid);
              },
            ),
            if (canDeleteForEveryone)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(
                  context.tr('Delete for Everyone'),
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: Text(
                  context.tr('Permanently deletes this chat for everyone'),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteForEveryone(context, chatId);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteForMe(
    BuildContext context,
    String chatId,
    String currentUid,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Delete Chat')),
        content: Text(
          context.tr(
            'This removes the chat from your list only. It will come back '
            'if the other side sends a new message.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'deletedFor.$currentUid': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, context.tr('Failed to delete chat: {e}', {'e': e}));
      }
    }
  }

  Future<void> _confirmDeleteForEveryone(
    BuildContext context,
    String chatId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Delete for Everyone')),
        content: Text(
          context.tr(
            'This permanently deletes the entire chat and every message in '
            'it, for everyone. This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.tr('Delete for Everyone'),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _deleteChatForEveryone(chatId);
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, context.tr('Failed to delete chat: {e}', {'e': e}));
      }
    }
  }

  // Firestore batches cap at 500 ops - paginate well under that so a chat
  // with many messages doesn't fail partway through. The parent chat doc is
  // only deleted once every message is gone.
  Future<void> _deleteChatForEveryone(String chatId) async {
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    while (true) {
      final snap = await messagesRef.limit(450).get();
      if (snap.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < 450) break;
    }

    await chatRef.delete();
  }

  Future<void> _logout(BuildContext context) async {
    setUnreadChatBadge(0);
    await unregisterPushToken();
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required String title,
    required Widget avatar,
    required Map<String, dynamic> data,
    required String currentUid,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    // _isVisible() (checked before a chat ever reaches this method) already
    // guarantees lastMessage is set - a chat with none is hidden entirely
    // rather than shown with a placeholder.
    final lastMessage = data['lastMessage'] as String? ?? '';
    final unreadCount = _unreadFor(data, currentUid);
    final isUnread = unreadCount > 0;
    final tick = _buildLastMessageTick(data, currentUid);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: avatar,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        subtitle: Row(
          children: [
            if (tick != null) ...[tick, const SizedBox(width: 4)],
            Expanded(
              child: Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                  color: isUnread
                      ? Theme.of(context).textTheme.bodyLarge?.color
                      : Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(data['lastUpdated']),
              style: TextStyle(
                fontSize: 11,
                color: isUnread
                    ? Colors.green.shade700
                    : Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 6),
            if (isUnread)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 20),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              const SizedBox(height: 20),
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    QueryDocumentSnapshot doc,
    String currentUid,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final isGroup = data['isGroup'] == true;

    if (isGroup) {
      final groupName = data['groupName'] ?? 'Group Chat';

      return _buildTile(
        context,
        title: groupName,
        avatar: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: const Icon(Icons.groups, color: Colors.green),
        ),
        data: data,
        currentUid: currentUid,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: doc.id,
                otherUserName: groupName,
                isGroup: true,
              ),
            ),
          );
        },
        onLongPress: () =>
            _showDeleteOptions(context, doc.id, data, currentUid),
      );
    }

    final participants = List<String>.from(data['participants'] ?? []);
    final otherUid = participants.firstWhere(
      (uid) => uid != currentUid,
      orElse: () => '',
    );

    if (otherUid.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<_OtherUserInfo>(
      future: _getOtherUserInfo(otherUid),
      builder: (context, infoSnapshot) {
        final info = infoSnapshot.data;
        final name = info?.name ?? context.tr('Loading...');

        return _buildTile(
          context,
          title: name,
          avatar: UserAvatar(name: name, role: info?.role),
          data: data,
          currentUid: currentUid,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: doc.id,
                  otherUserName: name,
                  otherUserUid: otherUid,
                ),
              ),
            );
          },
          onLongPress: () =>
              _showDeleteOptions(context, doc.id, data, currentUid),
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    List<QueryDocumentSnapshot> chats,
    String currentUid,
    String emptyMessage,
  ) {
    if (chats.isEmpty) {
      return EmptyState(icon: Icons.chat_bubble_outline, title: emptyMessage);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: chats.length,
      itemBuilder: (context, index) =>
          _buildRow(context, chats[index], currentUid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        body: Center(child: Text(context.tr('Please log in again.'))),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .orderBy('lastUpdated', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final allChats = snapshot.data!.docs
            .where(
              (d) =>
                  _isVisible(d.data() as Map<String, dynamic>, currentUser.uid),
            )
            .toList();
        final individualChats = allChats
            .where((d) => (d.data() as Map)['isGroup'] != true)
            .toList();
        final groupChats = allChats
            .where((d) => (d.data() as Map)['isGroup'] == true)
            .toList();

        final totalUnread = allChats.fold<int>(
          0,
          (total, doc) =>
              total +
              _unreadFor(doc.data() as Map<String, dynamic>, currentUser.uid),
        );

        if (totalUnread != _lastNotifiedUnread) {
          _lastNotifiedUnread = totalUnread;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => setUnreadChatBadge(totalUnread),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('Chats')),
            backgroundColor: widget.appBarColor,
            actions: [
              ...?widget.extraActions,
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => _logout(context),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: widget.appBarColor,
                    unselectedLabelColor: Colors.white,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(text: context.tr('All')),
                      Tab(text: context.tr('Individual')),
                      Tab(text: context.tr('Groups')),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              if (widget.homeHeader != null)
                widget.homeHeader!(
                  context,
                  totalUnread: totalUnread,
                  totalChats: allChats.length,
                  totalGroups: groupChats.length,
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(
                      context,
                      allChats,
                      currentUser.uid,
                      context.tr('No conversations yet.'),
                    ),
                    _buildList(
                      context,
                      individualChats,
                      currentUser.uid,
                      context.tr('No individual chats yet.'),
                    ),
                    _buildList(
                      context,
                      groupChats,
                      currentUser.uid,
                      context.tr('No group chats yet.'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: widget.floatingActionButton,
        );
      },
    );
  }
}
