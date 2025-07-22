import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/notification_service.dart';

class NotificationEndpoint {
  static Future<void> handleIncomingNotification(http.Request request) async {
    try {
      final body = await utf8.decode(request.bodyBytes);
      final data = json.decode(body);
      
      // Extract notification data from the response
      final notification = data['notification'] ?? data;
      
      await NotificationService.showNotification(
        title: notification['title'] ?? 'Order Update',
        message: notification['message'],
        orderId: notification['orderId']?.toString(),
      );
      
    } catch (e) {
      debugPrint('Error handling incoming notification: $e');
      rethrow;
    }
  }
}
