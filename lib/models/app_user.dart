import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role;
  final bool isPresident;
  final String? position;
  final bool active;
  final int stars;
  final DateTime? joinedAt;
  final String? photoUrl;
  final String? phone;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.isPresident,
    required this.stars,
    this.position,
    this.active = true,
    this.joinedAt,
    this.photoUrl,
    this.phone,
  });

  bool get isAdmin => role == 'admin';

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'member',
      isPresident: data['isPresident'] as bool? ?? false,
      position: data['position'] as String?,
      active: data['active'] as bool? ?? true,
      stars: (data['stars'] as num?)?.toInt() ?? 0,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
      photoUrl: data['photoUrl'] as String?,
      phone: data['phone'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'isPresident': isPresident,
      'active': active,
      'stars': stars,
      'joinedAt': joinedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(joinedAt!),
      if (position != null) 'position': position,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (phone != null) 'phone': phone,
    };
  }
}

class AppPosition {
  static const member = 'member';
  static const secretary = 'secretary';
  static const jointSecretary = 'joint_secretary';
  static const treasurer = 'treasurer';
  static const jointTreasurer = 'joint_treasurer';
  static const vicePresident = 'vice_president';
  static const president = 'president';

  static const all = [
    member,
    secretary,
    jointSecretary,
    treasurer,
    jointTreasurer,
    vicePresident,
    president,
  ];

  static String label(String? value) {
    switch (value) {
      case secretary:
        return 'Secretary';
      case jointSecretary:
        return 'Joint Secretary';
      case treasurer:
        return 'Treasurer';
      case jointTreasurer:
        return 'Joint Treasurer';
      case vicePresident:
        return 'Vice President';
      case president:
        return 'President';
      case member:
      default:
        return 'Member';
    }
  }
}
