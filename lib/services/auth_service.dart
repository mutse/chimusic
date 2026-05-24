import '../models/music_models.dart';

abstract class AuthService {
  Future<UserProfile?> restoreUser();

  Future<UserProfile> signIn();

  Future<void> signOut();
}

class MockAuthService implements AuthService {
  UserProfile? _currentUser;

  @override
  Future<UserProfile?> restoreUser() async => _currentUser;

  @override
  Future<UserProfile> signIn() async {
    final now = DateTime.now();
    final handle = 'listener${now.millisecondsSinceEpoch.remainder(1000)}';
    final user = UserProfile(
      id: 'chi_$handle',
      name: 'Chi Listener',
      email: '$handle@chimusic.app',
      avatarSeed: handle,
      membershipTier: MembershipTier.free,
      signedInAt: now,
      trialEndsAt: now.add(const Duration(days: 7)),
    );
    _currentUser = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }
}
