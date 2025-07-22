import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import '../services/api_service.dart';
import '../models/order.dart';
import 'notifications_provider.dart';
import 'package:provider/provider.dart';

class OrdersProvider with ChangeNotifier {
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;
  Timer? _pollingTimer;
  final Duration _pollingInterval = const Duration(seconds: 30);
  BuildContext? _context;
  
  List<Order> get orders => [..._orders];
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  void setContext(BuildContext context) {
    _context = context;
  }
  
  Future<void> fetchOrders() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      print('Fetching orders from: ${ApiService.baseUrl}/api/orders/');
      final response = await ApiService.get('/api/orders/list/');
      print('Orders API response status: ${response.statusCode}');
      print('Orders API response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Decoded orders data: $data');
        
        // Check if the response is a list or has an orders key
        List<dynamic> ordersData;
        if (data is List) {
          // Direct list of orders
          ordersData = data;
        } else if (data is Map && data.containsKey('orders')) {
          // Object with orders key
          ordersData = data['orders'] ?? [];
        } else {
          print('Invalid response format: not a list or missing orders key');
          _error = 'Invalid response format from server';
          _isLoading = false;
          notifyListeners();
          return;
        }
        
        _orders = ordersData.map((item) => Order.fromJson(item)).toList();
        
        // Sort orders by date (newest first)
        _orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
        
        _isLoading = false;
        _error = null;
      } else {
        _error = 'Failed to load orders (Status: ${response.statusCode})';
        _isLoading = false;
      }
      
      notifyListeners();
    } catch (e) {
      print('Error fetching orders: $e');
      _error = 'Failed to load orders: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<Order?> getOrderDetails(String orderId) async {
    try {
      final response = await ApiService.get('/api/orders/$orderId/');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Order.fromJson(data);
      } else {
        _error = 'Failed to load order details';
        return null;
      }
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }
  
  void startOrderStatusPolling() {
    print('Starting order status polling...');
    
    // Cancel existing timer if any
    _pollingTimer?.cancel();
    
    // Start new polling timer
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      print('Polling for order status updates...');
      _checkOrderStatusUpdates();
    });
  }
  
  void stopOrderStatusPolling() {
    print('Stopping order status polling...');
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
  
  Future<void> _checkOrderStatusUpdates() async {
    try {
      // Only check for updates if we have orders
      if (_orders.isEmpty) {
        await fetchOrders();
        return;
      }
      
      final response = await ApiService.get('/api/orders/status-updates/');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> updatedOrdersData = data['orders'] ?? [];
        
        // Check for status changes
        for (var updatedOrderData in updatedOrdersData) {
          final updatedOrder = Order.fromJson(updatedOrderData);
          final existingOrderIndex = _orders.indexWhere((o) => o.id == updatedOrder.id);
          
          if (existingOrderIndex != -1) {
            final existingOrder = _orders[existingOrderIndex];
            
            // Check if status has changed
            if (existingOrder.status != updatedOrder.status) {
              print('Order ${updatedOrder.id} status changed from ${existingOrder.status} to ${updatedOrder.status}');
              
              // Update the order in our list
              _orders[existingOrderIndex] = updatedOrder;
              
              // Create a notification for the status change
              if (_context != null) {
                final notificationsProvider = Provider.of<NotificationsProvider>(
                  _context!,
                  listen: false,
                );
                
                notificationsProvider.addLocalNotification(
                  title: 'Order Status Update',
                  message: 'Your order #${updatedOrder.orderNumber} has been ${_getStatusMessage(updatedOrder.status)}',
                  orderId: updatedOrder.id,
                );
              }
            }
          } else {
            // New order, add it to the list
            _orders.add(updatedOrder);
          }
        }
        
        // Sort orders by date (newest first)
        _orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
        
        notifyListeners();
      }
    } catch (e) {
      print('Error checking order status updates: $e');
    }
  }
  
  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'received and is pending';
      case 'processing':
        return 'being processed';
      case 'shipped':
        return 'shipped';
      case 'delivered':
        return 'delivered';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'updated to $status';
    }
  }
  
  @override
  void dispose() {
    stopOrderStatusPolling();
    super.dispose();
  }

  Future<bool> addOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await ApiService.post('/api/orders/create/', orderData);
      
      print('Order creation response: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          final orderJson = json.decode(response.body);
          print('Decoded order JSON: $orderJson');
          
          // Create a new order from the response
          final newOrder = Order(
            id: orderJson['id'].toString(),
            amount: double.parse(orderJson['amount'].toString()),
            status: orderJson['status'] ?? 'pending',
            dateTime: DateTime.parse(orderJson['date_time']),
            deliveryInfo: orderJson['delivery_info'] ?? {},
            userOrderNumber: orderJson['user_order_number'],
          );
          
          // Add to local list
          _orders.add(newOrder);
          
          // Sort orders by date
          _orders.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          
          notifyListeners();
          
          // Fetch all orders to ensure the list is up to date
          fetchOrders();
          
          return true;
        } catch (e) {
          print('Error parsing order response: $e');
          _error = 'Order was placed but there was an error processing the response';
          
          // Fetch all orders to ensure the list is up to date even if parsing failed
          fetchOrders();
          
          // Return true since the order was actually placed
          return true;
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          _error = errorData['error'] ?? 'Failed to place order';
        } catch (e) {
          _error = 'Failed to place order (Status: ${response.statusCode})';
        }
        return false;
      }
    } catch (e) {
      print('Error adding order: $e');
      _error = e.toString();
      return false;
    }
  }

  Future<bool> cancelOrder(String orderId) async {
    try {
      final response = await ApiService.post('/api/orders/$orderId/cancel/', {});
      
      if (response.statusCode == 200) {
        // Update local order status
        final orderIndex = _orders.indexWhere((o) => o.id == orderId);
        if (orderIndex != -1) {
          // Create a new order with updated status
          final updatedOrder = Order(
            id: _orders[orderIndex].id,
            amount: _orders[orderIndex].amount,
            status: 'cancelled',
            dateTime: _orders[orderIndex].dateTime,
            deliveryInfo: _orders[orderIndex].deliveryInfo,
            userOrderNumber: _orders[orderIndex].userOrderNumber,
          );
          
          _orders[orderIndex] = updatedOrder;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Error cancelling order: $e');
      return false;
    }
  }

  void _sortOrders() {
    _orders.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }
}








