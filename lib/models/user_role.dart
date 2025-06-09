// Define user roles as an enum for type safety
enum UserRole { student, counselor, admin }

// Extension to convert enum to string and back
extension UserRoleExtension on UserRole {
  String get name {
    switch (this) {
      case UserRole.student:
        return 'student';
      case UserRole.counselor:
        return 'counselor';
      case UserRole.admin:
        return 'admin';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.counselor:
        return 'Counselor';
      case UserRole.admin:
        return 'Admin';
    }
  }

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'counselor':
        return UserRole.counselor;
      case 'admin':
        return UserRole.admin;
      case 'student':
      default:
        return UserRole.student;
    }
  }
}
