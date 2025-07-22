import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';  // Add this import for File class
import 'dart:typed_data'; // Add this import for Uint8List
import '../services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import './orders_provider.dart';
import './notifications_provider.dart';
import './cart_provider.dart';
import '../services/api_service.dart';


class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userData;
  final _storage = const FlutterSecureStorage();
  BuildContext? _context;
  OrdersProvider? _ordersProvider;

  AuthProvider() {
 
  }

  void setContext(BuildContext context) {
    _context = context;
    try {
      _ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    } catch (e) {
      print('Error getting OrdersProvider: $e');
    }
  }

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get userData => _userData;

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      // Check if we have a valid token
      final token = await _storage.read(key: 'access_token');
      if (token == null) {
        print('No token available for getUserData');
        return _userData;
      }
      
      print('Using token: ${token.substring(0, 10)}...');
      
      // Try to get user profile from backend
      try {
        final response = await ApiService.get('/auth/user-profile/');
        print('GET /auth/user-profile/ response status: ${response.statusCode}');
        print('GET /auth/user-profile/ response body: ${response.body}');
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          Map<String, dynamic> userData = responseData['user'] ?? responseData;
          
          // Debug log shipping address data
          print('Address from profile: ${userData['address']}');
          print('Wilaya from profile: ${userData['wilaya']}');
          print('Phone from profile: ${userData['phone']}');
          
          // Ensure profile image URL is complete
          if (userData['profile_image'] != null && userData['profile_image'].isNotEmpty) {
            if (!userData['profile_image'].startsWith('http')) {
              userData['profile_image'] = '${ApiService.baseUrl}${userData['profile_image']}';
            }
          }
          
          _userData = userData;
          notifyListeners();
          return _userData;
        }
      } catch (e) {
        print('Error fetching user profile: $e');
      }
      
      // Try alternative endpoint
      try {
        final response = await ApiService.get('/auth/profile/');
        print('GET /auth/profile/ response status: ${response.statusCode}');
        print('GET /auth/profile/ response body: ${response.body}');
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          Map<String, dynamic> userData = responseData['user'] ?? responseData;
          
          // Ensure profile image URL is complete
          if (userData['profile_image'] != null && userData['profile_image'].isNotEmpty) {
            if (!userData['profile_image'].startsWith('http')) {
              userData['profile_image'] = '${ApiService.baseUrl}${userData['profile_image']}';
            }
          }
          
          _userData = userData;
          notifyListeners();
          return _userData;
        }
      } catch (e) {
        print('Error fetching user profile from alternative endpoint: $e');
      }
      
      // If both fail, return current userData
      return _userData;
    } catch (e) {
      print('Error in getUserData: $e');
      return _userData;
    }
  }



 
  Future<bool> login(String email, String password) async {
    try {
      final response = await ApiService.login(
        email: email,
        password: password,
      );
      
      _userData = response['user'];
      _isAuthenticated = true;
      
      // Debug log
      print('Login successful. User data: $_userData');
      print('Address from login: ${_userData?['address']}');
      print('Wilaya from login: ${_userData?['wilaya']}');
      print('Phone from login: ${_userData?['phone']}');
      
      // Ensure profile image URL is complete
      if (_userData != null && _userData!['profile_image'] != null && _userData!['profile_image'].isNotEmpty) {
        if (!_userData!['profile_image'].startsWith('http')) {
          _userData!['profile_image'] = '${ApiService.baseUrl}${_userData!['profile_image']}';
        }
      }
      
      // Set the current user ID in ApiService
      if (_userData != null && _userData!['id'] != null) {
        ApiService.setCurrentUserId(_userData!['id'].toString());
      }
      
      notifyListeners();
      return true; // Return true for successful login
    } catch (e) {
      print('Login error: $e');
      _isAuthenticated = false;
      _userData = null;
      notifyListeners();
      
      // Rethrow the exception so it can be caught in the UI
      throw Exception('Invalid credentials. Please check your email and password.');
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final response = await ApiService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      _userData = response['user'];
      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      print('Registration error: $e');
      _isAuthenticated = false;
      _userData = null;
      notifyListeners();
      
      // Rethrow with more specific error message if possible
      if (e.toString().contains('400')) {
        throw Exception('Invalid registration data. Please check all fields.');
      } else if (e.toString().contains('email')) {
        throw Exception('This email is already registered.');
      } else {
        rethrow;
      }
    }
  }

  Future<void> logout() async {
    try {
      // Unsubscribe from topics
      if (_userData != null && _userData!['id'] != null) {
        final userId = _userData!['id'].toString();
       
      }
      
      // Clear secure storage
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'userData');
      
      // Reset state
      _userData = null;
      _isAuthenticated = false;
      
      notifyListeners();
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    String? phone,
    File? imageFile,
    Uint8List? webImageBytes,
    String? imageName,
  }) async {
    try {
      final response = await ApiService.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        imageFile: imageFile,
        webImageBytes: webImageBytes,
        imageName: imageName,
      );
      
      _userData = response['user'];
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('Session expired')) {
        await logout();
      }
      rethrow;
    }
  }

  Future<void> updateShippingAddress({
    required String address,
    required String wilaya,
    required String phone,
  }) async {
    try {
      final response = await ApiService.updateShippingAddress(
        address: address,
        wilaya: wilaya,
        phone: phone,
      );
      
      _userData = response['user'];
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('Session expired')) {
        await logout();
      }
      rethrow;
    }
  }

 


  // Add this method to check authentication status
  Future<bool> validateAuthentication() async {
    final token = await _storage.read(key: 'access_token');
    print('Current auth token: ${token != null ? "exists" : "missing"}');
    
    if (token != null) {
      try {
        // Make a test request to validate the token
        final response = await ApiService.get('/api/user/');
        print('Auth validation response: ${response.statusCode}');
        return response.statusCode == 200;
      } catch (e) {
        print('Auth validation error: $e');
        return false;
      }
    }
    return false;
  }
}






























