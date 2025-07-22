import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/category.dart';
import '../services/api_service.dart';

class CategoryProvider with ChangeNotifier {
  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<Category> get categories => [..._categories];
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCategories() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/categories/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('categories')) {
          _categories = (data['categories'] as List)
              .map((category) => Category.fromJson(category))
              .toList();
          _error = null;
        } else {
          _error = 'Invalid response format';
        }
      } else {
        _error = 'Failed to load categories';
      }

      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}

