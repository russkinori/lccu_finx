// app_utils.dart
//
// Common utility functions used throughout the app
// Promotes code reuse and consistency

/// Format a number as currency (e.g., "$1,234.56")
String formatMoney(num value) {
  return '\$${value.toStringAsFixed(2)}';
}

/// Convert strings like 'COLLECTED' or 'pending' to 'Collected'/'Pending'
/// (Title Case)
String titleCase(String s) {
  final trimmed = s.trim();
  if (trimmed.isEmpty) return s;
  return trimmed
      .toLowerCase()
      .split(RegExp(r"\s+"))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

/// Capitalize first letter only (e.g., "hello world" -> "Hello world")
String capitalize(String s) {
  if (s.isEmpty) return s;
  return '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';
}

/// Format date as "MMM d, yyyy" (e.g., "Jan 21, 2026")
String formatDate(DateTime date) {
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Format date as "MMM d" (e.g., "Jan 21")
String formatDateShort(DateTime date) {
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

/// Truncate text with ellipsis if longer than maxLength
String truncate(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...';
}

/// Check if a string is a valid email
bool isValidEmail(String email) {
  return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
}

/// Check if a string is a valid phone number (basic check)
bool isValidPhone(String phone) {
  return RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(phone);
}
