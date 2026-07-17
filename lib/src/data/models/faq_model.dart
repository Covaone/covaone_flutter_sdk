import 'package:equatable/equatable.dart';

/// A single FAQ entry from `POST /faqs/users/get/all`.
class FaqModel extends Equatable {
  final String faqId;
  final String title;
  final String description;
  final String? image;

  const FaqModel({
    required this.faqId,
    required this.title,
    required this.description,
    this.image,
  });

  factory FaqModel.fromJson(Map<String, dynamic> json) {
    return FaqModel(
      faqId: json['faq_id'] as String? ?? json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      image: json['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'faq_id': faqId,
        'title': title,
        'description': description,
        'image': image,
      };

  @override
  List<Object?> get props => [faqId, title, description, image];
}
