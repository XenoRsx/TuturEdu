class UserModel {
  final String uid;
  final String email;
  final String role; // 'Teacher', 'Student', or 'Parent'
  final String name;

  // For Teacher: list of classes taught, e.g.: ["Add Maths Form 4", "Physics Form 5"]
  // For Student: list of classes enrolled, e.g.: ["Add Maths Form 4"]
  // For Parent: not used (empty)
  final List<String> subjects;

  // For Student: uid of the linked Parent account (set by Admin, see
  // link_parent_child_screen.dart). Null if not linked yet.
  final String? parentUid;

  // For Parent: uids of the linked Student account(s) - a parent can have
  // more than one child linked (see link_parent_child_screen.dart). Empty
  // if not linked yet.
  final List<String> childUids;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.name,
    this.subjects = const [],
    this.parentUid,
    this.childUids = const [],
  });

  // Converts a Firestore Map into this Dart model object
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'Student',
      name: map['name'] ?? '',
      subjects: List<String>.from(map['subjects'] ?? []),
      parentUid: map['parentUid'] as String?,
      childUids: List<String>.from(map['childUids'] ?? []),
    );
  }

  // Converts this model back into a Firestore-compatible Map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'name': name,
      'subjects': subjects,
      if (parentUid != null) 'parentUid': parentUid,
      if (childUids.isNotEmpty) 'childUids': childUids,
    };
  }
}
