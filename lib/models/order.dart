
import 'cart.dart';  // Import for CartItem if needed

class Order {
  final String id;
  final double amount;
  final String status;
  final DateTime dateTime;
  final dynamic deliveryInfo; // Change to dynamic to handle Map or String
  final String userOrderNumber;
  final List<OrderItem> items; // Add items field
  
  Order({
    required this.id,
    required this.amount,
    required this.status,
    required this.dateTime,
    this.deliveryInfo,
    required this.userOrderNumber,
    this.items = const [], // Default to empty list
  });
  
  // Add these getters to fix the errors
  DateTime get orderDate => dateTime;
  String get orderNumber => userOrderNumber;

  // Add this method to format prices
  String formattedPrice(double price) {
    // Remove decimal zeros if the number is a whole number
    if (price == price.roundToDouble()) {
      return price.toInt().toString();
    } else {
      return price.toStringAsFixed(2);
    }
  }

  // Add a getter for formatted amount
  String get displayAmount => formattedPrice(amount);

  // Add the canBeCancelled getter
  bool get canBeCancelled {
    // Only pending orders can be cancelled
    return status.toLowerCase() == 'pending';
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    try {
      return Order(
        id: json['id'].toString(),
        userOrderNumber: json['user_order_number']?.toString() ?? '',
        amount: double.parse(json['amount'].toString()),
        dateTime: DateTime.parse(json['date_time']),
        status: json['status'] ?? 'pending',
        deliveryInfo: json['delivery_info'],
        items: (json['items'] as List<dynamic>?)
                ?.map((item) => OrderItem.fromJson(item))
                .toList() ??
            [],
      );
    } catch (e) {
      print('Error parsing order: $e');
      rethrow;
    }
  }
  
  // Add copyWith method
  Order copyWith({
    String? id,
    double? amount,
    String? status,
    DateTime? dateTime,
    dynamic deliveryInfo,
    String? userOrderNumber,
    List<OrderItem>? items,
  }) {
    return Order(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      dateTime: dateTime ?? this.dateTime,
      deliveryInfo: deliveryInfo ?? this.deliveryInfo,
      userOrderNumber: userOrderNumber ?? this.userOrderNumber,
      items: items ?? this.items,
    );
  }
}

class OrderItem {
  final String productId;
  final String title;
  final int quantity;
  final double price;
  final String imageUrl;

  OrderItem({
    required this.productId,
    required this.title,
    required this.quantity,
    required this.price,
    required this.imageUrl,
  });

  // Add this method to format prices
  String formattedPrice(double price) {
    // Remove decimal zeros if the number is a whole number
    if (price == price.roundToDouble()) {
      return price.toInt().toString();
    } else {
      return price.toStringAsFixed(2);
    }
  }

  // Add a getter for formatted price
  String get displayPrice => formattedPrice(price);

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      quantity: int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'title': title,
      'quantity': quantity,
      'price': price,
      'image_url': imageUrl,
    };
  }

  // Helper method to create OrderItem from CartItem
  factory OrderItem.fromCartItem(CartItem cartItem) {
    return OrderItem(
      productId: cartItem.id,
      title: cartItem.title,
      quantity: cartItem.quantity,
      price: cartItem.price,
      imageUrl: cartItem.imageUrl,
    );
  }
}



























