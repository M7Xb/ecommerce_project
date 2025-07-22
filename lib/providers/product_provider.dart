import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/deal.dart';
import '../services/api_service.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  List<Deal> _deals = [];
  bool _isLoading = false;
  String? _error;
  List<Product> _categoryProducts = [];
  List<Product> _searchResults = [];
  bool _isSearching = false;

  List<Product> get products => [..._products];
  List<Deal> get deals => [..._deals];
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Product> get categoryProducts => [..._categoryProducts];
  List<Product> get searchResults => [..._searchResults];
  bool get isSearching => _isSearching;

  Future<void> fetchProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Use ApiService instead of direct http calls
      final productsResponse = await ApiService.get('/api/products/');
      print('Products API response status: ${productsResponse.statusCode}');

      if (productsResponse.statusCode == 200) {
        final productsData = json.decode(productsResponse.body);
        print('Products data: $productsData');
        
        if (productsData.containsKey('products')) {
          _products = (productsData['products'] as List)
              .map((item) {
                // Ensure stock_quantity is included
                print('Product item: $item');
                if (!item.containsKey('stock_quantity')) {
                  print('Adding default stock_quantity');
                  item['stock_quantity'] = 0; // Default value if missing
                }
                return Product.fromJson(item);
              })
              .toList();
        } else {
          throw Exception('Invalid response format: missing products key');
        }
      } else {
        throw Exception('Failed to load products. Status: ${productsResponse.statusCode}');
      }

      // Debug print for deals API URL
      final dealsResponse = await ApiService.get('/api/deals/active/');

      if (dealsResponse.statusCode == 200) {
        final dealsData = json.decode(dealsResponse.body);
        if (dealsData.containsKey('deals')) {
          _deals = (dealsData['deals'] as List)
              .map((item) => Deal.fromJson(item))
              .toList();
        } else {
          throw Exception('Invalid response format: missing deals key');
        }
      } else {
        throw Exception('Failed to load deals. Status: ${dealsResponse.statusCode}');
      }

      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (error) {
      _error = 'Failed to load data: ${error.toString()}';
      _isLoading = false;
      _products = [];
      _deals = [];
      notifyListeners();
    }
  }

  Future<void> fetchProductsByCategory(String categoryId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await ApiService.get('/api/products/?category=$categoryId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('products')) {
          _categoryProducts = (data['products'] as List).map((product) {
            // Ensure category information is properly included
            if (product['category'] == null || product['category'] is String) {
              product['category'] = {
                'id': categoryId,
                'name': product['category_name'] ?? '',
                'icon': product['category_icon'] ?? '',
              };
            }
            return Product.fromJson(product);
          }).toList();
          
          print('Fetched ${_categoryProducts.length} products for category $categoryId'); // Debug log
          _error = null;
        } else {
          _error = 'Invalid response format';
        }
      } else {
        _error = 'Failed to load products. Status: ${response.statusCode}';
        print('API Error: ${response.body}'); // Debug log
      }

      _isLoading = false;
      notifyListeners();
    } catch (error) {
      print('Error fetching products: $error'); // Debug log
      _error = error.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchProducts(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      // If we already have products loaded, we can filter them locally
      if (_products.isNotEmpty) {
        _searchResults = _products.where((product) {
          final titleMatch = product.title.toLowerCase().contains(query.toLowerCase());
          final categoryMatch = product.category.name.toLowerCase().contains(query.toLowerCase());
          final descriptionMatch = product.description.toLowerCase().contains(query.toLowerCase());
          return titleMatch || categoryMatch || descriptionMatch;
        }).toList();
        _isSearching = false;
        notifyListeners();
      } else {
        // If products aren't loaded yet, fetch them first
        await fetchProducts();
        // Then perform the search
        searchProducts(query);
      }
    } catch (error) {
      _error = 'Search failed: ${error.toString()}';
      _isSearching = false;
      _searchResults = [];
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    _isSearching = false;
    notifyListeners();
  }
}



