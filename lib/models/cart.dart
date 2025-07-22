class CartItem {
  final String id;        // Cart item ID
  final String productId; // Actual product ID
  final String title;
  final int quantity;
  final double price;
  final String imageUrl;

  CartItem({
    required this.id,
    required this.productId,
    required this.title,
    required this.quantity,
    required this.price,
    required this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'quantity': quantity,
      'price': price,
      'imageUrl': imageUrl,
    };
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
}




