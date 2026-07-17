import 'package:equatable/equatable.dart';

/// Brand / support configuration returned by the Covaone API inside every
/// session response (`configuration` key).
class ConfigurationModel extends Equatable {
  /// Display name of the support team (e.g. "Ola Bimbo").
  /// Used to derive [initials] shown in the chat header.
  final String supportName;

  /// Hex colour string for SDK theming (e.g. "#592C83").
  final String color;

  /// Contact email address of the merchant's support account.
  final String contactEmail;

  const ConfigurationModel({
    required this.supportName,
    required this.color,
    required this.contactEmail,
  });

  /// Derives two-letter initials from [supportName] by taking the first
  /// character of each whitespace-delimited word, uppercased.
  /// "Ola Bimbo" → "OB", "Support" → "S".
  String get initials {
    final parts = supportName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    return parts.map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
  }

  factory ConfigurationModel.fromJson(Map<String, dynamic> json) {
    return ConfigurationModel(
      supportName: json['support_name'] as String? ??
          json['config_name'] as String? ??
          '',
      color: json['color'] as String? ?? '#592C83',
      contactEmail: json['contact_email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'support_name': supportName,
        'color': color,
        'contact_email': contactEmail,
      };

  ConfigurationModel copyWith({
    String? supportName,
    String? color,
    String? contactEmail,
  }) =>
      ConfigurationModel(
        supportName: supportName ?? this.supportName,
        color: color ?? this.color,
        contactEmail: contactEmail ?? this.contactEmail,
      );

  @override
  List<Object?> get props => [supportName, color, contactEmail];
}
