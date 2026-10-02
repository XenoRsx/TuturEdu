// lib/screens/chat_screen.dart
//
// The actual chat screen - sends/receives messages in real time via
// Firestore. Chat will LOCK (send button disabled) outside office hours -
// see _computeIsOfficeHour(), which also folds in the chat's teacher's
// manual On-Duty/Off-Duty status (BLUEPRINT.md 5.10) and Leave/Holiday date
// range set from Settings (BLUEPRINT.md 5.14): a teacher going Off-Duty, or
// currently within their leave dates, locks the chat the same way as being
// outside office hours would, even during the scheduled window.
// `_relevantTeacherUid` is whichever participant is the Teacher (self, for
// a Teacher viewing their own chat; otherUserUid/groupAdmin, for a
// Student/Parent viewing a chat with one) - its dutyStatus/leaveStart/
// leaveEnd are watched live so the lock updates immediately if the teacher
// toggles or a leave period starts/ends while this screen is open.
//
// While chat is locked:
//   - "Reply Now (Overtime Mode)" (Teacher only) -> overrides the lock,
//     replies immediately, marked isOvertimeReply.
//   - "Schedule Reply"/"Schedule Message" (every role) -> saves a draft to
//     chats/{chatId}/scheduledReplies, auto-sent once the chat reopens (see
//     BLUEPRINT.md 5.4). The whole pipeline - rules, dialog, storage,
//     auto-send, pending-list UI - is keyed by senderId only, no role
//     check, so Student/Parent get the exact same mechanism as Teacher;
//     only the "Reply Now" bypass stays Teacher-only, since that one is
//     specifically about a teacher choosing to break their own hours.
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
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_strings.dart';
import '../utils/file_validator.dart';
import '../utils/office_hours.dart';
import '../utils/phishing_detector.dart';
import '../utils/presence.dart';
import '../widgets/app_card.dart';
import '../utils/role_colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/message_bubble.dart';
import 'full_image_screen.dart';
import 'group_info_screen.dart';
import 'user_profile_screen.dart';

class _SenderInfo {
  final String name;
  final String? role;

