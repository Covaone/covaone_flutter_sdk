import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'message_model.dart';

/// Outcome of a completed WebRTC call session.
///
/// This is separate from [CallStatus] (the Bloc UI-phase enum) which tracks
/// the live state of an in-progress call.
enum CallOutcome {
  completed,
  missed,
  rejected,
  failed;

  static CallOutcome fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'completed':
        return CallOutcome.completed;
      case 'missed':
        return CallOutcome.missed;
      case 'rejected':
        return CallOutcome.rejected;
      case 'failed':
        return CallOutcome.failed;
      default:
        return CallOutcome.failed;
    }
  }
}

/// Call metadata embedded inside a [MessageModel] whose
/// [MessageModel.messageType] == [MessageType.CALL].
/// The [MessageModel.message] field carries the JSON payload.
class CallLogModel extends Equatable {
  final String callId;
  final CallOutcome status;

  /// `"inbound"` (agent called customer) or `"outbound"` (customer initiated).
  final String direction;
  final int durationSeconds;
  final String? summary;

  const CallLogModel({
    required this.callId,
    required this.status,
    required this.direction,
    required this.durationSeconds,
    this.summary,
  });

  factory CallLogModel.fromJson(Map<String, dynamic> json) {
    return CallLogModel(
      callId: json['call_id'] as String? ?? '',
      status: CallOutcome.fromString(json['status'] as String?),
      direction: json['direction'] as String? ?? 'inbound',
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      summary: json['summary'] as String?,
    );
  }

  /// Parses a [CallLogModel] from the JSON payload inside a CALL [MessageModel].
  factory CallLogModel.fromMessage(MessageModel message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      return CallLogModel.fromJson(data);
    } catch (_) {
      return CallLogModel(
        callId: message.messageId,
        status: CallOutcome.failed,
        direction: 'inbound',
        durationSeconds: 0,
        summary: null,
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'call_id': callId,
        'status': status.name,
        'direction': direction,
        'duration_seconds': durationSeconds,
        'summary': summary,
      };

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props =>
      [callId, status, direction, durationSeconds, summary];
}
