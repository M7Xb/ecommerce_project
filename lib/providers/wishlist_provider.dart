import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/product.dart';

class WishlistProvider with ChangeNotifier {
  List<Product> _items = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get items => [..._items];
  int get itemCount => _items.length;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchWishlist() async {
    if (_isLoading) return; // Prevent multiple simultaneous fetches
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final wishlistItems = await ApiService.getWishlist();
      _items = wishlistItems;
      _error = null;
    } catch (e) {
      _error = 'Error fetching wishlist: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleWishlistItem(String productId, Product product) async {
    try {
      final isAdded = await ApiService.toggleWishlist(productId);
      
      if (isAdded) {
        if (!_items.any((item) => item.id == productId)) {
          _items.add(product);
        }
      } else {
        _items.removeWhere((item) => item.id == productId);
      }
      
      notifyListeners();
    } catch (e) {
      print('Error toggling wishlist item: $e');
    }
  }

  bool isInWishlist(String productId) {
    return _items.any((item) => item.id == productId);
  }

  // clearWishlist method removed
}


