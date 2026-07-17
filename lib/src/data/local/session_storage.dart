import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../models/broadcast_model.dart';
import '../models/configuration_model.dart';
import '../models/message_model.dart';
import '../models/session_model.dart';

/// Thin SharedPreferences wrapper that persists session state across app
/// restarts. All methods are idempotent and handle corrupt data gracefully.
class SessionStorage {
  // ── Session ID ────────────────────────────────────────────────────────────

  Future<String?> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(CovaoneConstants.sessionIdKey);
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<void> saveSessionId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CovaoneConstants.sessionIdKey, id);
  }

  Future<void> clearSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CovaoneConstants.sessionIdKey);
  }

  // ── Email ─────────────────────────────────────────────────────────────────

  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(CovaoneConstants.emailKey);
    return (email == null || email.isEmpty) ? null : email;
  }

  Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CovaoneConstants.emailKey, email);
  }

  // ── Configuration ─────────────────────────────────────────────────────────

  Future<ConfigurationModel?> getCachedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CovaoneConstants.configKey);
    if (raw == null) return null;
    try {
      return ConfigurationModel.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConfig(ConfigurationModel config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        CovaoneConstants.configKey, jsonEncode(config.toJson()));
  }

  // ── Session cache ─────────────────────────────────────────────────────────

  Future<void> saveCachedSession(SessionModel session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      CovaoneConstants.sessionCacheKey,
      jsonEncode(session.toJson()),
    );
  }

  Future<SessionModel?> getCachedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CovaoneConstants.sessionCacheKey);
    if (raw == null) return null;
    try {
      return SessionModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSessionSyncAt(DateTime syncedAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      CovaoneConstants.sessionSyncAtKey,
      syncedAt.toIso8601String(),
    );
  }

  Future<DateTime?> getSessionSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CovaoneConstants.sessionSyncAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> clearSessionCache() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(CovaoneConstants.sessionCacheKey),
      prefs.remove(CovaoneConstants.sessionSyncAtKey),
    ]);
  }

  // ── Broadcast cache ───────────────────────────────────────────────────────

  Future<void> saveCachedBroadcasts(List<BroadcastModel> broadcasts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      CovaoneConstants.broadcastCacheKey,
      jsonEncode(broadcasts.map((b) => b.toJson()).toList()),
    );
  }

  Future<List<BroadcastModel>?> getCachedBroadcasts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CovaoneConstants.broadcastCacheKey);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => BroadcastModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBroadcastSyncAt(DateTime syncedAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      CovaoneConstants.broadcastSyncAtKey,
      syncedAt.toIso8601String(),
    );
  }

  Future<DateTime?> getBroadcastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CovaoneConstants.broadcastSyncAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> clearBroadcastCache() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(CovaoneConstants.broadcastCacheKey),
      prefs.remove(CovaoneConstants.broadcastSyncAtKey),
    ]);
  }

  // ── Viewed broadcasts ─────────────────────────────────────────────────────
  //
  // Storage format (mirrors the JS SDK):
  // { "status": "viewed", "list": { "0": "<id>", "1": "<id>" }, "name": "" }

  Future<Set<String>> getViewedBroadcastIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CovaoneConstants.broadcastViewedKey);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = map['list'] as Map<String, dynamic>?;
      if (list == null) return {};
      return list.values.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> markBroadcastViewed(String broadcastId) async {
    final existing = await getViewedBroadcastIds();
    existing.add(broadcastId);

    final indexedList = <String, String>{};
    final ids = existing.toList();
    for (var i = 0; i < ids.length; i++) {
      indexedList['$i'] = ids[i];
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      CovaoneConstants.broadcastViewedKey,
      jsonEncode({'status': 'viewed', 'list': indexedList, 'name': ''}),
    );
  }

  // ── Chat open tracking ────────────────────────────────────────────────────

  Future<void> saveLastChatOpenedAt(DateTime openedAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      CovaoneConstants.lastChatOpenedAtKey,
      openedAt.toIso8601String(),
    );
  }

  Future<DateTime?> getLastChatOpenedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CovaoneConstants.lastChatOpenedAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> saveLastMessageAlertClearedAt(DateTime clearedAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      CovaoneConstants.lastMessageAlertClearedAtKey,
      clearedAt.toIso8601String(),
    );
  }

  Future<DateTime?> getLastMessageAlertClearedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CovaoneConstants.lastMessageAlertClearedAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  // ── Pending message alerts ────────────────────────────────────────────────

  Future<void> savePendingMessageAlerts(List<MessageModel> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    if (alerts.isEmpty) {
      await prefs.remove(CovaoneConstants.pendingMessageAlertsKey);
      return;
    }
    await prefs.setString(
      CovaoneConstants.pendingMessageAlertsKey,
      jsonEncode(alerts.map((m) => m.toJson()).toList()),
    );
  }

  Future<List<MessageModel>> getPendingMessageAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CovaoneConstants.pendingMessageAlertsKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Message IDs the user swiped away one-by-one from the sticky alert stack.
  Future<void> saveDismissedMessageAlertIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    if (ids.isEmpty) {
      await prefs.remove(CovaoneConstants.dismissedMessageAlertIdsKey);
      return;
    }
    await prefs.setStringList(
      CovaoneConstants.dismissedMessageAlertIdsKey,
      ids.toList(growable: false),
    );
  }

  Future<Set<String>> getDismissedMessageAlertIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list =
        prefs.getStringList(CovaoneConstants.dismissedMessageAlertIdsKey);
    if (list == null || list.isEmpty) return {};
    return list.toSet();
  }

  /// Appends [message] into the cached session history (if a cache exists).
  Future<void> appendMessageToCachedSession(MessageModel message) async {
    final cached = await getCachedSession();
    if (cached == null) return;
    if (cached.messages.any((m) => m.messageId == message.messageId)) return;
    final updated = cached.copyWith(
      messages: [...cached.messages, message],
    );
    await saveCachedSession(updated);
  }

  // ── Wipe ──────────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(CovaoneConstants.sessionIdKey),
      prefs.remove(CovaoneConstants.emailKey),
      prefs.remove(CovaoneConstants.configKey),
      prefs.remove(CovaoneConstants.sessionCacheKey),
      prefs.remove(CovaoneConstants.sessionSyncAtKey),
      prefs.remove(CovaoneConstants.broadcastCacheKey),
      prefs.remove(CovaoneConstants.broadcastSyncAtKey),
      prefs.remove(CovaoneConstants.broadcastViewedKey),
      prefs.remove(CovaoneConstants.lastChatOpenedAtKey),
      prefs.remove(CovaoneConstants.lastMessageAlertClearedAtKey),
      prefs.remove(CovaoneConstants.pendingMessageAlertsKey),
      prefs.remove(CovaoneConstants.dismissedMessageAlertIdsKey),
    ]);
  }
}
