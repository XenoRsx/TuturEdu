class UserModel {
  final String uid;
  final String email;
  final String role; // 'Teacher', 'Student', atau 'Parent'
  final String name;

  // Untuk Teacher: senarai kelas yang diajar, contoh: ["Add Maths Form 4", "Physics Form 5"]
  // Untuk Student: senarai kelas yang diambil, contoh: ["Add Maths Form 4"]
  // Untuk Parent: tidak digunakan (kosong)
  final List<String> subjects;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.name,
    this.subjects = const [],
  });

  // Fungsi untuk tukar data format Map dari Firestore kepada Object Model Dart
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'Student',
      name: map['name'] ?? '',
      subjects: List<String>.from(map['subjects'] ?? []),
    );
  }

  // Fungsi kalau kita nak hantar balik data model ni ke format Map Firestore
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
