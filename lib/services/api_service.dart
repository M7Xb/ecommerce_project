import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/review_model.dart';
import '../models/product.dart';

class ApiService {
  static const storage = FlutterSecureStorage();
  static String? _csrfToken;

  static String get baseUrl {
    const localNetworkIP = 'http://192.168.43.216:8000'; // Your PC IP

    if (kIsWeb) {
      return localNetworkIP; // Web also uses IP address now
    } else if (Platform.isAndroid || Platform.isIOS) {
      return localNetworkIP; // Mobile uses IP address
    } else {
      return localNetworkIP; // Desktop also uses IP address
    }
  }

  // Current user ID management
  static String? _currentUserId;

  static void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  static String? getCurrentUserId() {
    return _currentUserId;
  }

  static void logBaseUrl() {
    print('Current API base URL: $baseUrl');
  }

  // Fetch CSRF token from the server
  static Future<String?> fetchCsrfToken() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/csrf-token/'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _csrfToken = data['csrf_token'];
        print('CSRF token fetched: ${_csrfToken?.substring(0, 10)}...');
        return _csrfToken;
      } else {
        print('Failed to fetch CSRF token: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching CSRF token: $e');
      return null;
    }
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    try {
      final token = await _getValidToken();
      Map<String, String> headers = {'Content-Type': 'application/json'};
      
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      // Add CSRF token if available
      if (_csrfToken != null) {
        headers['X-CSRFToken'] = _csrfToken!;
      }
      
      return headers;
    } catch (e) {
      print('Error getting auth headers: $e');
      return {'Content-Type': 'application/json'};
    }
  }

  static Future<http.Response> get(String endpoint) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );
      
      print('GET $endpoint response status: ${response.statusCode}');
      print('GET $endpoint response body: ${response.body}');
      
      return response;
    } catch (e) {
      print('Error in GET request to $endpoint: $e');
      throw Exception('Failed to connect to the server: $e');
    }
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> data) async {
    try {
      // Fetch CSRF token if not already available
      if (_csrfToken == null) {
        await fetchCsrfToken();
      }
      
      final headers = await getAuthHeaders();
      
      print('POST request to $endpoint with data: $data');
      print('Headers: $headers');
      
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      );
      
      print('Response status: ${response.statusCode}');
      if (response.statusCode != 200 && response.statusCode != 201) {
        print('Response body: ${response.body}');
      }
      
      return response;
    } catch (e) {
      print('Error in POST request to $endpoint: $e');
      rethrow;
    }
  }

  static Future<http.Response> delete(String endpoint) async {
    try {
      // Fetch CSRF token if not already available
      if (_csrfToken == null) {
        await fetchCsrfToken();
      }
      
      final headers = await getAuthHeaders();
      
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );
      
      return response;
    } catch (e) {
      print('Error in DELETE request to $endpoint: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getCategories() async {
    try {
      final uri = Uri.parse('$baseUrl/api/categories/');
      final headers = await getAuthHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  static Future<void> logout() async {
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
  }

  static Future<String?> _getValidToken() async {
    try {
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        print('No access token found');
        return null;
      }
      print('Using token: ${token.substring(0, 10)}...'); // Log first 10 chars of token
      return token;
    } catch (e) {
      print('Error retrieving token: $e');
      return null;
    }
  }

  static Future<void> refreshToken() async {
    try {
      final refreshToken = await storage.read(key: 'refresh_token');
      if (refreshToken == null) {
        throw Exception('No refresh token found');
      }

      final uri = Uri.parse('$baseUrl/auth/token/refresh/');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await storage.write(key: 'access_token', value: data['access']);
      } else {
        await logout();
        throw Exception('Session expired. Please login again.');
      }
    } catch (e) {
      await logout();
      throw Exception('Failed to refresh token: $e');
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Login response data: $data'); // Debug log
        
        // Save tokens
        await storage.write(key: 'access_token', value: data['access']);
        await storage.write(key: 'refresh_token', value: data['refresh']);
        
        // Extract user data directly from login response
        Map<String, dynamic> userData = data['user'] ?? {};
        
        // Ensure profile image URL is complete
        if (userData['profile_image'] != null && userData['profile_image'].isNotEmpty) {
          if (!userData['profile_image'].startsWith('http')) {
            userData['profile_image'] = '$baseUrl${userData['profile_image']}';
          }
        }
        
        return {
          'access': data['access'],
          'refresh': data['refresh'],
          'user': userData,
        };
      } else {
        throw Exception('Failed to login: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      print('Attempting to register with: $email, $firstName, $lastName');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'password2': password,
          'first_name': firstName,
          'last_name': lastName,
        }),
      );

      print('Register response status: ${response.statusCode}');
      print('Register response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        await storage.write(key: 'access_token', value: data['access']);
        await storage.write(key: 'refresh_token', value: data['refresh']);
        return data;
      } else if (response.statusCode == 400) {
        // Try to parse the error message
        try {
          final errorData = json.decode(response.body);
          if (errorData.containsKey('email')) {
            // Check if the email error is about it already being registered
            final emailError = errorData['email'];
            if (emailError is List && emailError.isNotEmpty) {
              final errorMsg = emailError[0].toString();
              if (errorMsg.contains('already') || errorMsg.contains('exist')) {
                throw Exception('This email is already registered');
              }
            }
            throw Exception('Email error: ${errorData['email']}');
          } else if (errorData.containsKey('password')) {
            throw Exception('Password error: ${errorData['password']}');
          } else {
            throw Exception('Registration failed: ${response.body}');
          }
        } catch (e) {
          // If the exception was thrown by us, rethrow it
          if (e.toString().contains('This email is already registered')) {
            rethrow;
          }
          throw Exception('Registration failed: Please check your information');
        }
      } else {
        throw Exception('Registration failed with status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Registration error in ApiService: $e');
      // If it's our specific email error, preserve it
      if (e.toString().contains('This email is already registered')) {
        rethrow;
      }
      throw Exception('Registration failed: $e');
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
    String? phone,
    File? imageFile,
    Uint8List? webImageBytes,
    String? imageName,
  }) async {
    try {
      final headers = await getAuthHeaders();
      
      if ((imageFile != null && !kIsWeb) || (webImageBytes != null && kIsWeb)) {
        // Use multipart request for file upload
        var request = http.MultipartRequest(
          'PUT',
          Uri.parse('$baseUrl/auth/profile/update/'),
        );
        
        // Add headers (remove Content-Type as it will be set automatically for multipart)
        headers.remove('Content-Type');
        headers.forEach((key, value) {
          request.headers[key] = value;
        });
        
        // Add text fields
        request.fields['first_name'] = firstName;
        request.fields['last_name'] = lastName;
        if (phone != null) {
          request.fields['phone'] = phone;
        }
        
        // Add file based on platform
        if (kIsWeb && webImageBytes != null) {
          // Web: use bytes
          request.files.add(
            http.MultipartFile.fromBytes(
              'profile_image',
              webImageBytes,
              filename: imageName ?? 'profile_image.jpg',
            ),
          );
        } else if (!kIsWeb && imageFile != null) {
          // Mobile: use file path
          request.files.add(
            await http.MultipartFile.fromPath(
              'profile_image',
              imageFile.path,
            ),
          );
        }
        
        // Send request
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        
        print('Profile update response: ${response.statusCode}'); // Debug log
        print('Profile update body: ${response.body}'); // Debug log
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          Map<String, dynamic> userData = responseData['user'] ?? responseData;
          
          // Ensure profile image URL is complete
          if (userData['profile_image'] != null && userData['profile_image'].isNotEmpty) {
            if (!userData['profile_image'].startsWith('http')) {
              userData['profile_image'] = '$baseUrl${userData['profile_image']}';
            }
          }
          
          return {'user': userData};
        } else {
          throw Exception('Failed to update profile: ${response.statusCode}');
        }
      } else {
        // Use regular PUT request without file
        final response = await http.put(
          Uri.parse('$baseUrl/auth/profile/update/'),
          headers: headers,
          body: json.encode({
            'first_name': firstName,
            'last_name': lastName,
            if (phone != null) 'phone': phone,
          }),
        );

        print('Profile update response: ${response.statusCode}'); // Debug log
        print('Profile update body: ${response.body}'); // Debug log

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          Map<String, dynamic> userData = responseData['user'] ?? responseData;
          
          // Ensure profile image URL is complete
          if (userData['profile_image'] != null && userData['profile_image'].isNotEmpty) {
            if (!userData['profile_image'].startsWith('http')) {
              userData['profile_image'] = '$baseUrl${userData['profile_image']}';
            }
          }
          
          return {'user': userData};
        } else {
          throw Exception('Failed to update profile');
        }
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  static Future<Map<String, dynamic>> updateShippingAddress({
    required String address,
    required String wilaya,
    required String phone,
  }) async {
    try {
      final headers = await getAuthHeaders();
      headers['Content-Type'] = 'application/json';
      
      print('Updating shipping address via API: address=$address, wilaya=$wilaya, phone=$phone');
      
      final response = await http.put(
        Uri.parse('$baseUrl/auth/shipping-address/update/'),
        headers: headers,
        body: json.encode({
          'address': address,
          'wilaya': wilaya,
          'phone': phone,
        }),
      );
      
      print('Shipping address update response: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        Map<String, dynamic> userData = responseData['user'] ?? responseData;
        
        // Ensure profile image URL is complete if it exists
        if (userData['profile_image'] != null && userData['profile_image'].isNotEmpty) {
          if (!userData['profile_image'].startsWith('http')) {
            userData['profile_image'] = '$baseUrl${userData['profile_image']}';
          }
        }
        
        return {'user': userData};
      } else {
        throw Exception('Failed to update shipping address: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response = await get('/api/notifications/');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['notifications'] ?? []);
      } else if (response.statusCode == 404) {
        // If the endpoint doesn't exist, return an empty list instead of throwing an error
        // Only log this message once or during development
        print('Notifications endpoint not found (404) - returning empty list');
        return [];
      } else {
        throw Exception('Failed to load notifications: ${response.statusCode}');
      }
    } catch (e) {
      // Simplified error logging
      print('Error fetching notifications: ${e.toString().split('\n')[0]}');
      return [];
    }
  }

  static Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final headers = await getAuthHeaders();
      print('Marking notification as read: $notificationId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/$notificationId/read/'),
        headers: headers,
      );
      
      print('Mark as read response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        print('Notification marked as read successfully');
        return true;
      } else {
        print('Failed to mark notification as read: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final headers = await getAuthHeaders();
      print('Getting current user');
      
      final response = await http.get(
        Uri.parse('$baseUrl/auth/user/'),
        headers: headers,
      );
      
      print('Get current user response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Current user: ${data.toString()}');
        return data;
      } else {
        print('Failed to get current user: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to get current user');
      }
    } catch (e) {
      print('Error getting current user: $e');
      throw Exception('Failed to connect to the server: $e');
    }
  }

  static Future<bool> createNotification(String title, String message, String? orderId) async {
    try {
      final headers = await getAuthHeaders();
      print('Creating notification: Title: $title, Message: $message, OrderID: $orderId');
      print('Auth headers: $headers');
      
      // Check if the URL is correct
      final url = '$baseUrl/api/notifications/create/';
      print('Notification endpoint URL: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'title': title,
          'message': message,
          'order_id': orderId,
        }),
      );
      
      print('Create notification response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        print('Failed to create notification: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error creating notification: $e');
      return false;
    }
  }

  static Future<List<ReviewModel>> getProductReviews(String productId) async {
    try {
      final headers = await getAuthHeaders();
      final url = Uri.parse('$baseUrl/api/products/$productId/reviews/');
      print('Fetching reviews from: $url');
      
      final response = await http.get(url, headers: headers);
      
      print('Review response status: ${response.statusCode}');
      print('Review response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ReviewModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load reviews: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting reviews: $e');
      rethrow;
    }
  }

  static Future<ReviewModel> createReview(String productId, int rating, String comment) async {
    try {
      final headers = await getAuthHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/products/$productId/reviews/create/'),
        headers: headers,
        body: jsonEncode({
          'rating': rating,
          'comment': comment,
        }),
      );
      
      print('Create review response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 201) {
        return ReviewModel.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create review');
      }
    } catch (e) {
      print('Error creating review: $e');
      rethrow;
    }
  }

  static Future<void> reportReview(String reviewId, String reason) async {
    try {
      final headers = await getAuthHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/reviews/$reviewId/report/'),
        headers: headers,
        body: jsonEncode({
          'reason': reason,
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to report review');
      }
    } catch (e) {
      print('Error reporting review: $e');
      rethrow;
    }
  }

  static Future<void> deleteUserReview(String reviewId) async {
    try {
      final headers = await getAuthHeaders();
      
      // Update the URL to match your Django URL pattern
      final response = await http.delete(
        Uri.parse('$baseUrl/api/reviews/${reviewId}/delete/'),
        headers: headers,
      );
      
      print('Delete review response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode != 200) {
        throw Exception('Failed to delete review: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting review: $e');
      rethrow;
    }
  }

  // Add method to get CSRF token
  static Future<String?> getCsrfToken() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/csrf-token/'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['csrf_token'];
      }
      return null;
    } catch (e) {
      print('Error getting CSRF token: $e');
      return null;
    }
  }

  static Future<Product?> fetchProductById(String productId) async {
    try {
      print('Fetching product with ID: $productId');
      final response = await get('/api/products/$productId/');
      print('Product API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Product data: $data');
        return Product.fromJson(Map<String, dynamic>.from(data));
      } else {
        print('Failed to load product: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching product by ID: $e');
      return null;
    }
  }

  // Wishlist methods
  static Future<List<Product>> getWishlist() async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/wishlist/'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> wishlistData = data['wishlist'];
        return wishlistData.map((item) => Product.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load wishlist');
      }
    } catch (e) {
      print('Error getting wishlist: $e');
      return [];
    }
  }

  static Future<bool> toggleWishlist(String productId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/wishlist/toggle/$productId/'),
        headers: headers,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['status'] == 'added';
      } else {
        throw Exception('Failed to toggle wishlist');
      }
    } catch (e) {
      print('Error toggling wishlist: $e');
      return false;
    }
  }

  static Future<bool> checkWishlist(String productId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/wishlist/check/$productId/'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['in_wishlist'];
      } else {
        return false;
      }
    } catch (e) {
      print('Error checking wishlist: $e');
      return false;
    }
  }

  // clearWishlist method removed

  static Future<bool> updateFCMToken(String token) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/fcm-token/'),
        headers: headers,
        body: jsonEncode({
          'token': token,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating FCM token: $e');
      return false;
    }
  }
}



