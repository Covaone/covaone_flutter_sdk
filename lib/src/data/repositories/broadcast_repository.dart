import '../models/broadcast_model.dart';
import '../remote/api_client.dart';

/// Fetches and caches broadcast (announcement) data from the Covaone API.
class BroadcastRepository {
  final ApiClient _apiClient;

  const BroadcastRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// Calls `POST /broadcasts/widget/get` and returns all active broadcasts
  /// targeted at the widget channel.
  Future<List<BroadcastModel>> getBroadcasts(String sessionId) async {
    final data = await _apiClient.getBroadcasts(sessionId);

    // The API may return a bare JSON array or a wrapped object.
    List<dynamic> rawList;
    if (data is List<dynamic>) {
      rawList = data;
    } else if (data is Map<String, dynamic>) {
      rawList = data['data'] as List<dynamic>? ??
          data['broadcasts'] as List<dynamic>? ??
          [];
    } else {
      rawList = [];
    }

    return rawList
        .map((e) => BroadcastModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Calls `POST /broadcast/get` for a single broadcast by ID.
  Future<BroadcastModel> getSingleBroadcast(String broadcastId) async {
    final data = await _apiClient.getSingleBroadcast(broadcastId);

    final raw = data['data'] as Map<String, dynamic>? ?? data;
    return BroadcastModel.fromJson(raw);
  }
}
