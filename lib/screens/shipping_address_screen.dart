import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ShippingAddressScreen extends StatefulWidget {
  const ShippingAddressScreen({Key? key}) : super(key: key);

  @override
  State<ShippingAddressScreen> createState() => _ShippingAddressScreenState();
}

class _ShippingAddressScreenState extends State<ShippingAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedWilaya;
  bool _isLoading = false;

  // Updated list with properly encoded strings
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

  @override
  void initState() {
    super.initState();
    
    // Get user data synchronously first if available
    final userData = Provider.of<AuthProvider>(context, listen: false).userData;
    if (userData != null) {
      _addressController.text = userData['address'] ?? '';
      _phoneController.text = userData['phone'] ?? '';
      
      // Normalize the wilaya value to match the list
      String? wilaya = userData['wilaya'];
      if (wilaya != null && wilaya.isNotEmpty) {
        // Find the matching wilaya from the list, ignoring diacritics
        _selectedWilaya = _wilayas.firstWhere(
          (w) => w.toLowerCase().replaceAll(RegExp(r'[éèêë]'), 'e')
                 == wilaya.toLowerCase().replaceAll(RegExp(r'[éèêë]'), 'e'),
          orElse: () => wilaya,
        );
      }
    }
    
    // Then refresh data asynchronously
    Future.microtask(() async {
      await Provider.of<AuthProvider>(context, listen: false).getUserData();
      _loadShippingAddress();
    });
  }

  Future<void> _loadShippingAddress() async {
    final userData = Provider.of<AuthProvider>(context, listen: false).userData;
    if (userData != null) {
      print('Loading shipping address from user data: $userData'); // Debug log
      print('Address: ${userData['address']}'); // Debug log
      print('Wilaya: ${userData['wilaya']}'); // Debug log
      print('Phone: ${userData['phone']}'); // Debug log
      
      setState(() {
        _addressController.text = userData['address'] ?? '';
        _phoneController.text = userData['phone'] ?? '';
        
        // Normalize the wilaya value to match the list
        String? wilaya = userData['wilaya'];
        if (wilaya != null && wilaya.isNotEmpty) {
          print('Found wilaya in user data: $wilaya'); // Debug log
          // Find the matching wilaya from the list, ignoring diacritics
          _selectedWilaya = _wilayas.firstWhere(
            (w) => w.toLowerCase().replaceAll(RegExp(r'[éèêë]'), 'e')
                   == wilaya.toLowerCase().replaceAll(RegExp(r'[éèêë]'), 'e'),
            orElse: () => wilaya,
          );
          print('Selected wilaya: $_selectedWilaya'); // Debug log
        } else {
          print('No wilaya found in user data'); // Debug log
        }
      });
    } else {
      print('No user data available'); // Debug log
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveShippingAddress() async {
    if (_formKey.currentState!.validate()) {
      // Check if wilaya is selected
      if (_selectedWilaya == null || _selectedWilaya!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a wilaya'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        print('Saving shipping address: address=${_addressController.text}, wilaya=$_selectedWilaya, phone=${_phoneController.text}'); // Debug log
        
        await Provider.of<AuthProvider>(context, listen: false).updateShippingAddress(
          address: _addressController.text.trim(),
          wilaya: _selectedWilaya!,
          phone: _phoneController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shipping address updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Refresh user data to ensure we have the latest
          await Provider.of<AuthProvider>(context, listen: false).getUserData();
          
          Navigator.of(context).pop();
        }
      } catch (e) {
        print('Error saving shipping address: $e'); // Debug log
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update shipping address: ${e.toString().replaceAll('Exception:', '')}'),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipping Address'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedWilaya,
                  decoration: InputDecoration(
                    labelText: 'Wilaya',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.location_city_outlined),
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
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Detailed Address',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.home_outlined),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your address';
                    }
                    if (value.length < 10) {
                      return 'Please enter a more detailed address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveShippingAddress,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Save Address',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}







