/// TTL helpers for deciding when cached SDK data should be refreshed.
abstract final class SyncPolicy {
  static bool isExpired(DateTime? lastSync, Duration ttl) {
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) >= ttl;
  }
}
