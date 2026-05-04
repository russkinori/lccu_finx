// Unit tests for friendlyErrorMessage() and friendlyActionError().
//
// These functions convert technical Supabase / network exceptions into safe,
// user-visible strings. Regressions here silently surface raw Postgres errors
// to end users, so every branch should have at least one test.

import 'package:flutter_test/flutter_test.dart';
import 'package:lccu_finx/core/widgets/friendly_error.dart';

void main() {
  group('friendlyErrorMessage', () {
    const fallback = 'Something went wrong. Please try again.';

    test('returns fallback for null error', () {
      expect(friendlyErrorMessage(null), fallback);
    });

    test('returns fallback for empty string', () {
      expect(friendlyErrorMessage(''), fallback);
    });

    test('schema cache / function-not-found errors', () {
      const msg =
          'friendlyErrorMessage for PGRST202 and schema cache issues';
      expect(
        friendlyErrorMessage('PGRST202'),
        'This feature is not fully set up yet. Please contact support.',
      );
      expect(
        friendlyErrorMessage('could not find the function'),
        'This feature is not fully set up yet. Please contact support.',
      );
      expect(
        friendlyErrorMessage('schema cache'),
        'This feature is not fully set up yet. Please contact support.',
        reason: msg,
      );
    });

    test('timeout / timed out errors', () {
      const expected =
          'The request took too long. Check your connection and try again.';
      expect(friendlyErrorMessage('timeout'), expected);
      expect(friendlyErrorMessage('Operation timed out'), expected);
    });

    test('network / socket errors', () {
      const expected =
          'Unable to connect right now. Check your internet connection and try again.';
      expect(friendlyErrorMessage('SocketException'), expected);
      expect(friendlyErrorMessage('failed host lookup'), expected);
      expect(friendlyErrorMessage('network error'), expected);
      expect(friendlyErrorMessage('connection refused'), expected);
      expect(friendlyErrorMessage('ClientException'), expected);
    });

    test('invalid login credentials', () {
      const expected = 'The email or password is incorrect.';
      expect(friendlyErrorMessage('invalid login credentials'), expected);
      expect(friendlyErrorMessage('Invalid email or password'), expected);
    });

    test('email not confirmed', () {
      expect(
        friendlyErrorMessage('email not confirmed'),
        'Please confirm your email address before signing in.',
      );
    });

    test('JWT / session / token expired / unauthorized', () {
      const expected =
          'Your session has expired. Please sign in again.';
      expect(friendlyErrorMessage('jwt expired'), expected);
      expect(friendlyErrorMessage('session expired'), expected);
      expect(friendlyErrorMessage('token expired'), expected);
      expect(friendlyErrorMessage('unauthorized'), expected);
    });

    test('permission / RLS errors', () {
      const expected =
          'You do not have permission to perform this action.';
      expect(friendlyErrorMessage('permission denied'), expected);
      expect(friendlyErrorMessage('not allowed'), expected);
      expect(friendlyErrorMessage('not authorized'), expected);
      expect(friendlyErrorMessage('row-level security'), expected);
      expect(friendlyErrorMessage('RLS'), expected);
      expect(friendlyErrorMessage('403'), expected);
    });

    test('failed to create auth user', () {
      expect(
        friendlyErrorMessage('failed to create auth user'),
        'Could not create the sign-in account. Please check the email address and try again.',
      );
    });

    test('failed to persist user profile', () {
      expect(
        friendlyErrorMessage('failed to persist user profile'),
        'The user account was created, but the profile could not be saved. '
        'Please check the required fields and try again.',
      );
    });

    test('duplicate key / already exists errors', () {
      const expected = 'A record with these details already exists.';
      expect(friendlyErrorMessage('duplicate key value'), expected);
      expect(friendlyErrorMessage('already registered'), expected);
      expect(friendlyErrorMessage('already exists'), expected);
      expect(friendlyErrorMessage('unique constraint'), expected);
    });

    test('profile not found errors', () {
      const expected =
          'Your profile is not fully set up. Please contact an administrator.';
      expect(friendlyErrorMessage('teacher not found'), expected);
      expect(friendlyErrorMessage('guardian record not found'), expected);
    });

    test('hard delete not allowed', () {
      expect(
        friendlyErrorMessage('hard delete is not allowed'),
        'This user cannot be permanently deleted because related records exist.',
      );
    });

    test('CSV / format errors', () {
      const expected =
          'The file format is invalid. Please use the CSV template and try again.';
      expect(friendlyErrorMessage('format exception'), expected);
      expect(friendlyErrorMessage('invalid csv'), expected);
      expect(friendlyErrorMessage('empty csv'), expected);
      expect(friendlyErrorMessage('missing required field'), expected);
    });

    test('storage / download errors', () {
      const expected = 'The file could not be downloaded. Please try again.';
      expect(friendlyErrorMessage('storage error'), expected);
      expect(friendlyErrorMessage('download failed'), expected);
    });

    test('returns fallback for unrecognised errors', () {
      expect(friendlyErrorMessage('some random technical error xyz'), fallback);
      expect(
        friendlyErrorMessage(
          'something completely unknown',
          fallback: 'Custom fallback.',
        ),
        'Custom fallback.',
      );
    });

    test('custom fallback parameter is used when supplied', () {
      const custom = 'Custom error message.';
      expect(
        friendlyErrorMessage('completely unknown error', fallback: custom),
        custom,
      );
    });
  });

  group('friendlyActionError', () {
    test('prepends action prefix to the friendly message', () {
      final result = friendlyActionError(
        'Failed to load.',
        'invalid login credentials',
      );
      expect(result, startsWith('Failed to load.'));
      expect(result, contains('The email or password is incorrect.'));
    });

    test('includes fallback message when error is unrecognised', () {
      final result = friendlyActionError('Export failed.', 'unknown xyz');
      expect(result, startsWith('Export failed.'));
      expect(result, contains('Something went wrong. Please try again.'));
    });

    test('handles null error gracefully', () {
      final result = friendlyActionError('Operation failed.', null);
      expect(result, startsWith('Operation failed.'));
    });
  });
}
