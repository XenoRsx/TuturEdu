// lib/screens/chat_screen.dart
//
// Screen chat sebenar - hantar/terima mesej real-time guna Firestore.
// Chat akan LOCK (send button disabled) kalau outside office hour.

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

  @override
  void initState() {
    super.initState();
    _isOfficeHour = OfficeHours.isOfficeHourNow();

    // Check setiap minit sama ada office hour dah tukar status
    // (contoh: user buka app kat 4:59pm, chat sepatutnya lock bila jam 5:00pm)
    _officeHourTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final nowStatus = OfficeHours.isOfficeHourNow();
      if (nowStatus != _isOfficeHour && mounted) {
        setState(() => _isOfficeHour = nowStatus);
      }
    });
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

    // Double-check office hour semasa hantar (elak race condition
    // kalau user tekan send tepat masa jam bertukar)
    if (!OfficeHours.isOfficeHourNow()) {
      setState(() => _isOfficeHour = false);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _messageController.clear();

    final chatRef =
        FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

    await chatRef.collection('messages').add({
      'senderId': currentUser.uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await chatRef.set({
      'lastUpdated': FieldValue.serverTimestamp(),
      'lastMessage': text,
    }, SetOptions(merge: true));
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
                    final data =
                        messages[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == currentUserUid;
                    final text = data['text'] ?? '';

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                        child: Text(
                          text,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                          ),
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
      child: Row(
        children: [
          const Icon(Icons.lock_clock, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Chat ditutup di luar waktu pejabat (${OfficeHours.officeHourText()}). '
              'Dibuka semula: ${OfficeHours.nextOpenText()}.',
              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: _isOfficeHour,
                decoration: InputDecoration(
                  hintText: _isOfficeHour
                      ? 'Taip mesej...'
                      : 'Chat dikunci buat masa ini',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onSubmitted: (_) => _isOfficeHour ? _sendMessage() : null,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.send),
              color: _isOfficeHour ? Colors.blue : Colors.grey,
              onPressed: _isOfficeHour ? _sendMessage : null,
            ),
          ],
        ),
      ),
    );
  }
}
