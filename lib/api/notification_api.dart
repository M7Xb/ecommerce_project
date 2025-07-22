import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationApi {
  static Future<void> handleNotification(Map<String, dynamic> data) async {
    try {
      await NotificationService.showNotification(
        title: data['title'],
        message: data['message'],
        orderId: data['orderId'],
      );
    } catch (e) {
      debugPrint('Error handling notification: $e');
    }
  }
}