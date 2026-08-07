// lib/screens/chat_screen.dart
//
// The actual chat screen - sends/receives messages in real time via
// Firestore. Chat will LOCK (send button disabled) outside office hours.
//
// Overtime Mode (Teacher only) while chat is locked:
//   - "Reply Now (Overtime Mode)" -> overrides the lock, replies immediately.
//   - "Schedule Reply" -> saves a draft, auto-sends once office hours reopen.
//
// Read receipts (WhatsApp-style):
//   - chats/{chatId}.lastRead: Map<uid, Timestamp> - updated whenever a
//     participant has the chat open, so we know what they've seen.
//   - chats/{chatId}.unreadCount: Map<uid, int> - incremented for every
//     other participant whenever a message is sent, reset to 0 for the
//     current user when they open/read the chat. Powers the unread badge
//     in ChatListScreen.
//   - Each message bubble I sent shows a single tick once it's written to
//     Firestore, and a blue double tick once every other participant's
//     lastRead timestamp is at or after the message's timestamp.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/file_validator.dart';
import '../utils/office_hours.dart';
import 'full_image_screen.dart';
import 'group_info_screen.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final bool isGroup;
  final String? otherUserUid;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    this.isGroup = false,
    this.otherUserUid,
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
  bool _overtimeActive = false; // teacher tapped "Reply Now (Overtime Mode)"

  // ----- Attachment upload state -----
  bool _isUploadingAttachment = false;
  double? _uploadProgress; // null = indeterminate, 0.0-1.0 = known progress

  // ----- Read receipts state -----
  StreamSubscription<DocumentSnapshot>? _chatDocSub;
  StreamSubscription<QuerySnapshot>? _messagesSub;
  List<String> _participants = [];
  Map<String, dynamic> _lastRead = {};

  // Cache of sender name (uid -> name) for group chats, avoids repeated
  // queries for the same bubble on every StreamBuilder rebuild.
  final Map<String, String> _senderNameCache = {};

  Future<String> _getSenderName(String uid) async {
    final cached = _senderNameCache[uid];
    if (cached != null) return cached;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final name = doc.data()?['name'] ?? 'User';
    _senderNameCache[uid] = name;
    return name;
  }

  @override
  void initState() {
    super.initState();
    _isOfficeHour = OfficeHours.isOfficeHourNow();
    _loadCurrentUserRole();

    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId);

    // Read-only: mirrors participants & lastRead into local state so tick
    // marks update live. Never writes back here - writing back would
    // re-trigger this same listener in an infinite loop.
    _chatDocSub = chatRef.snapshots().listen((snap) {
      final data = snap.data();
      if (data == null || !mounted) return;
      setState(() {
        _participants = List<String>.from(data['participants'] ?? []);
        _lastRead = Map<String, dynamic>.from(data['lastRead'] ?? {});
      });
    });

    // Mark read now, and again whenever the messages subcollection changes
    // (i.e. a new message arrives) while this screen stays open.
    _markAsRead();
    _messagesSub = chatRef
        .collection('messages')
        .snapshots()
        .listen((_) => _markAsRead());

    // Check every minute whether office hour status has changed
    // (e.g. user opened the app at 4:59pm, chat should lock at 5:00pm)
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

  Future<void> _markAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
          'lastRead.${currentUser.uid}': FieldValue.serverTimestamp(),
          'unreadCount.${currentUser.uid}': 0,
        });
  }

  /// Participants list for the chat, used to fan out unread counts when
  /// sending a message. Falls back to a one-time fetch if the live chat-doc
  /// listener hasn't delivered its first snapshot yet (e.g. sending the very
  /// first message right after the chat was created).
  Future<List<String>> _resolveParticipants() async {
    if (_participants.isNotEmpty) return _participants;
    final doc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .get();
    return List<String>.from(doc.data()?['participants'] ?? []);
  }

  @override
  void dispose() {
    _officeHourTimer?.cancel();
    _chatDocSub?.cancel();
    _messagesSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Sends the typed message, or [quickReplyText] when tapped from a Quick
  /// Reply chip instead of the text field.
  Future<void> _sendMessage({String? quickReplyText}) async {
    final isQuickReply = quickReplyText != null;
    final text = isQuickReply ? quickReplyText : _messageController.text.trim();
    if (text.isEmpty) return;

    final officeHourNow = OfficeHours.isOfficeHourNow();

    // Outside office hours, a message can only go through if Overtime Mode
    // is active (teacher already tapped "Reply Now (Overtime Mode)").
    if (!officeHourNow && !_overtimeActive) {
      if (mounted) setState(() => _isOfficeHour = false);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (!isQuickReply) _messageController.clear();

    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId);

    final isOvertimeReply = !officeHourNow && _overtimeActive;
    final participants = await _resolveParticipants();

    await chatRef.collection('messages').add({
      'senderId': currentUser.uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      if (isOvertimeReply) 'isOvertimeReply': true,
      if (isQuickReply) 'isQuickReply': true,
    });

    final chatUpdates = <String, dynamic>{
      'lastUpdated': FieldValue.serverTimestamp(),
      'lastMessage': text,
      'lastSenderId': currentUser.uid,
    };
    for (final uid in participants) {
      if (uid == currentUser.uid) continue;
      chatUpdates['unreadCount.$uid'] = FieldValue.increment(1);
    }
    await chatRef.set(chatUpdates, SetOptions(merge: true));
  }

  // ----- File attachment: pick, validate (3 layers - see file_validator.dart),
  // upload to Firebase Storage, then send as a message -----
  Future<void> _pickAndSendAttachment() async {
    final officeHourNow = OfficeHours.isOfficeHourNow();
    if (!officeHourNow && !_overtimeActive) {
      if (mounted) setState(() => _isOfficeHour = false);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null) {
      _showAttachmentError('Could not read the selected file.');
      return;
    }

    final validation = FileValidator.validate(picked.name, bytes);
    if (!validation.isValid) {
      _showAttachmentError(validation.errorMessage!);
      return;
    }

    setState(() {
      _isUploadingAttachment = true;
      _uploadProgress = null;
    });

    StreamSubscription<TaskSnapshot>? progressSub;

    try {
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId);
      // Pre-generate the message ID so the Storage path can embed it, per
      // BLUEPRINT.md 8.7: chats/{chatId}/attachments/{messageId}_{fileName}
      final messageRef = chatRef.collection('messages').doc();
      final storageRef = FirebaseStorage.instance.ref(
        'chats/${widget.chatId}/attachments/${messageRef.id}_${picked.name}',
      );

      final uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(contentType: _contentTypeFor(picked.name)),
      );

      progressSub = uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted || snapshot.totalBytes <= 0) return;
        setState(
          () =>
              _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes,
        );
      });

      // Storage calls can hang indefinitely (rather than fail fast) when the
      // bucket isn't reachable - e.g. Storage not yet enabled for this
      // Firebase project. Time out instead of spinning forever.
      await uploadTask.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          uploadTask.cancel();
          throw TimeoutException(
            'Upload timed out. Firebase Storage may not be enabled for this '
            'project yet - check the Firebase Console.',
          );
        },
      );
      final downloadUrl = await storageRef.getDownloadURL();

      final isOvertimeReply = !officeHourNow && _overtimeActive;
      final attachmentTypeStr =
          validation.attachmentType == AttachmentType.image
          ? 'image'
          : 'document';

      await messageRef.set({
        'senderId': currentUser.uid,
        'text': '',
        'timestamp': FieldValue.serverTimestamp(),
        'attachmentUrl': downloadUrl,
        'attachmentType': attachmentTypeStr,
        'attachmentName': picked.name,
        if (isOvertimeReply) 'isOvertimeReply': true,
      });

      final participants = await _resolveParticipants();
      final chatUpdates = <String, dynamic>{
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastMessage': '📎 ${picked.name}',
        'lastSenderId': currentUser.uid,
      };
      for (final uid in participants) {
        if (uid == currentUser.uid) continue;
        chatUpdates['unreadCount.$uid'] = FieldValue.increment(1);
      }
      await chatRef.set(chatUpdates, SetOptions(merge: true));
    } catch (e) {
      final message = e is TimeoutException
          ? e.message ?? 'Upload timed out.'
          : 'Upload failed: ${e.toString()}';
      _showAttachmentError(message);
    } finally {
      await progressSub?.cancel();
      if (mounted) {
        setState(() {
          _isUploadingAttachment = false;
          _uploadProgress = null;
        });
      }
    }
  }

  void _showAttachmentError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _contentTypeFor(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return null;
    }
  }

  IconData _iconForDocument(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showAttachmentError('Could not open the attachment.');
    }
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
              'This message will be sent automatically once office hours '
              'reopen (${OfficeHours.nextOpenText()}).',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Type the message to schedule...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Schedule'),
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
          content: Text('Reply scheduled for ${OfficeHours.nextOpenText()}.'),
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

  // Once office hours reopen, send every scheduled reply owned by the
  // current user whose time has arrived. Client-side only (a Cloud Function
  // to auto-send even while the app is closed is a future improvement -
  // see BLUEPRINT.md section 5.4).
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

    if (pending.docs.isEmpty) return;

    final now = DateTime.now();
    final participants = await _resolveParticipants();

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

      final chatUpdates = <String, dynamic>{
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastMessage': text,
        'lastSenderId': currentUser.uid,
      };
      for (final uid in participants) {
        if (uid == currentUser.uid) continue;
        chatUpdates['unreadCount.$uid'] = FieldValue.increment(1);
      }
      await chatRef.set(chatUpdates, SetOptions(merge: true));

      await doc.reference.update({'status': 'sent'});
    }
  }

  String _formatTime(dynamic rawTimestamp) {
    if (rawTimestamp is! Timestamp) return '';
    final dt = rawTimestamp.toDate();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Tick mark for a message I sent: a clock while it's still writing to
  /// the server, a single grey tick once sent, a blue double tick once
  /// every other participant has read it (all of them, for group chats).
  Widget _buildTick(dynamic rawTimestamp) {
    if (rawTimestamp is! Timestamp) {
      return const Icon(Icons.access_time, size: 12, color: Colors.white70);
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final otherUids = _participants
        .where((uid) => uid != currentUser?.uid)
        .toList();
    final messageTime = rawTimestamp.toDate();

    final readByAll =
        otherUids.isNotEmpty &&
        otherUids.every((uid) {
          final readTs = _lastRead[uid];
          if (readTs is! Timestamp) return false;
          return !readTs.toDate().isBefore(messageTime);
        });

    return Icon(
      readByAll ? Icons.done_all : Icons.done,
      size: 14,
      color: readByAll ? Colors.lightBlueAccent : Colors.white70,
    );
  }

  /// Renders an attachment inside a message bubble: an inline thumbnail
  /// (tap to open full-screen) for images, or a small file card (tap to
  /// open externally) for documents.
  Widget _buildAttachmentContent(
    String url,
    String? type,
    String name,
    bool isMe,
  ) {
    if (type == 'image') {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FullImageScreen(imageUrl: url)),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                width: 200,
                height: 200,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
            errorBuilder: (context, error, stackTrace) => const SizedBox(
              width: 200,
              height: 200,
              child: Icon(Icons.broken_image_outlined, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openAttachment(url),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconForDocument(name),
              color: isMe ? Colors.white : Colors.blue,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: isMe ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    if (widget.isGroup) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupInfoScreen(chatId: widget.chatId),
        ),
      );
    } else if (widget.otherUserUid != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(uid: widget.otherUserUid!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => _openDetails(context),
          child: Row(
            children: [
              if (widget.isGroup) ...[
                const Icon(Icons.groups, size: 20),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  widget.otherUserName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: widget.isGroup ? 'Group info' : 'View profile',
            onPressed: () => _openDetails(context),
          ),
        ],
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
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation!'),
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
                    final senderId = data['senderId'] ?? '';
                    final rawTimestamp = data['timestamp'];
                    final attachmentUrl = data['attachmentUrl'] as String?;
                    final attachmentType = data['attachmentType'] as String?;
                    final attachmentName =
                        data['attachmentName'] as String? ?? 'Attachment';

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
                            if (widget.isGroup && !isMe && senderId.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: FutureBuilder<String>(
                                  future: _getSenderName(senderId),
                                  builder: (context, senderSnapshot) => Text(
                                    senderSnapshot.data ?? '...',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ),
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
                            if (attachmentUrl != null)
                              _buildAttachmentContent(
                                attachmentUrl,
                                attachmentType,
                                attachmentName,
                                isMe,
                              )
                            else
                              Text(
                                text,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTime(rawTimestamp),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.black45,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    _buildTick(rawTimestamp),
                                  ],
                                ],
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
          _buildQuickReplyChips(),
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
                      ? 'Overtime Mode active — your message will be marked as an after-hours reply.'
                      : 'Chat is closed outside office hours (${OfficeHours.officeHourText()}). '
                            'Reopens: ${OfficeHours.nextOpenText()}.',
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

  /// List of scheduled replies still pending for this chat (teacher only).
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
                        'Scheduled $timeText: "$text"',
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

  static const List<String> _quickReplies = [
    'OK',
    'Yes',
    'No',
    'Thank you',
    'Noted',
    'Please wait',
  ];

  /// Row of quick-reply chips above the input bar - tapping one sends it
  /// immediately as a message (tagged `isQuickReply: true`).
  Widget _buildQuickReplyChips() {
    final canType = _isOfficeHour || _overtimeActive;
    if (!canType) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _quickReplies.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final reply = _quickReplies[index];
          return ActionChip(
            label: Text(reply, style: const TextStyle(fontSize: 12.5)),
            backgroundColor: Colors.blue.shade50,
            side: BorderSide(color: Colors.blue.shade100),
            onPressed: () => _sendMessage(quickReplyText: reply),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    final canType = _isOfficeHour || _overtimeActive;
    final canAttach = canType && !_isUploadingAttachment;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            _isUploadingAttachment
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: _uploadProgress,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.attach_file),
                    tooltip:
                        'Send a file (PDF, Word, PowerPoint, Excel, image)',
                    color: canAttach ? Colors.blue : Colors.grey,
                    onPressed: canAttach ? _pickAndSendAttachment : null,
                  ),
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: canType,
                decoration: InputDecoration(
                  hintText: canType
                      ? (_overtimeActive
                            ? 'Type a message (Overtime Mode)...'
                            : 'Type a message...')
                      : 'Chat is currently locked',
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
