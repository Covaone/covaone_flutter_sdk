import 'package:equatable/equatable.dart';

/// A merchant broadcast message fetched from `POST /broadcasts/widget/get`.
class BroadcastModel extends Equatable {
  final String broadcastId;
  final String title;
  final String description;
  final String? image;

  /// `"In-App"` | `"App"` | `"Widget"`.
  final String broadcastCategory;

  final bool isActive;
  final DateTime timeCreated;

  const BroadcastModel({
    required this.broadcastId,
    required this.title,
    required this.description,
    this.image,
    required this.broadcastCategory,
    required this.isActive,
    required this.timeCreated,
  });

  factory BroadcastModel.fromJson(Map<String, dynamic> json) {
    return BroadcastModel(
      broadcastId: json['broadcast_id'] as String? ??
          json['_id'] as String? ??
          '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      image: json['image'] as String?,
      broadcastCategory:
          json['broadcast_category'] as String? ?? 'Widget',
      isActive: json['is_active'] as bool? ?? false,
      timeCreated: _parseDateTime(json['time_created']),
    );
  }

  Map<String, dynamic> toJson() => {
        'broadcast_id': broadcastId,
        'title': title,
        'description': description,
        'image': image,
        'broadcast_category': broadcastCategory,
        'is_active': isActive,
        'time_created': timeCreated.toIso8601String(),
      };

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  @override
  List<Object?> get props =>
      [broadcastId, title, description, image, broadcastCategory, isActive, timeCreated];
}
