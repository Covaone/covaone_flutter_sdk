

abstract class InitializerHandler {
  Future<dynamic> initializer(String firstName, String lastName, String merchantKey, String email, String userRef);
  Future<dynamic> initialize(String publicKey);
  Future<dynamic> getCurrentSession(String publicKey);
}