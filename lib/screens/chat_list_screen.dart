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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/push_notifications.dart';
import '../utils/unread_badge.dart';
import '../widgets/empty_state.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

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

  Future<String> _getOtherUserName(String otherUid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherUid)
        .get();
    if (doc.exists) {
      return doc.data()?['name'] ?? 'User';
    }
    return 'User';
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
  }) {
    final lastMessage = data['lastMessage'] ?? 'Start the conversation...';
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
      );
    }

    final participants = List<String>.from(data['participants'] ?? []);
    final otherUid = participants.firstWhere(
      (uid) => uid != currentUid,
      orElse: () => '',
    );

    if (otherUid.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<String>(
      future: _getOtherUserName(otherUid),
      builder: (context, nameSnapshot) {
        final name = nameSnapshot.data ?? 'Loading...';

        return _buildTile(
          context,
          title: name,
          avatar: CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.blue),
            ),
          ),
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
      return const Scaffold(body: Center(child: Text('Please log in again.')));
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

        final allChats = snapshot.data!.docs;
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
            title: const Text('Chats'),
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
                    tabs: const [
                      Tab(text: 'All'),
                      Tab(text: 'Individual'),
                      Tab(text: 'Groups'),
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
                      'No conversations yet.',
                    ),
                    _buildList(
                      context,
                      individualChats,
                      currentUser.uid,
                      'No individual chats yet.',
                    ),
                    _buildList(
                      context,
                      groupChats,
                      currentUser.uid,
                      'No group chats yet.',
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
