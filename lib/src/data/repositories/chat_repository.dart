import 'dart:convert';
import 'dart:io';

import '../local/session_storage.dart';
import '../models/session_model.dart';
import '../remote/api_client.dart';

/// Handles session lifecycle and file upload operations.
class ChatRepository {
  final ApiClient _apiClient;
  final SessionStorage _sessionStorage;

  const ChatRepository({
    required ApiClient apiClient,
    required SessionStorage sessionStorage,
  })  : _apiClient = apiClient,
        _sessionStorage = sessionStorage;

  // ── Session ───────────────────────────────────────────────────────────────

  /// Calls `POST /initiate-session` and returns the newly created session ID.
  Future<String> initiateSession(String publicKey) async {
    final data = await _apiClient.initiateSession(publicKey);
    final sessionId = data['session_id'] as String?;
    if (sessionId == null || sessionId.isEmpty) {
      throw Exception('initiate-session returned no session_id');
    }
    return sessionId;
  }

  /// Calls `POST /get-single-session` and returns a fully-hydrated [SessionModel].
  Future<SessionModel> getSession(String sessionId) async {
    final data = await _apiClient.getSingleSession(sessionId);
    final session = SessionModel.fromJson(data);
    await _persistSession(session);
    return session;
  }

  /// Calls `POST /set-profile` and returns the updated [SessionModel].
  Future<SessionModel> setProfile({
    required String sessionId,
    required String email,
    required String name,
  }) async {
    await _apiClient.setProfile(
      sessionId: sessionId,
      email: email,
      name: name,
    );
    // Re-fetch the session to return the canonical state.
    return getSession(sessionId);
  }

  Future<void> _persistSession(SessionModel session) async {
    await _sessionStorage.saveSessionId(session.sessionId);
    await _sessionStorage.saveCachedSession(session);
    await _sessionStorage.saveSessionSyncAt(DateTime.now());
    await _sessionStorage.saveConfig(session.configuration);
    final email = session.email?.trim();
    if (email != null && email.isNotEmpty) {
      await _sessionStorage.saveEmail(email);
    }
  }

  // ── File upload ───────────────────────────────────────────────────────────

  /// Reads [filePath] from disk, base64-encodes it, and posts it to
  /// `POST /file-upload`. Returns the server response payload.
  Future<Map<String, dynamic>> uploadFile({
    required String conversationId,
    required String filePath,
    required String filename,
    String message = '',
    String messageType = 'QUERY',
    String origin = 'frontend',
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final base64File = base64Encode(bytes);

    return _apiClient.uploadFile(
      conversationId: conversationId,
      origin: origin,
      message: message,
      messageType: messageType,
      fileBase64: base64File,
      filename: filename,
    );
  }

  /// Uploads already-base64-encoded file content. Used by [ChatBloc] when the
  /// UI layer picks a file via [file_picker] and encodes the bytes itself.
  Future<Map<String, dynamic>> uploadFileFromBase64({
    required String conversationId,
    required String filename,
    required String base64Content,
    String messageType = 'QUERY',
    String origin = 'frontend',
  }) async {
    return _apiClient.uploadFile(
      conversationId: conversationId,
      origin: origin,
      message: filename,
      messageType: messageType,
      fileBase64: base64Content,
      filename: filename,
    );
  }
}
