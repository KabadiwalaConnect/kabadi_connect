import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class QuickProfileResult {
  const QuickProfileResult({
    required this.uid,
    required this.profile,
    required this.isAnonymous,
    required this.created,
  });

  final String uid;
  final Map<String, dynamic> profile;
  final bool isAnonymous;
  final bool created;
}

class QuickProfileService {
  static Future<UserCredential>? _anonymousSignIn;
  // Indian contact number only. This does not verify ownership or sign in.
  // Accept 10 digits or +91/91 followed by 10 digits, with common separators.
  static String? normalizeContactMobile(String input) {
    var value = input.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (value.startsWith('+91')) {
      value = value.substring(3);
    } else if (value.length == 12 && value.startsWith('91')) {
      value = value.substring(2);
    }
    return RegExp(r'^[6-9][0-9]{9}$').hasMatch(value) ? '+91$value' : null;
  }

  Future<QuickProfileResult> continueWithName({
    required String name,
    required String mobileNumber,
    required String role,
    required String language,
  }) async {
    final cleanName = name.trim();
    final cleanMobile = normalizeContactMobile(mobileNumber);
    if (cleanMobile == null ||
        cleanName.length < 2 ||
        cleanName.length > 100 ||
        !['collector', 'recycler'].contains(role) ||
        !['en', 'hi', 'mr'].contains(language)) {
      throw ArgumentError('Invalid quick-profile input.');
    }

    final auth = FirebaseAuth.instance;
    // IMPORTANT: preserve existing anonymous AND email accounts.
    // Never sign out an existing account to enter this flow.
    User? user = auth.currentUser;
    if (user == null) {
      final request = _anonymousSignIn ??= auth.signInAnonymously();
      try {
        user = (await request).user;
      } finally {
        if (identical(_anonymousSignIn, request)) {
          _anonymousSignIn = null;
        }
      }
    }
    if (user == null) {
      _blockQuickProfile(
        'auth-returned-no-user',
        'Authentication returned no user.',
      );
    }
    final activeUser = user;
    debugPrintQuick('authenticated; checking own profile');

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(activeUser.uid);
    final outcome = await FirebaseFirestore.instance
        .runTransaction<QuickProfileResult>((transaction) async {
          final snapshot = await transaction.get(ref);
          if (snapshot.exists) {
            final data = snapshot.data()!;
            if (data['name'] is! String ||
                !['collector', 'recycler'].contains(data['role'])) {
              debugPrintQuick(
                'profile-check: nameIsString=${data['name'] is String}; roleSupported=${['collector', 'recycler'].contains(data['role'])}',
              );
              _blockQuickProfile(
                'profile-fields-invalid',
                'Existing profile needs review; not overwriting it.',
              );
            }
            // Preserve all existing fields, including contact details.
            // Registration is not a profile-edit, number lookup or account-switch flow.
            return QuickProfileResult(
              uid: activeUser.uid,
              profile: data,
              isAnonymous: activeUser.isAnonymous,
              created: false,
            );
          }

          final data = <String, dynamic>{
            'name': cleanName,
            'mobileNumber': cleanMobile,
            'mobileVerified': false,
            'role': role,
            'language': language,
            'authorizationStatus': role == 'recycler'
                ? 'pending'
                : 'notApplicable',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (!activeUser.isAnonymous) {
            final email = activeUser.email;
            if (email == null || email.isEmpty) {
              // Never silently convert a legacy phone-only user to a guest.
              _blockQuickProfile(
                'existing-account-email-missing',
                'Existing non-email account needs a migration path.',
              );
            }
            data['email'] = email;
          }
          transaction.set(ref, data);
          return QuickProfileResult(
            uid: activeUser.uid,
            profile: data,
            isAnonymous: activeUser.isAnonymous,
            created: true,
          );
        })
        .timeout(const Duration(seconds: 25));
    // Timeout does not cancel the native operation. Retrying uses the same
    // authenticated UID and does not replace an existing profile.
    debugPrintQuick('profile transaction completed');
    return outcome;
  }
}

// Only status messages; never log names, credentials or tokens.
void debugPrintQuick(String message) {
  debugPrint('KC_QUICK $message');
}

// Stable diagnostic codes only; no profile values, email, UID or tokens.
Never _blockQuickProfile(String code, String message) {
  debugPrintQuick('blocked=$code');
  throw StateError(message);
}
