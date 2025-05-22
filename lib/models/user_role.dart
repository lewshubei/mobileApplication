// Define user roles as an enum for type safety
enum UserRole { student, counselor }

// Extension to convert enum to string and back
extension UserRoleExtension on UserRole {
  String get name {
    switch (this) {
      case UserRole.student:
        return 'student';
      case UserRole.counselor:
        return 'counselor';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.counselor:
        return 'Counselor';
    }
  }

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'counselor':
        return UserRole.counselor;
      case 'student':
      default:
        return UserRole.student;
    }
  }
}
