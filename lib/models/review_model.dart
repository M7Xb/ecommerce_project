import '../services/api_service.dart'; // Import ApiService

class ReviewModel {
  final String id;
  final int rating;
  final String comment;
  final String userName;
  final String userId;
  final DateTime createdAt;
  final String? profileImageUrl;

  ReviewModel({
    required this.id,
    required this.rating,
    required this.comment,
    required this.userName,
    required this.userId,
    required this.createdAt,
    this.profileImageUrl,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    // Process profile image URL to ensure it has the base URL
    String? profileImageUrl = json['profile_image_url'];
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      // Check if the URL already has a scheme (http:// or https://)
      if (!profileImageUrl.startsWith('http')) {
        // If not, prepend the base URL
        profileImageUrl = '${ApiService.baseUrl}$profileImageUrl';
      }
    }

    return ReviewModel(
      id: json['id'].toString(),
      rating: json['rating'],
      comment: json['comment'],
      userName: json['user_name'],
      userId: json['user_id'].toString(),
      createdAt: DateTime.parse(json['created_at']),
      profileImageUrl: profileImageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      'comment': comment,
    };
  }
}