  const _SenderInfo(this.name, this.role);
}

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

  // ----- Delete Message state (see BLUEPRINT.md 5.16) -----
  bool _isAdmin = false;
  static const _deleteWindow = Duration(minutes: 15);

  // ----- On-Duty/Off-Duty state (see file header + BLUEPRINT.md 5.10) -----
  String? _relevantTeacherUid;
  String? _groupAdminUid;
  bool _teacherOffDuty = false;
  StreamSubscription<DocumentSnapshot>? _teacherDutySub;

  // ----- Leave/Holiday state (Settings screen, see BLUEPRINT.md 5.14) -----
  DateTime? _teacherLeaveStart;
  DateTime? _teacherLeaveEnd;

  // ----- Attachment upload state -----
  bool _isUploadingAttachment = false;
  double? _uploadProgress; // null = indeterminate, 0.0-1.0 = known progress

  // ----- Read receipts state -----
  StreamSubscription<DocumentSnapshot>? _chatDocSub;
  StreamSubscription<QuerySnapshot>? _messagesSub;
  List<String> _participants = [];
  Map<String, dynamic> _lastRead = {};

  // ----- Typing indicator + online status (see BLUEPRINT.md 5.23) -----
  // Each participant writes `chats/{id}.typing.{uid}` (throttled) while
  // composing. "Fresh" is judged by when THIS device received the ping
  // (_typingSeenAt), not by the server timestamp itself - so a phone with a
  // wrong clock on either end can't make "typing..." stick or never show.
  static const _typingFresh = Duration(seconds: 5);
  static const _typingThrottle = Duration(seconds: 3);
  final Map<String, DateTime> _typingSeenAt = {};
  Map<String, dynamic> _typingRaw = {};
  DateTime? _lastTypingWrite;
  Timer? _statusTicker;
  String? _statusLine;
  String? _otherUid;
  DateTime? _otherLastSeen;
  StreamSubscription<DocumentSnapshot>? _otherUserSub;

  // ----- Search messages (see BLUEPRINT.md 5.24) -----
  bool _searching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Cache of sender info (uid -> _SenderInfo) for group chats, avoids
  // repeated queries for the same bubble on every StreamBuilder rebuild.
  // Widened from name-only to also carry role, so the sender-name label can
  // be colored per role (roleColor()) instead of one fixed color for
  // everyone.
  final Map<String, _SenderInfo> _senderInfoCache = {};

  Future<_SenderInfo> _getSenderInfo(String uid) async {
    final cached = _senderInfoCache[uid];
    if (cached != null) return cached;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data();
    final info = _SenderInfo(data?['name'] ?? 'User', data?['role'] as String?);
    _senderInfoCache[uid] = info;
    return info;
  }

  // "Chat open" = automatic office-hour schedule AND the relevant teacher
  // hasn't manually gone Off-Duty AND isn't on leave. See file header,
  // BLUEPRINT.md 5.10 (duty toggle) and 5.14 (leave dates).
  bool _computeIsOfficeHour() =>
      OfficeHours.isOfficeHourNow() && !_teacherOffDuty && !_isTeacherOnLeave;

  bool get _isTeacherOnLeave {
    final start = _teacherLeaveStart;
    final end = _teacherLeaveEnd;
    if (start == null || end == null) return false;
    final now = DateTime.now();
    return !now.isBefore(start) && !now.isAfter(end);
  }

  @override
  void initState() {
    super.initState();
    _isOfficeHour = _computeIsOfficeHour();
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
        _updateTyping(Map<String, dynamic>.from(data['typing'] ?? {}));
        _statusLine = _computeStatusLine();
      });
      if (!widget.isGroup) {
        final me = FirebaseAuth.instance.currentUser?.uid;
        final other =
            widget.otherUserUid ??
            _participants.where((uid) => uid != me).firstOrNull;
        if (other != null) _watchOtherUser(other);
      }
      if (widget.isGroup) {
        final groupAdmin = data['groupAdmin'] as String?;
        if (groupAdmin != null && groupAdmin != _groupAdminUid) {
          _groupAdminUid = groupAdmin;
          _watchTeacherDutyStatus(groupAdmin);
        }
      }
    });

    // Mark read now, and again whenever the messages subcollection changes
    // (i.e. a new message arrives) while this screen stays open.
    _markAsRead();
    _messagesSub = chatRef
        .collection('messages')
        .snapshots()
        .listen((_) => _markAsRead());

    // Typing pings expire and "Online" turns into "Last seen" purely with
    // the passage of time (no new snapshot arrives), so re-check once a
    // second - setState only when the visible line actually changes.
    _statusTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final line = _computeStatusLine();
      if (line != _statusLine && mounted) setState(() => _statusLine = line);
    });

    // Check every minute whether office hour status has changed
    // (e.g. user opened the app at 4:59pm, chat should lock at 5:00pm)
    _officeHourTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final nowStatus = _computeIsOfficeHour();
      if (nowStatus != _isOfficeHour && mounted) {
        setState(() {
          _isOfficeHour = nowStatus;
          if (nowStatus) _overtimeActive = false;
        });
      }
      if (nowStatus) _autoSendDueScheduledReplies();
    });
  }

  // Watches the given teacher's dutyStatus live, so the lock updates
  // immediately if they toggle On-Duty/Off-Duty while this screen is open.
  void _watchTeacherDutyStatus(String teacherUid) {
    if (_relevantTeacherUid == teacherUid) return;
    _relevantTeacherUid = teacherUid;
    _teacherDutySub?.cancel();
    _teacherDutySub = FirebaseFirestore.instance
        .collection('users')
        .doc(teacherUid)
        .snapshots()
        .listen((doc) {
          if (!mounted) return;
          final data = doc.data();
          final offDuty = data?['dutyStatus'] == 'off_duty';
          final leaveStart = (data?['leaveStart'] as Timestamp?)?.toDate();
          final leaveEnd = (data?['leaveEnd'] as Timestamp?)?.toDate();
          if (offDuty == _teacherOffDuty &&
              leaveStart == _teacherLeaveStart &&
              leaveEnd == _teacherLeaveEnd) {
            return;
          }
          setState(() {
            _teacherOffDuty = offDuty;
            _teacherLeaveStart = leaveStart;
            _teacherLeaveEnd = leaveEnd;
            _isOfficeHour = _computeIsOfficeHour();
            if (_isOfficeHour) _overtimeActive = false;
          });
          if (_isOfficeHour) _autoSendDueScheduledReplies();
        });
  }

  // Called inside the chat-doc listener's setState.
  void _updateTyping(Map<String, dynamic> typing) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final now = DateTime.now();
    for (final entry in typing.entries) {
      final value = entry.value;
      if (entry.key == me || value is! Timestamp) continue;
      if (_typingRaw[entry.key] == value) continue;
      // Leftover ping from someone who closed the app mid-typing (dispose
      // never got to clear it) - coarse 1-minute check, tolerant of skew.
      if (now.difference(value.toDate()).abs() > const Duration(minutes: 1)) {
        continue;
      }
      _typingSeenAt[entry.key] = now;
      if (widget.isGroup && !_senderInfoCache.containsKey(entry.key)) {
        _getSenderInfo(entry.key).then((_) {
          if (mounted) setState(() => _statusLine = _computeStatusLine());
        });
      }
    }
    _typingSeenAt.removeWhere((uid, _) => typing[uid] is! Timestamp);
    _typingRaw = typing;
  }

  /// AppBar subtitle: who's typing, else (1:1 only) Online / Last seen.
  String? _computeStatusLine() {
    final now = DateTime.now();
    final typingUids = _typingSeenAt.entries
        .where((e) => now.difference(e.value) < _typingFresh)
        .map((e) => e.key)
        .toList();
    if (typingUids.isNotEmpty) {
      if (!widget.isGroup) return context.tr('typing...');
      if (typingUids.length > 1) {
        return context.tr('{n} people are typing...', {'n': typingUids.length});
      }
      final name =
          _senderInfoCache[typingUids.first]?.name ?? context.tr('Someone');
      return context.tr('{name} is typing...', {'name': name});
    }
    if (widget.isGroup) return null;
    final presence = context.trDays(
      Presence.describe(_otherLastSeen)
          .replaceFirst('Online', context.tr('Online'))
          .replaceFirst('Last seen', context.tr('Last seen')),
    );
    return presence.isEmpty ? null : presence;
  }

  void _watchOtherUser(String uid) {
    if (_otherUid == uid) return;
    _otherUid = uid;
    _otherUserSub?.cancel();
    _otherUserSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
          if (!mounted) return;
          setState(() {
            _otherLastSeen = (doc.data()?['lastSeen'] as Timestamp?)?.toDate();
            _statusLine = _computeStatusLine();
          });
        });
  }

  // Throttled: at most one write per _typingThrottle while typing. Never
  // touches lastUpdated, so chat-list order and push triggers don't move.
  void _onComposeChanged(String value) {
    if (value.trim().isEmpty) {
      _clearTyping();
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final now = DateTime.now();
    final last = _lastTypingWrite;
    if (last != null && now.difference(last) < _typingThrottle) return;
    _lastTypingWrite = now;
    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'typing.$uid': FieldValue.serverTimestamp(),
    }).ignore();
  }

  void _clearTyping() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _lastTypingWrite == null) return;
    _lastTypingWrite = null;
    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'typing.$uid': FieldValue.delete(),
    }).ignore();
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (data['deleted'] == true) return false;
    final query = _searchQuery.toLowerCase();
    final text = (data['text'] as String? ?? '').toLowerCase();
    final file = (data['attachmentName'] as String? ?? '').toLowerCase();
    return text.contains(query) || file.contains(query);
  }

  Future<void> _loadCurrentUserRole() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final role = doc.data()?['role'] ?? '';
    final isTeacher = role == 'Teacher';
    if (mounted) {
      setState(() {
        _isTeacher = isTeacher;
        _isAdmin = role == 'Admin';
      });
    }

    // Group chats resolve their teacher (groupAdmin) from the chat-doc
    // listener in initState instead - see _chatDocSub.
    if (!widget.isGroup) {
      final teacherUid = isTeacher ? currentUser.uid : widget.otherUserUid;
      if (teacherUid != null) _watchTeacherDutyStatus(teacherUid);
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
    _statusTicker?.cancel();
    _otherUserSub?.cancel();
    _clearTyping();
    _searchController.dispose();
    _chatDocSub?.cancel();
    _messagesSub?.cancel();
    _teacherDutySub?.cancel();
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

    final officeHourNow = _computeIsOfficeHour();

    // Outside office hours (or the teacher is manually Off-Duty), a message
    // can only go through if Overtime Mode is active (teacher already
    // tapped "Reply Now (Overtime Mode)").
    if (!officeHourNow && !_overtimeActive) {
      if (mounted) setState(() => _isOfficeHour = false);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (!isQuickReply) {
      _messageController.clear();
      _clearTyping();
    }

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
    final officeHourNow = _computeIsOfficeHour();
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
      if (!mounted) return;
      _showAttachmentError(context.tr('Could not read the selected file.'));
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

      // Web's resumable-upload protocol occasionally fires its first
      // request with a stale/expiring ID token, failing with `unauthorized`
      // even though the user genuinely is signed in (see CLAUDE.md's
      // storage.rules notes - confirmed via DevTools: the preflight
      // succeeds but the actual XHR comes back 403). A plain delay-and-
      // retry reuses the SAME cached token and can keep failing, so force
      // a real token refresh (getIdToken(true)) before each retry - that's
      // what actually clears the stale-token condition. Not retried for
      // other error codes; those are real failures.
      const maxUploadAttempts = 3;
      for (var attempt = 1; attempt <= maxUploadAttempts; attempt++) {
        if (attempt > 1) {
          await currentUser.getIdToken(true);
        }
        final uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(contentType: _contentTypeFor(picked.name)),
        );

        progressSub = uploadTask.snapshotEvents.listen((snapshot) {
          if (!mounted || snapshot.totalBytes <= 0) return;
          setState(
            () => _uploadProgress =
                snapshot.bytesTransferred / snapshot.totalBytes,
          );
        });

        try {
          // Storage calls can hang indefinitely (rather than fail fast)
          // when the bucket isn't reachable - e.g. Storage not yet
          // enabled for this Firebase project. Time out instead of
          // spinning forever.
          await uploadTask.timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              uploadTask.cancel();
              throw TimeoutException(
                context.tr(
                  'Upload timed out. Firebase Storage may not be enabled '
                  'for this project yet - check the Firebase Console.',
                ),
              );
            },
          );
          break;
        } on FirebaseException catch (e) {
          if (e.code != 'unauthorized' || attempt == maxUploadAttempts) {
            rethrow;
          }
          await progressSub.cancel();
          await Future.delayed(const Duration(milliseconds: 700));
        }
      }
      // getDownloadURL() is a plain (non-resumable) GET, but it's still
      // subject to this rule's allow-read clause, which cross-checks the
      // chat's Firestore participants - and that firestore.get() lookup can
      // fail to resolve in time immediately after a resumable upload
      // session finishes, for the same class of reason documented on
      // storage.rules' write clause. Give it the same refresh-and-retry
      // treatment rather than assuming a plain GET is immune.
      late final String downloadUrl;
      for (var attempt = 1; attempt <= maxUploadAttempts; attempt++) {
        if (attempt > 1) {
          await currentUser.getIdToken(true);
          await Future.delayed(const Duration(milliseconds: 700));
        }
        try {
          downloadUrl = await storageRef.getDownloadURL();
          break;
        } on FirebaseException catch (e) {
          if (e.code != 'unauthorized' || attempt == maxUploadAttempts) {
            rethrow;
          }
        }
      }

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
      if (!mounted) return;
      final message = e is TimeoutException
          ? e.message ?? context.tr('Upload timed out.')
          : context.tr('Upload failed: {e}', {'e': e});
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(context.tr('Attachment Error')),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
      if (!mounted) return;
      _showAttachmentError(context.tr('Could not open the attachment.'));
    }
  }

  // ----- URL phishing detection (heuristic, client-side - see
  // lib/utils/phishing_detector.dart and BLUEPRINT.md section 11) -----

  /// Renders message [text] as plain text with any detected URLs turned
  /// into tappable spans - blue/underlined if [isSuspiciousUrl] finds
  /// nothing unusual, red with a warning icon (and a confirm-before-open
  /// dialog) if it does.
  Widget _buildMessageText(String text, bool isMe) {
    final baseColor = isMe
        ? Colors.white
        : Theme.of(context).textTheme.bodyLarge?.color;
    final matches = urlPattern.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(text, style: TextStyle(color: baseColor));
    }

    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }

      final rawUrl = match.group(0)!;
      final suspicious = isSuspiciousUrl(rawUrl);

      if (suspicious) {
        spans.add(
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(right: 2),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: Colors.redAccent,
              ),
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: rawUrl,
          style: TextStyle(
            color: suspicious
                ? Colors.redAccent
                : (isMe ? Colors.lightBlueAccent.shade100 : Colors.blue),
            decoration: TextDecoration.underline,
            fontWeight: suspicious ? FontWeight.bold : FontWeight.normal,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => suspicious
                ? _confirmSuspiciousLink(rawUrl)
                : _launchChatLink(rawUrl),
        ),
      );

      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(color: baseColor),
        children: spans,
      ),
    );
  }

  Future<void> _launchChatLink(String rawUrl) async {
    final uri = Uri.tryParse(normalizeUrl(rawUrl));
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _showAttachmentError(context.tr('Could not open the link.'));
    }
  }

  Future<void> _confirmSuspiciousLink(String rawUrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(context.tr('Suspicious link')),
          ],
        ),
        content: Text(
          context.tr(
            'This link looks like it could be a phishing attempt:\n\n{url}\n\n'
            'Only open it if you trust where it came from.',
            {'url': rawUrl},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.tr('Open Anyway'),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) await _launchChatLink(rawUrl);
  }

  // ----- Delete Message (soft-delete, see BLUEPRINT.md 5.16) -----
  // The sender can delete their own message within _deleteWindow of sending
  // it; an Admin can delete any message, any time (moderation). Messages
  // are otherwise create-only (firestore.rules) - this is the one narrow
  // exception, restricted server-side to flipping `deleted`/`deletedAt`
  // only, never the original content.
  bool _canDeleteMessage(Map<String, dynamic> data, bool isMe) {
    if (data['deleted'] == true) return false;
    if (_isAdmin) return true;
    if (!isMe) return false;
    final rawTimestamp = data['timestamp'];
    if (rawTimestamp is! Timestamp) return false;
    return DateTime.now().difference(rawTimestamp.toDate()) < _deleteWindow;
  }

  Future<void> _confirmDeleteMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Delete Message')),
        content: Text(
          context.tr(
            'Delete this message for everyone in the chat? This cannot be '
            'undone.',
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
              context.tr('Delete'),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId)
        .update({'deleted': true, 'deletedAt': FieldValue.serverTimestamp()});
  }

  // ----- Report Message (BLUEPRINT.md 5.22) -----
  // Anyone can report someone ELSE's message (not their own, not one that's
  // already deleted). Reviewed by Admin in flagged_messages_screen.dart.
  bool _canReportMessage(Map<String, dynamic> data, bool isMe) =>
      !isMe && data['deleted'] != true;

  void _showMessageActions(
    String messageId,
    Map<String, dynamic> data,
    bool isMe,
  ) {
    final canDelete = _canDeleteMessage(data, isMe);
    final canReport = _canReportMessage(data, isMe);

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
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  context.tr('Delete Message'),
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteMessage(messageId);
                },
              ),
            if (canReport)
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                title: Text(context.tr('Report Message')),
                subtitle: Text(
                  context.tr('Send this message to an Admin to review'),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _reportMessage(messageId, data);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _reportReasonLabel(String reason) {
    switch (reason) {
      case 'Bullying or harassment':
        return context.tr('Bullying or harassment');
      case 'Inappropriate content':
        return context.tr('Inappropriate content');
      case 'Spam or scam':
        return context.tr('Spam or scam');
      default:
        return context.tr('Other');
    }
  }

  static const _reportReasons = [
    'Bullying or harassment',
    'Inappropriate content',
    'Spam or scam',
    'Other',
  ];

  Future<void> _reportMessage(
    String messageId,
    Map<String, dynamic> data,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    var reason = _reportReasons.first;
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.tr('Report Message')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('Why are you reporting this message?')),
                RadioGroup<String>(
                  groupValue: reason,
                  onChanged: (value) {
                    if (value != null) setDialogState(() => reason = value);
                  },
                  child: Column(
                    children: _reportReasons
                        .map(
                          (r) => RadioListTile<String>(
                            value: r,
                            // Stored in English (Admin reads it); shown
                            // translated.
                            title: Text(_reportReasonLabel(r)),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
                  ),
                ),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(
                    labelText: context.tr('More details (optional)'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('Cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                context.tr('Report'),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true) return;

    try {
      // Deterministic ID - one report per person per message. Reporting the
      // same message twice hits the existing doc, which rules treat as an
      // update (Admin-only) and deny.
      await FirebaseFirestore.instance
          .collection('reports')
          .doc('${messageId}_${currentUser.uid}')
          .set({
            'chatId': widget.chatId,
            'messageId': messageId,
            // Snapshot - Admin can't read `messages` directly (rules are
            // participants-only), so the report has to carry the content.
            'messageText': data['text'] ?? '',
            'attachmentName': data['attachmentName'],
            'reportedUid': data['senderId'],
            'reportedBy': currentUser.uid,
            'reason': reason,
            'note': note,
            'status': 'open',
            'createdAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      _showReportResult(
        context.tr('Thanks - an Admin will review this message.'),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showReportResult(
        e.code == 'permission-denied'
            ? context.tr('You\'ve already reported this message.')
            : context.tr('Could not send report: {e}', {'e': e.message}),
      );
    }
  }

  void _showReportResult(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ----- Overtime Mode: "Reply Now (Overtime Mode)" -----
  void _activateOvertimeReplyNow() {
    setState(() => _overtimeActive = true);
  }

  // ----- "Schedule Reply"/"Schedule Message" - available to every role,
  // unlike "Reply Now (Overtime)" which only makes sense for a Teacher
  // choosing to break their own office hours. -----
  Future<void> _openScheduleReplyDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _isTeacher
              ? context.tr('Schedule Reply')
              : context.tr('Schedule Message'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(
                'This message will be sent automatically once office hours '
                'reopen ({when}).',
                {'when': context.trDays(OfficeHours.nextOpenText())},
              ),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: context.tr('Type the message to schedule...'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.tr('Schedule')),
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
            context.tr('Reply scheduled for {when}.', {
              'when': context.trDays(OfficeHours.nextOpenText()),
            }),
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
          color: isMe
              ? Colors.white.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                  color: isMe
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyLarge?.color,
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
        leading: _searching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: context.tr('Close search'),
                onPressed: _closeSearch,
              )
            : null,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: context.tr('Search messages...'),
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim()),
              )
            : InkWell(
                onTap: () => _openDetails(context),
                child: Row(
                  children: [
                    if (widget.isGroup) ...[
                      const Icon(Icons.groups, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.otherUserName,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_statusLine != null)
                            Text(
                              _statusLine!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        backgroundColor: Colors.blue,
        actions: _searching
            ? [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: context.tr('Clear'),
                    onPressed: () => setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                    }),
                  ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: context.tr('Search messages'),
                  onPressed: () => setState(() => _searching = true),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: widget.isGroup
                      ? context.tr('Group info')
                      : context.tr('View profile'),
                  onPressed: () => _openDetails(context),
                ),
              ],
      ),
      body: Column(
        children: [
          if (!_isOfficeHour) _buildLockedBanner(),
          _buildScheduledRepliesList(),
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

                final allMessages = snapshot.data!.docs;

                if (allMessages.isEmpty) {
                  return EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: context.tr('No messages yet'),
                    subtitle: context.tr('Start the conversation!'),
                  );
                }

                // Client-side search - Firestore has no full-text search,
                // and this stream already holds the whole conversation.
                final isFiltering = _searching && _searchQuery.isNotEmpty;
                final messages = isFiltering
                    ? allMessages
                          .where(
                            (doc) => _matchesSearch(
                              doc.data() as Map<String, dynamic>,
                            ),
                          )
                          .toList()
                    : allMessages;

                if (isFiltering && messages.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: context.tr('No matching messages'),
                    subtitle: context.tr(
                      'Nothing in this chat matches "{q}".',
                      {'q': _searchQuery},
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageDoc = messages[index];
                    final data = messageDoc.data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == currentUserUid;
                    final isDeleted = data['deleted'] == true;
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
                      child: GestureDetector(
                        onLongPress:
                            _canDeleteMessage(data, isMe) ||
                                _canReportMessage(data, isMe)
                            ? () =>
                                  _showMessageActions(messageDoc.id, data, isMe)
                            : null,
                        child: MessageBubble(
                          isMe: isMe,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.isGroup &&
                                  !isMe &&
                                  senderId.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: FutureBuilder<_SenderInfo>(
                                    future: _getSenderInfo(senderId),
                                    builder: (context, senderSnapshot) => Text(
                                      senderSnapshot.data?.name ?? '...',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: roleColor(
                                          senderSnapshot.data?.role,
                                        ),
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
                                            ? context.tr('Overtime')
                                            : context.tr('Scheduled'),
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
                              if (isDeleted)
                                Text(
                                  context.tr('This message was deleted'),
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: isMe
                                        ? Colors.white70
                                        : Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color,
                                  ),
                                )
                              else if (attachmentUrl != null)
                                _buildAttachmentContent(
                                  attachmentUrl,
                                  attachmentType,
                                  attachmentName,
                                  isMe,
                                )
                              else
                                _buildMessageText(text, isMe),
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
                                            : Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.color,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: AppCard(
        color: Colors.orange.shade100,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _overtimeActive
                      ? Icons.bolt
                      : (_isTeacherOnLeave
                            ? Icons.beach_access_outlined
                            : (_teacherOffDuty
                                  ? Icons.work_off_outlined
                                  : Icons.lock_clock)),
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _overtimeActive
                        ? context.tr(
                            'Overtime Mode active — your message will be '
                            'marked as an after-hours reply.',
                          )
                        : _isTeacherOnLeave
                        ? context.tr(
                            'This teacher is on leave until {date}. Chat will '
                            'reopen after that.',
                            {
                              'date':
                                  '${_teacherLeaveEnd!.day.toString().padLeft(2, '0')}/'
                                  '${_teacherLeaveEnd!.month.toString().padLeft(2, '0')}/'
                                  '${_teacherLeaveEnd!.year}',
                            },
                          )
                        : _teacherOffDuty
                        ? context.tr(
                            'This teacher is currently Off-Duty. Chat will '
                            'reopen once they go back On-Duty.',
                          )
                        : context.tr(
                            'Chat is closed outside office hours ({hours}). '
                            'Reopens: {when}.',
                            {
                              'hours': context.trDays(
                                OfficeHours.officeHourText(),
                              ),
                              'when': context.trDays(
                                OfficeHours.nextOpenText(),
                              ),
                            },
                          ),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            if (!_overtimeActive) ...[
              const SizedBox(height: 10),
              if (_isTeacher)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _activateOvertimeReplyNow,
                        icon: const Icon(Icons.bolt, size: 16),
                        label: Text(
                          context.tr('Reply Now (Overtime)'),
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
                        label: Text(
                          context.tr('Schedule Reply'),
                          style: TextStyle(fontSize: 12.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openScheduleReplyDialog,
                    icon: const Icon(Icons.schedule_send, size: 16),
                    label: Text(
                      context.tr('Schedule Message'),
                      style: TextStyle(fontSize: 12.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// List of scheduled replies/messages still pending for this chat, owned
  /// by the current user (any role - query is keyed by senderId).
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

        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: AppCard(
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
                          context.tr('Scheduled {time}: "{text}"', {
                            'time': timeText,
                            'text': text,
                          }),
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
          ),
        );
      },
    );
  }

  // Sent in the sender's own app language - a chip tapped in Malay sends
  // the Malay text.
  List<String> _quickReplies(BuildContext context) => [
    context.tr('OK'),
    context.tr('Yes'),
    context.tr('No'),
    context.tr('Thank you'),
    context.tr('Noted'),
    context.tr('Please wait'),
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
        itemCount: _quickReplies(context).length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final reply = _quickReplies(context)[index];
          final chipColor = Theme.of(context).colorScheme.primary;
          return ActionChip(
            label: Text(
              reply,
              style: TextStyle(fontSize: 12.5, color: chipColor),
            ),
            backgroundColor: chipColor.withValues(alpha: 0.1),
            side: BorderSide(color: chipColor.withValues(alpha: 0.3)),
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
                    tooltip: context.tr(
                      'Send a file (PDF, Word, PowerPoint, Excel, image)',
                    ),
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
                            ? context.tr('Type a message (Overtime Mode)...')
                            : context.tr('Type a message...'))
                      : context.tr('Chat is currently locked'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                onChanged: _onComposeChanged,
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
