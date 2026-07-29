// lib/screens/chat_screen.dart
//
// Screen chat sebenar - hantar/terima mesej real-time guna Firestore.
// Chat akan LOCK (send button disabled) kalau outside office hour.
//
// Overtime Mode (khusus Teacher) bila chat locked:
//   - "Reply Now (Overtime Mode)" -> override lock, terus reply.
//   - "Schedule Reply" -> simpan draft, auto-hantar bila office hour buka.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/office_hours.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late bool _isOfficeHour;
  Timer? _officeHourTimer;

  // ----- Overtime Mode state -----
  bool _isTeacher = false;
  bool _overtimeActive = false; // teacher tekan "Reply Now (Overtime Mode)"

  @override
  void initState() {
    super.initState();
    _isOfficeHour = OfficeHours.isOfficeHourNow();
    _loadCurrentUserRole();

    // Check setiap minit sama ada office hour dah tukar status
    // (contoh: user buka app kat 4:59pm, chat sepatutnya lock bila jam 5:00pm)
    _officeHourTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final nowStatus = OfficeHours.isOfficeHourNow();
      if (nowStatus != _isOfficeHour && mounted) {
        setState(() {
          _isOfficeHour = nowStatus;
          if (nowStatus) _overtimeActive = false;
        });
      }
      if (nowStatus) _autoSendDueScheduledReplies();
    });
  }

  Future<void> _loadCurrentUserRole() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final role = doc.data()?['role'] ?? '';
    if (mounted) {
      setState(() => _isTeacher = role == 'Teacher');
    }
    if (_isOfficeHour) _autoSendDueScheduledReplies();
  }

  @override
  void dispose() {
    _officeHourTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final officeHourNow = OfficeHours.isOfficeHourNow();

    // Kalau bukan office hour, mesej hanya boleh lepas kalau Overtime Mode
    // aktif (teacher dah tekan "Reply Now (Overtime Mode)").
    if (!officeHourNow && !_overtimeActive) {
      if (mounted) setState(() => _isOfficeHour = false);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _messageController.clear();

    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId);

    final isOvertimeReply = !officeHourNow && _overtimeActive;

    await chatRef.collection('messages').add({
      'senderId': currentUser.uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      if (isOvertimeReply) 'isOvertimeReply': true,
    });

    await chatRef.set({
      'lastUpdated': FieldValue.serverTimestamp(),
      'lastMessage': text,
    }, SetOptions(merge: true));
  }

  // ----- Overtime Mode: "Reply Now (Overtime Mode)" -----
  void _activateOvertimeReplyNow() {
    setState(() => _overtimeActive = true);
  }

  // ----- Overtime Mode: "Schedule Reply" -----
  Future<void> _openScheduleReplyDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Reply'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mesej ni akan auto-hantar bila office hour buka semula '
              '(${OfficeHours.nextOpenText()}).',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Taip mesej untuk dijadualkan...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Jadualkan'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    await _saveScheduledReply(result);
  }

  Future<void> _saveScheduledReply(String text) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final scheduledFor = OfficeHours.nextOpenDateTime();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('scheduledReplies')
        .add({
          'senderId': currentUser.uid,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
          'scheduledFor': Timestamp.fromDate(scheduledFor),
          'status': 'pending',
        });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reply dijadualkan untuk ${OfficeHours.nextOpenText()}.',
          ),
        ),
      );
    }
  }

  Future<void> _cancelScheduledReply(String replyId) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('scheduledReplies')
        .doc(replyId)
        .delete();
  }

  // Bila office hour dah buka semula, hantar semua scheduled reply milik
  // current user yang masanya dah tiba. Client-side sahaja (Cloud Function
  // untuk auto-hantar walaupun app tertutup adalah penambahbaikan masa
  // depan - rujuk BLUEPRINT.md seksyen 5.4).
  Future<void> _autoSendDueScheduledReplies() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId);

    final pending = await chatRef
        .collection('scheduledReplies')
        .where('senderId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    final now = DateTime.now();

    for (final doc in pending.docs) {
      final data = doc.data();
      final scheduledFor = (data['scheduledFor'] as Timestamp?)?.toDate();
      if (scheduledFor == null || scheduledFor.isAfter(now)) continue;

      final text = data['text'] ?? '';
      if (text.isEmpty) continue;

      await chatRef.collection('messages').add({
        'senderId': currentUser.uid,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isScheduledReply': true,
      });

      await chatRef.set({
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastMessage': text,
      }, SetOptions(merge: true));

      await doc.reference.update({'status': 'sent'});
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          if (!_isOfficeHour) _buildLockedBanner(),
          if (_isTeacher) _buildScheduledRepliesList(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ralat: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Belum ada mesej. Mula chat sekarang!'),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == currentUserUid;
                    final text = data['text'] ?? '';
                    final isOvertimeReply = data['isOvertimeReply'] == true;
                    final isScheduledReply = data['isScheduledReply'] == true;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOvertimeReply || isScheduledReply)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isOvertimeReply
                                          ? Icons.bolt
                                          : Icons.schedule_send,
                                      size: 12,
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isOvertimeReply
                                          ? 'Overtime'
                                          : 'Scheduled',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              text,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildLockedBanner() {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _overtimeActive ? Icons.bolt : Icons.lock_clock,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _overtimeActive
                      ? 'Overtime Mode aktif — mesej anda akan ditanda sebagai balasan luar waktu pejabat.'
                      : 'Chat ditutup di luar waktu pejabat (${OfficeHours.officeHourText()}). '
                            'Dibuka semula: ${OfficeHours.nextOpenText()}.',
                  style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                ),
              ),
            ],
          ),
          if (_isTeacher && !_overtimeActive) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _activateOvertimeReplyNow,
                    icon: const Icon(Icons.bolt, size: 16),
                    label: const Text(
                      'Reply Now (Overtime)',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange,
                      side: const BorderSide(color: Colors.deepOrange),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openScheduleReplyDialog,
                    icon: const Icon(Icons.schedule_send, size: 16),
                    label: const Text(
                      'Schedule Reply',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Senarai scheduled reply yang masih pending untuk chat ni (teacher sahaja).
  Widget _buildScheduledRepliesList() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('scheduledReplies')
          .where('senderId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;

        return Container(
          width: double.infinity,
          color: Colors.blue.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final text = data['text'] ?? '';
              final scheduledFor = (data['scheduledFor'] as Timestamp?)
                  ?.toDate();
              final timeText = scheduledFor != null
                  ? '${scheduledFor.hour.toString().padLeft(2, '0')}:${scheduledFor.minute.toString().padLeft(2, '0')}'
                  : '';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_send,
                      size: 16,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Dijadualkan $timeText: "$text"',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => _cancelScheduledReply(doc.id),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    final canType = _isOfficeHour || _overtimeActive;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: canType,
                decoration: InputDecoration(
                  hintText: canType
                      ? (_overtimeActive
                            ? 'Taip mesej (Overtime Mode)...'
                            : 'Taip mesej...')
                      : 'Chat dikunci buat masa ini',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                onSubmitted: (_) => canType ? _sendMessage() : null,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.send),
              color: canType ? Colors.blue : Colors.grey,
              onPressed: canType ? _sendMessage : null,
            ),
          ],
        ),
      ),
    );
  }
}
