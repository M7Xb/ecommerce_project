import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_service.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final bool isRead;
  final String? orderId;
  final DateTime timestamp;
  
  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.isRead = false,
    this.orderId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  // Add copyWith method
  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    bool? isRead,
    String? orderId,
    DateTime? timestamp,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      orderId: orderId ?? this.orderId,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class NotificationsProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  String? _currentUserId;
  bool _isLoading = false;
  String? _error;
  
  List<NotificationModel> get notifications => [..._notifications];
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  String? get currentUserId => _currentUserId;
  
  void clearAll() {
    _notifications = [];
    notifyListeners();
  }
  
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    fetchNotifications();
  }
  
  Future<void> fetchNotifications() async {
    if (_currentUserId == null) {
      print('Cannot fetch notifications: No user ID set');
      return;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await ApiService.get('/api/notifications/');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> notificationsData = data['notifications'] ?? [];
        
        _notifications = notificationsData.map((item) {
          return NotificationModel(
            id: item['id'].toString(),
            title: item['title'] ?? 'Notification',
            message: item['message'] ?? '',
            isRead: item['is_read'] ?? false,
            timestamp: DateTime.parse(item['created_at']),
            orderId: item['order_id']?.toString(),
          );
        }).toList();
        
        // Sort notifications by date (newest first)
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        _isLoading = false;
        _error = null;
      } else {
        _error = 'Failed to load notifications';
        _isLoading = false;
      }
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> markAsRead(String notificationId) async {
    try {
      // Find the notification in the local list
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index == -1) {
        // If not found by ID, try to find by orderId (for FCM notifications)
        final orderIndex = _notifications.indexWhere((n) => n.orderId == notificationId);
        if (orderIndex == -1) {
          print('Notification not found: $notificationId');
          return;
        }
        
        // Update local state
        _notifications[orderIndex] = _notifications[orderIndex].copyWith(isRead: true);
        notifyListeners();
        
        // Update on server
        await ApiService.post('/api/notifications/mark-read/', {
          'notification_id': _notifications[orderIndex].id,
        });
        
        return;
      }
      
      // Update local state
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
      
      // Update on server
      await ApiService.post('/api/notifications/mark-read/', {
        'notification_id': notificationId,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }
  
  Future<void> markAllAsRead() async {
    try {
      // Update local state
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      notifyListeners();
      
      // Update on server
      await ApiService.post('/api/notifications/mark-all-read/', {});
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }
  
  void addLocalNotification({
    required String? title,
    required String? message,
    String? orderId,
  }) {
    if (title == null || message == null) {
      return;
    }
    
    // Check if a notification with the same orderId already exists
    if (orderId != null) {
      final existingIndex = _notifications.indexWhere((n) => n.orderId == orderId);
      if (existingIndex != -1) {
        // Update existing notification
        _notifications[existingIndex] = NotificationModel(
          id: _notifications[existingIndex].id,
          title: title,
          message: message,
          isRead: false,
          timestamp: DateTime.now(),
          orderId: orderId,
        );
        
        notifyListeners();
        return;
      }
    }
    
    // Add new notification
    final newNotification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      isRead: false,
      timestamp: DateTime.now(),
      orderId: orderId,
    );
    
    _notifications.insert(0, newNotification);
    notifyListeners();
  }
  
  void clearNotifications() {
    _notifications = [];
    notifyListeners();
  }
}





