class UserModel {
  final String uid;
  final String email;
  final String role; // 'Teacher', 'Student', or 'Parent'
  final String name;

  // For Teacher: list of classes taught, e.g.: ["Add Maths Form 4", "Physics Form 5"]
  // For Student: list of classes enrolled, e.g.: ["Add Maths Form 4"]
  // For Parent: not used (empty)
  final List<String> subjects;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.name,
    this.subjects = const [],
  });

  // Converts a Firestore Map into this Dart model object
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'Student',
      name: map['name'] ?? '',
      subjects: List<String>.from(map['subjects'] ?? []),
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
    };
  }
}
