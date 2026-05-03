/// Converts technical exceptions from Supabase, networking, auth and parsing
/// into short messages that are safe to show to end users.
String friendlyErrorMessage(
  Object? error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error == null) return fallback;

  final raw = error.toString().trim();
  if (raw.isEmpty) return fallback;
  final lower = raw.toLowerCase();

  if (lower.contains('pgrst202') ||
      lower.contains('could not find the function') ||
      lower.contains('schema cache')) {
    return 'This feature is not fully set up yet. Please contact support.';
  }

  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'The request took too long. Check your connection and try again.';
  }

  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network') ||
      lower.contains('connection refused') ||
      lower.contains('clientexception')) {
    return 'Unable to connect right now. Check your internet connection and try again.';
  }

  if (lower.contains('invalid login credentials') ||
      lower.contains('invalid email or password')) {
    return 'The email or password is incorrect.';
  }

  if (lower.contains('email not confirmed')) {
    return 'Please confirm your email address before signing in.';
  }

  if (lower.contains('jwt') ||
      lower.contains('session') ||
      lower.contains('token expired') ||
      lower.contains('unauthorized')) {
    return 'Your session has expired. Please sign in again.';
  }

  if (lower.contains('permission') ||
      lower.contains('not allowed') ||
      lower.contains('not authorized') ||
      lower.contains('admin access required') ||
      lower.contains('row-level security') ||
      lower.contains('rls') ||
      lower.contains('403')) {
    return 'You do not have permission to perform this action.';
  }

  if (lower.contains('edge function') && lower.contains('admin access required')) {
    return 'You do not have permission to perform this action.';
  }

  if (lower.contains('failed to create auth user')) {
    return 'Could not create the sign-in account. Please check the email address and try again.';
  }

  if (lower.contains('failed to persist user profile')) {
    return 'The user account was created, but the profile could not be saved. Please check the required fields and try again.';
  }

  if (lower.contains('duplicate key') ||
      lower.contains('already registered') ||
      lower.contains('already exists') ||
      lower.contains('unique constraint')) {
    return 'A record with these details already exists.';
  }

  if (lower.contains('teacher not found') ||
      lower.contains('guardian record not found') ||
      lower.contains('principal') && lower.contains('not found') ||
      lower.contains('profile') && lower.contains('not found')) {
    return 'Your profile is not fully set up. Please contact an administrator.';
  }

  if (lower.contains('hard delete is not allowed')) {
    return 'This user cannot be permanently deleted because related records exist.';
  }

  if (lower.contains('format exception') ||
      lower.contains('invalid csv') ||
      lower.contains('empty csv') ||
      lower.contains('missing required')) {
    return 'The file format is invalid. Please use the CSV template and try again.';
  }

  if (lower.contains('storage') || lower.contains('download')) {
    return 'The file could not be downloaded. Please try again.';
  }

  return fallback;
}

String friendlyActionError(String action, Object? error) {
  return '$action ${friendlyErrorMessage(error)}';
}
