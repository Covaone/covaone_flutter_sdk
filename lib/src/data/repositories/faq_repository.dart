import '../models/faq_model.dart';
import '../remote/api_client.dart';

/// Fetches FAQ (frequently asked questions) from the Covaone API.
class FaqRepository {
  final ApiClient _apiClient;

  const FaqRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// Calls `POST /faqs/users/get/all` and returns the FAQ list for the widget.
  Future<List<FaqModel>> getAllFaqs(String sessionId) async {
    final raw = await _apiClient.getAllFaqs(sessionId);

    // The endpoint may return a bare List or a Map containing the list.
    List<dynamic> rawList;
    if (raw is List) {
      rawList = raw;
    } else if (raw is Map<String, dynamic>) {
      rawList = raw['data'] as List<dynamic>? ??
          raw['faqs'] as List<dynamic>? ??
          [];
    } else {
      rawList = [];
    }

    return rawList
        .map((e) => FaqModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
