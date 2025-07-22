import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/orders_provider.dart';
import '../providers/auth_provider.dart';
import 'orders_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  String? _selectedWilaya;
  bool _isLoading = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userData = await authProvider.getUserData();
    if (userData != null) {
      setState(() {
        _userData = userData;
        _nameController.text = '${userData['first_name']} ${userData['last_name']}';
        
        // Pre-fill shipping information if available
        if (userData['phone'] != null && userData['phone'].toString().isNotEmpty) {
          _phoneController.text = userData['phone'].toString();
        }
        if (userData['address'] != null && userData['address'].toString().isNotEmpty) {
          _addressController.text = userData['address'].toString();
        }
        if (userData['wilaya'] != null && 
            userData['wilaya'].toString().isNotEmpty && 
            _wilayas.contains(userData['wilaya'])) {
          _selectedWilaya = userData['wilaya'].toString();
        }
      });
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Complete list of wilayas in Algeria
  final List<String> _wilayas = [
    'Adrar', 'Chlef', 'Laghouat', 'Oum El Bouaghi', 'Batna',
    'Bejaia', // Simplified version without diacritics
    'Biskra', 'Bechar', 'Blida', 'Bouira',
    'Tamanrasset', 'Tebessa', 'Tlemcen', 'Tiaret', 'Tizi Ouzou',
    'Alger', 'Djelfa', 'Jijel', 'Setif', 'Saida',
    'Skikda', 'Sidi Bel Abbes', 'Annaba', 'Guelma', 'Constantine',
    'Medea', 'Mostaganem', 'M\'Sila', 'Mascara', 'Ouargla',
    'Oran', 'El Bayadh', 'Illizi', 'Bordj Bou Arreridj', 'Boumerdes',
    'El Tarf', 'Tindouf', 'Tissemsilt', 'El Oued', 'Khenchela',
    'Souk Ahras', 'Tipaza', 'Mila', 'Ain Defla', 'Naama',
    'Ain Temouchent', 'Ghardaia', 'Relizane'
  ];

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final cart = Provider.of<CartProvider>(context, listen: false);

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty!')),
      );
      return;
    }

    if (_selectedWilaya == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a wilaya')),
      );
      return;
    }

    // Show confirmation dialog and handle the result
    final confirmed = await _showOrderConfirmationDialog();
    if (confirmed != true) return;  // This will now work correctly

    setState(() {
      _isLoading = true;
    });

    try {
      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);

      final orderData = {
        'total_amount': cart.totalAmount,
        'phone_number': _phoneController.text,
        'wilaya': _selectedWilaya!,
        'address': _addressController.text,
        'name': _nameController.text,
        'items': cart.items.entries.map((entry) {
          return {
            'product_id': entry.key,
            'quantity': entry.value.quantity,
            'price': entry.value.price,
            'title': entry.value.title,
            'image_url': entry.value.imageUrl,
          };
        }).toList(),
      };

      // Add debug logging
      print('Submitting order with data: $orderData');
      
      final success = await ordersProvider.addOrder(orderData);
      print('Order submission result: $success');
      print('Error from provider: ${ordersProvider.error}');

      if (success && mounted) {
        cart.clear();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Navigate to orders screen after a short delay to allow the snackbar to be seen
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const OrdersScreen(),
              ),
            );
          }
        });
      } else if (mounted) {
        final errorMessage = ordersProvider.error ?? 'Failed to place order';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (error) {
      print('Error in _submitOrder: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to build detail rows

  Widget _buildWilayaDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Wilaya',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(Icons.location_city),
      ),
      value: _selectedWilaya,
      items: _wilayas.map((String wilaya) {
        return DropdownMenuItem<String>(
          value: wilaya,
          child: Text(wilaya),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedWilaya = newValue;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a wilaya';
        }
        return null;
      },
    );
  }

  Future<bool?> _showOrderConfirmationDialog() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    
    return showDialog<bool>(  // Explicitly specify the return type as bool
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: const Offset(0.0, 10.0),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Order Icon
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withAlpha((0.1 * 255).round()),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 40,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              const Text(
                'Confirm Order',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              
              // Order Summary
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Items:',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          '${cart.itemCount}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          '\$${cart.formattedPrice(cart.totalAmount)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Message
              const Text(
                'Are you sure you want to place this order?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final userData = auth.userData;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Theme.of(context).primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Processing your order...',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order Progress Indicator
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Row(
                          children: [
                            _buildProgressStep(1, 'Cart', true),
                            _buildProgressLine(true),
                            _buildProgressStep(2, 'Checkout', true),
                            _buildProgressLine(false),
                            _buildProgressStep(3, 'Confirmation', false),
                          ],
                        ),
                      ),

                      // User Details Section
                      _buildSectionHeader(context, 'Personal Information', Icons.person_outline),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Theme.of(context).primaryColor.withOpacity(0.08),
                          border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Full Name Label
                              const Text(
                                'Full Name',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black, // Changed to black
                                ),
                              ),
                              const SizedBox(height: 8), // Space between label and input
                              // Full Name Input
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  hintText: 'Enter your full name',
                                  prefixIcon: Icon(Icons.person_outline, color: Theme.of(context).primaryColor),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Theme.of(context).primaryColor),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white, // Keep input field white for contrast
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20), // Space between form fields
                              
                              // Phone Number Label
                              const Text(
                                'Phone Number',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black, // Changed to black
                                ),
                              ),
                              const SizedBox(height: 8), // Space between label and input
                              // Phone Number Input
                              TextFormField(
                                controller: _phoneController,
                                decoration: InputDecoration(
                                  hintText: 'Enter your phone number',
                                  prefixIcon: Icon(Icons.phone_outlined, color: Theme.of(context).primaryColor),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Theme.of(context).primaryColor),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white, // Keep input field white for contrast
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Delivery Information
                      _buildSectionHeader(context, 'Delivery Information', Icons.local_shipping_outlined),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Theme.of(context).primaryColor.withOpacity(0.08),
                          border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Wilaya Label
                              const Text(
                                'Select Wilaya',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black, // Changed to black
                                ),
                              ),
                              const SizedBox(height: 8), // Space between label and input
                              // Wilaya Dropdown
                              DropdownButtonFormField<String>(
                                value: _selectedWilaya,
                                decoration: InputDecoration(
                                  hintText: 'Select your wilaya',
                                  prefixIcon: Icon(Icons.location_city_outlined, color: Theme.of(context).primaryColor),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Theme.of(context).primaryColor),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white, // Keep input field white for contrast
                                ),
                                items: _wilayas.map((String wilaya) {
                                  return DropdownMenuItem<String>(
                                    value: wilaya,
                                    child: Text(wilaya),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedWilaya = newValue;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a wilaya';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20), // Space between form fields
                              
                              // Address Label
                              const Text(
                                'Detailed Address',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black, // Changed to black
                                ),
                              ),
                              const SizedBox(height: 8), // Space between label and input
                              // Address Field
                              TextFormField(
                                controller: _addressController,
                                decoration: InputDecoration(
                                  hintText: 'Enter your detailed address',
                                  prefixIcon: Icon(Icons.home_outlined, color: Theme.of(context).primaryColor),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Theme.of(context).primaryColor),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white, // Keep input field white for contrast
                                ),
                                maxLines: 2,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your address';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Order Summary
                      _buildSectionHeader(context, 'Order Summary', Icons.shopping_bag_outlined),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Theme.of(context).primaryColor.withOpacity(0.08),
                          border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 250,
                                decoration: BoxDecoration(
                                  color: Colors.white, // White background for the list
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: cart.items.length,
                                  separatorBuilder: (context, index) => Divider(color: Colors.grey.shade300),
                                  itemBuilder: (context, index) {
                                    final item = cart.items.values.toList()[index];
                                    return Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            item.imageUrl,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              width: 60,
                                              height: 60,
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 15,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${item.quantity}x \$${item.formattedPrice(item.price)}',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '\$${item.formattedPrice(item.price * item.quantity)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).primaryColor,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(20), // Increased padding
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    _buildOrderSummaryRow('Subtotal', '\$${cart.formattedPrice(cart.totalAmount)}'),
                                    const SizedBox(height: 10), // Increased spacing
                                    _buildOrderSummaryRow('Shipping', 'Free', isShippingFree: true),
                                    const SizedBox(height: 10), // Increased spacing
                                    Divider(thickness: 1.5, color: Theme.of(context).primaryColor.withOpacity(0.1)),
                                    const SizedBox(height: 10), // Increased spacing
                                    _buildOrderSummaryRow(
                                      'Total',
                                      '\$${cart.formattedPrice(cart.totalAmount)}',
                                      isTotal: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Place Order Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'PLACE ORDER',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build order summary rows
  Widget _buildOrderSummaryRow(String label, String value, {bool isTotal = false, bool isShippingFree = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? Colors.black : Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isShippingFree 
                ? Colors.green.shade600 
                : (isTotal ? Theme.of(context).primaryColor : Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  // Helper method to build progress steps
  Widget _buildProgressStep(int step, String label, bool isActive) {
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
  Widget _buildProgressLine(bool isActive) {
    return Container(
      width: 40,
      height: 2,
      color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade300,
    );
  }
}










































