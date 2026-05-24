import '../models/music_models.dart';

abstract class SubscriptionService {
  Future<UserProfile> upgradeToPro(UserProfile user);

  Future<UserProfile> downgradeToFree(UserProfile user);
}

class MockSubscriptionService implements SubscriptionService {
  @override
  Future<UserProfile> downgradeToFree(UserProfile user) async {
    return user.copyWith(
      membershipTier: MembershipTier.free,
      clearTrialEndsAt: true,
    );
  }

  @override
  Future<UserProfile> upgradeToPro(UserProfile user) async {
    return user.copyWith(
      membershipTier: MembershipTier.pro,
      trialEndsAt: DateTime.now().add(const Duration(days: 14)),
    );
  }
}
