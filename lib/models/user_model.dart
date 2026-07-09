class UserModel {
  final String uid;
  final String email;
  final String role; // 'Lecturer', 'Student', atau 'Parent'
  final String name;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.name,
  });

  // Fungsi untuk tukar data format Map dari Firestore kepada Object Model Dart
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'Student',
      name: map['name'] ?? '',
    );
  }

  // Fungsi kalau kita nak hantar balik data model ni ke format Map Firestore
  Map<String, dynamic> toMap() {
    return {'uid': uid, 'email': email, 'role': role, 'name': name};
  }
}
