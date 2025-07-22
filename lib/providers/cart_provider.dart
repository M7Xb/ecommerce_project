import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Add this import for BuildContext
import '../models/cart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import '../main.dart'; // Add this import for navigatorKey

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  String? _userId;

  Map<String, CartItem> get items => {..._items};

  int get itemCount => _items.length;

  double get totalAmount {
    return _items.values.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  void addItem(String productId, double price, String title, String imageUrl, [int stockQuantity = 999]) {
    // Ensure image URL is absolute
    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = '${ApiService.baseUrl}$imageUrl';
      print('Converted cart item image URL to: $imageUrl');
    }
    
    if (_items.containsKey(productId)) {
      // If the item already exists, increase quantity
      _items.update(
        productId,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          productId: productId,
          title: existingCartItem.title,
          quantity: existingCartItem.quantity + 1,
          price: existingCartItem.price,
          imageUrl: imageUrl, // Use the corrected URL
        ),
      );
      print('Updated item $productId in cart, new quantity: ${_items[productId]!.quantity}');
    } else {
      // If the item doesn't exist, add it
      _items.putIfAbsent(
        productId,
        () => CartItem(
          id: DateTime.now().toString(),
          productId: productId,
          title: title,
          quantity: 1,
          price: price,
          imageUrl: imageUrl, // Use the corrected URL
        ),
      );
      print('Added new item $productId to cart with quantity: 1');
    }
    notifyListeners();
  }

  Future<void> removeItem(String productId) async {
    // First remove locally
    _items.remove(productId);
    notifyListeners();
    
    // Then remove from server if user is logged in
    if (_userId != null) {
      try {
        print('Removing item $productId from server cart');
        final response = await http.delete(
          Uri.parse('${ApiService.baseUrl}/api/cart/remove-item/$productId/'),
          headers: await ApiService.getAuthHeaders(),
        );
        
        if (response.statusCode == 200) {
          print('Item removed from server successfully');
        } else {
          print('Failed to remove item from server: ${response.statusCode}');
          print('Response body: ${response.body}');
          
          // If server removal failed, try syncing the entire cart
          await syncWithServer();
        }
      } catch (e) {
        print('Error removing item from server: $e');
        // If there was an error, try syncing the entire cart
        await syncWithServer();
      }
    } else {
      print('Cannot remove from server: No user ID set');
    }
  }

  Future<void> clear() async {
    // First clear locally
    _items.clear();
    notifyListeners();
    
    // Then clear on server if user is logged in
    if (_userId != null) {
      try {
        print('Clearing cart on server');
        final response = await http.delete(
          Uri.parse('${ApiService.baseUrl}/api/cart/clear/'),
          headers: await ApiService.getAuthHeaders(),
        );
        
        if (response.statusCode == 200) {
          print('Cart cleared on server successfully');
        } else {
          print('Failed to clear cart on server: ${response.statusCode}');
        }
      } catch (e) {
        print('Error clearing cart on server: $e');
      }
    } else {
      print('Cannot clear cart on server: No user ID set');
    }
  }

  void decreaseQuantity(String productId) {
    if (!_items.containsKey(productId)) {
      return;
    }
    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          productId: productId,  // Add the missing productId parameter
          title: existingCartItem.title,
          quantity: existingCartItem.quantity - 1,
          price: existingCartItem.price,
          imageUrl: existingCartItem.imageUrl,
        ),
      );
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  Future<void> updateItemQuantity(String productId, int newQuantity) async {
    if (!_items.containsKey(productId)) {
      return;
    }
    
    if (newQuantity <= 0) {
      // If quantity is zero or negative, remove the item
      await removeItem(productId);
    } else {
      // Update locally
      _items.update(
        productId,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          productId: productId,
          title: existingCartItem.title,
          quantity: newQuantity,
          price: existingCartItem.price,
          imageUrl: existingCartItem.imageUrl,
        ),
      );
      notifyListeners();
      
      // Update on server if user is logged in
      if (_userId != null) {
        try {
          print('Updating item quantity on server: $productId, quantity: $newQuantity');
          final response = await http.put(
            Uri.parse('${ApiService.baseUrl}/api/cart/update-item/$productId/'),
            headers: await ApiService.getAuthHeaders(),
            body: json.encode({'quantity': newQuantity}),
          );
          
          if (response.statusCode == 200) {
            print('Item quantity updated on server successfully');
          } else {
            print('Failed to update item quantity on server: ${response.statusCode}');
            // If server update failed, try syncing the entire cart
            await syncWithServer();
          }
        } catch (e) {
          print('Error updating item quantity on server: $e');
          // If there was an error, try syncing the entire cart
          await syncWithServer();
        }
      } else {
        print('Cannot update item on server: No user ID set');
      }
    }
  }

  // Add this method to format prices
  String formattedPrice(double price) {
    // Remove decimal zeros if the number is a whole number
    if (price == price.roundToDouble()) {
      return price.toInt().toString();
    } else {
      return price.toStringAsFixed(2);
    }
  }

  // Sync cart with server (call this after local changes)
  Future<void> syncWithServer() async {
    if (_userId == null) {
      // Only sync for authenticated users
      return;
    }
    
    try {
      // Convert cart items to format expected by API
      final cartItems = _items.values.map((item) => {
        'product_id': item.productId,
        'quantity': item.quantity,
      }).toList();
      
      // Send to server
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/cart/sync/'),
        headers: await ApiService.getAuthHeaders(),
        body: json.encode({'items': cartItems}),
      );
      
      if (response.statusCode == 200) {
        print('Cart synced with server successfully');
      } else {
        print('Failed to sync cart: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing cart: $e');
    }
  }

  // Add a method to set the user ID when logging in
  void setUserId(String? userId) {
    // If user ID changed, clear the cart
    if (_userId != userId) {
      _items.clear();
    }
    _userId = userId;
    notifyListeners();
  }

  // Add a method to clear the cart when logging out
  void clearOnLogout() {
    _items.clear();
    _userId = null;
    notifyListeners();
  }

  // Fetch cart from server (call this at login)
  Future<void> fetchFromServer() async {
    if (_userId == null) {
      print('Cannot fetch cart: No user ID set');
      return;
    }
    
    try {
      print('Fetching cart for user $_userId from server...');
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/cart/'),
        headers: await ApiService.getAuthHeaders(),
      );
      
      print('Cart fetch response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Cart data from server: $data');
        
        // Clear existing cart before loading from server
        _items.clear();
        
        // Add items from server
        if (data['items'] != null && data['items'].isNotEmpty) {
          final serverItems = List<Map<String, dynamic>>.from(data['items']);
          print('Found ${serverItems.length} items in server cart');
          
          for (var item in serverItems) {
            final productId = item['product_id'].toString();
            final quantity = int.parse(item['quantity'].toString());
            
            print('Adding item $productId to cart with quantity $quantity');
            
            // Create cart item with correct quantity
            _items.putIfAbsent(
              productId,
              () => CartItem(
                id: DateTime.now().toString(),
                productId: productId,
                title: item['title'],
                quantity: quantity, // Make sure we use the quantity from the server
                price: double.parse(item['price'].toString()),
                imageUrl: item['image_url'] ?? '',
              ),
            );
          }
          
          print('Cart updated with ${_items.length} items from server');
        } else {
          print('No items found in server cart');
        }
        
        notifyListeners();
      } else if (response.statusCode == 404) {
        print('Cart endpoint not found. This might be normal for new users.');
      } else {
        print('Failed to fetch cart: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching cart: $e');
    }
  }

  // New method to add item directly to database
  Future<bool> addItemToDatabase(String productId, double price, String title, String imageUrl, [int stockQuantity = 999]) async {
    // First add to local state
    addItem(productId, price, title, imageUrl, stockQuantity);
    
    print('Adding item to database. User ID: $_userId');
    
    // Check authentication status
    final authProvider = Provider.of<AuthProvider>(navigatorKey.currentContext!, listen: false);
    print('Auth status: isAuthenticated=${authProvider.isAuthenticated}, userData=${authProvider.userData != null}');
    
    // Then save to database if user is logged in
    if (_userId != null) {
      try {
        // Get the current quantity from local state
        int quantity = _items[productId]!.quantity;
        print('Sending item to server with quantity: $quantity');
        
        // Prepare the item data
        final itemData = {
          'product_id': productId,
          'quantity': quantity,
          'price': price,
          'title': title,
          'image_url': imageUrl
        };
        
        // Send to server
        final response = await http.post(
          Uri.parse('${ApiService.baseUrl}/api/cart/add-item/'),
          headers: await ApiService.getAuthHeaders(),
          body: json.encode(itemData),
        );
        
        if (response.statusCode == 200) {
          print('Item added to database successfully');
          return true;
        } else {
          print('Failed to add item to database: ${response.statusCode}');
          print('Response body: ${response.body}');
          return false;
        }
      } catch (e) {
        print('Error adding item to database: $e');
        return false;
      }
    } else {
      print('Cannot save to database: No user ID set. Auth status: ${authProvider.isAuthenticated}');
      
      // If user is authenticated but userId is not set, try to set it now
      if (authProvider.isAuthenticated && authProvider.userData != null && authProvider.userData!['id'] != null) {
        final userId = authProvider.userData!['id'].toString();
        print('User is authenticated but userId not set. Setting now: $userId');
        setUserId(userId);
        
        // Try again with the newly set userId
        return addItemToDatabase(productId, price, title, imageUrl, stockQuantity);
      }
    }
    return false;
  }

  // Add this method to ensure user ID is set if user is authenticated
  void ensureUserIdSet(BuildContext context) {
    if (_userId == null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated && authProvider.userData != null && authProvider.userData!['id'] != null) {
        final userId = authProvider.userData!['id'].toString();
        print('Setting missing user ID in CartProvider: $userId');
        setUserId(userId);
      }
    }
  }
}



