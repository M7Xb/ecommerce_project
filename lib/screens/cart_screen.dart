import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/checkout_screen.dart';
import '../models/product.dart'; // Add this import for Product and CategoryInfo

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch cart data when screen opens (only if user is logged in)
    Future.delayed(Duration.zero, () {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        Provider.of<CartProvider>(context, listen: false).fetchFromServer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    // Check if user is authenticated
    if (!authProvider.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Shopping Cart',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Please log in to view your cart',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your cart items will be saved to your account',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Log In'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Original cart screen for authenticated users
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shopping Cart',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                // Show confirmation dialog
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Cart'),
                    content: const Text('Are you sure you want to remove all items?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('CANCEL'),
                      ),
                      TextButton(
                        onPressed: () {
                          cart.clear();
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('CLEAR'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'Clear Cart',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      body: cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 100,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add items to start shopping',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Start Shopping'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Order Progress Indicator
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      _buildProgressStep(context, 1, 'Cart', true),
                      _buildProgressLine(context, false),
                      _buildProgressStep(context, 2, 'Checkout', false),
                      _buildProgressLine(context, false),
                      _buildProgressStep(context, 3, 'Confirmation', false),
                    ],
                  ),
                ),
                
                // Cart Summary Card
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade100, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total: \$${cart.formattedPrice(cart.totalAmount)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.add_shopping_cart),
                            label: const Text('Add More'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              foregroundColor: Colors.black87,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: cart.items.length,
                    itemBuilder: (ctx, i) {
                      final cartItem = cart.items.values.toList()[i];
                      final productId = cart.items.keys.toList()[i];
                      return Dismissible(
                        key: ValueKey(cartItem.id),
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.delete,
                            color: Colors.red.shade700,
                            size: 28,
                          ),
                        ),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) {
                          return showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Remove Item'),
                              content: Text('Remove ${cartItem.title} from cart?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('CANCEL'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('REMOVE'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) {
                          cart.removeItem(productId);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade100, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                // Product Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    cartItem.imageUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Product Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cartItem.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '\$${cartItem.formattedPrice(cartItem.price)}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Theme.of(context).primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Quantity Controls
                                      Row(
                                        children: [
                                          _buildQuantityButton(
                                            context,
                                            Icons.remove,
                                            () {
                                              if (cartItem.quantity > 1) {
                                                cart.updateItemQuantity(productId, cartItem.quantity - 1);
                                              } else {
                                                // Show confirmation dialog for removal
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text('Remove Item'),
                                                    content: Text('Remove ${cartItem.title} from cart?'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.of(ctx).pop(),
                                                        child: const Text('CANCEL'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          cart.removeItem(productId);
                                                          Navigator.of(ctx).pop();
                                                        },
                                                        child: const Text('REMOVE'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                          Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${cartItem.quantity}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          _buildQuantityButton(
                                            context,
                                            Icons.add,
                                            () => cart.updateItemQuantity(productId, cartItem.quantity + 1),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Total Price
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$${cartItem.formattedPrice(cartItem.price * cartItem.quantity)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Remove Item'),
                                            content: Text('Remove ${cartItem.title} from cart?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(ctx).pop(),
                                                child: const Text('CANCEL'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  cart.removeItem(productId);
                                                  Navigator.of(ctx).pop();
                                                },
                                                child: const Text('REMOVE'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Checkout Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Order Summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            _buildSummaryRow(context, 'Subtotal', '\$${cart.formattedPrice(cart.totalAmount)}'),
                            const SizedBox(height: 8),
                            _buildSummaryRow(context, 'Shipping', 'Free'),
                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              context, 
                              'Total', 
                              '\$${cart.formattedPrice(cart.totalAmount)}',
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Checkout Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (await _validateStockBeforeCheckout(context, cart)) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const CheckoutScreen(),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            shadowColor: Theme.of(context).primaryColor.withAlpha(102),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.shopping_bag_outlined,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Proceed to Checkout',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(51),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<bool> _validateStockBeforeCheckout(BuildContext context, CartProvider cart) async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    bool hasStockIssue = false;
    String errorMessage = '';
    
    // Fetch latest product data to get current stock levels
    await productProvider.fetchProducts();
    
    // Check each cart item against current stock
    for (final productId in cart.items.keys) {
      final cartItem = cart.items[productId]!;
      
      // Find the product in the product provider
      final products = productProvider.products.where((p) => p.id == productId).toList();
      if (products.isNotEmpty) {
        final product = products.first;
        if (product.stockQuantity < cartItem.quantity) {
          hasStockIssue = true;
          if (product.stockQuantity <= 0) {
            errorMessage += '• ${cartItem.title} is out of stock\n';
          } else {
            errorMessage += '• ${cartItem.title}: only ${product.stockQuantity} available\n';
          }
        }
      }
    }
    
    if (hasStockIssue) {
      // Show error dialog
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stock Issues'),
          content: Text(
            'Some items in your cart have stock issues:\n\n$errorMessage\n'
            'Please update your cart before proceeding.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }
    
    return true;
  }

  Product findProductById(BuildContext context, String id) {
    final products = Provider.of<ProductProvider>(context, listen: false).products;
    return products.firstWhere(
      (product) => product.id == id,
      orElse: () => Product(
        id: 'unknown',
        title: 'Unknown Product',
        price: 0,
        description: '',
        imageUrl: '',
        category: CategoryInfo(id: '0', name: 'Unknown'),
        stockQuantity: 0,
        isNew: false,
        isOnSale: false,
      ),
    );
  }

  // Helper method to build quantity control buttons
  Widget _buildQuantityButton(BuildContext context, IconData icon, VoidCallback onPressed) {
    // Determine color based on icon
    final Color buttonColor = icon == Icons.remove 
        ? Colors.red.shade400  // Red for minus
        : Colors.green.shade500;  // Green for plus
      
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: buttonColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: buttonColor, width: 1.5),
        ),
        child: Center(
          child: Icon(
            icon, 
            size: 20, 
            color: buttonColor,
            weight: 700,
          ),
        ),
      ),
    );
  }

  // Helper method to build summary rows
  Widget _buildSummaryRow(BuildContext context, String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.black : Colors.grey[700],
          ),
        ),
        Text(
          value == 'Free' 
              ? value 
              : value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: value == 'Free' 
                ? Colors.green.shade600
                : (isTotal ? Theme.of(context).primaryColor : Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  // Helper method to build progress steps
  Widget _buildProgressStep(BuildContext context, int step, String label, bool isActive) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade600,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build progress lines
  Widget _buildProgressLine(BuildContext context, bool isActive) {
    return Container(
      width: 40,
      height: 2,
      color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade300,
    );
  }
}

// The findProductById method is now inside the CartScreen class
// and takes a BuildContext as a parameter
// The CategoryInfo issue is fixed by providing a default value
// for the category when creating the Product instance
// The method is now called with the context and product ID
// Example usage: final product = findProductById(context, cartItem.productId);




















