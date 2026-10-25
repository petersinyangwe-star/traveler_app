 import 'package:flutter/material.dart';
 import 'package:http/http.dart' as http;
 import 'dart:convert';
 import 'glass_card.dart';

 class RegisterScreen extends StatefulWidget {
   const RegisterScreen({super.key});

   @override
   State<RegisterScreen> createState() => _RegisterScreenState();
 }

 class _RegisterScreenState extends State<RegisterScreen> {
   final _usernameController = TextEditingController();
   final _emailController = TextEditingController();
   final _passwordController = TextEditingController();
   final _phoneController = TextEditingController();
   final _nrcController = TextEditingController();
   final _passportController = TextEditingController();

   // Customer fields
   final _locationController = TextEditingController();
   final _reasonController = TextEditingController();
   final _preferredDurationController = TextEditingController();
   String _durationUnit = 'HOURS';
   String _preferredCurrency = 'ZMW';

   // Driver fields
   final _licenseController = TextEditingController();
   final _experienceController = TextEditingController();

   String _selectedRole = 'CUSTOMER';
   bool _isLoading = false;

   Future<void> _register() async {
     if (_usernameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
       return;
     }

     setState(() => _isLoading = true);

     try {
       final url = Uri.parse('http://localhost:8080/api/auth/register');

       final Map<String, dynamic> body = {
         'username': _usernameController.text.trim(),
         'email': _emailController.text.trim(),
         'password': _passwordController.text.trim(),
         'phone': _phoneController.text.trim(),
         'role': _selectedRole,
         'nrcNumber': _nrcController.text.trim(),
       };

       // Only add passport if it's NOT empty
       if (_passportController.text.trim().isNotEmpty) {
         body['passportNumber'] = _passportController.text.trim();
       }
       if (_selectedRole == 'CUSTOMER') {
         body['location'] = _locationController.text.trim();
         body['reasonForHiring'] = _reasonController.text.trim();
         body['preferredDuration'] = int.tryParse(_preferredDurationController.text) ?? 0;
         body['durationUnit'] = _durationUnit;
         body['preferredCurrency'] = _preferredCurrency;
       } else if (_selectedRole == 'DRIVER') {
         body['licenseNumber'] = _licenseController.text.trim();
         body['yearsOfExperience'] = int.tryParse(_experienceController.text) ?? 0;
       }

       final response = await http.post(
         url,
         headers: {'Content-Type': 'application/json'},
         body: jsonEncode(body),
       );

       if (response.statusCode == 200) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Registered! Please wait for admin approval.'), backgroundColor: Colors.green),
           );
           Navigator.pop(context);
         }
       } else {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
         }
       }
     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
     } finally {
       if (mounted) setState(() => _isLoading = false);
     }
   }

   @override
   Widget build(BuildContext context) {
     return Scaffold(
       body: Container(
         decoration: const BoxDecoration(
           image: DecorationImage(
             image: NetworkImage('https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?q=80&w=1000&auto=format&fit=crop'),
             fit: BoxFit.cover,
           ),
         ),
         child: SafeArea(
           child: SingleChildScrollView(
             padding: const EdgeInsets.all(24.0),
             child: Column(
               children: [
                 const SizedBox(height: 20),
                 GlassCard(
                   child: Padding(
                     padding: const EdgeInsets.all(20.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         // Header
                         const Center(
                           child: Column(
                             children: [
                               Icon(Icons.directions_car, size: 50, color: Colors.white),
                               SizedBox(height: 10),
                               Text("TRAVELER", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                               SizedBox(height: 5),
                               Text("Create an account", style: TextStyle(color: Colors.white70)),
                               SizedBox(height: 20),
                             ],
                           ),
                         ),

                         // Role Dropdown
                         const Text("Role", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                         const SizedBox(height: 8),
                         DropdownButtonFormField<String>(
                           value: _selectedRole,
                           dropdownColor: const Color(0xFF1C2541),
                           style: const TextStyle(color: Colors.white),
                           decoration: InputDecoration(
                             filled: true,
                             fillColor: Colors.white.withOpacity(0.1),
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                           ),
                           items: const [
                             DropdownMenuItem(value: 'CUSTOMER', child: Text('Customer')),
                             DropdownMenuItem(value: 'DRIVER', child: Text('Driver')),
                           ],
                           onChanged: (val) => setState(() => _selectedRole = val!),
                         ),
                         const SizedBox(height: 20),

                         // Common Fields
                         _buildGlassTextField(_usernameController, 'Username'),
                         const SizedBox(height: 15),
                         _buildGlassTextField(_emailController, 'Email', keyboardType: TextInputType.emailAddress),
                         const SizedBox(height: 15),
                         _buildGlassTextField(_passwordController, 'Password', obscureText: true),
                         const SizedBox(height: 15),
                         _buildGlassTextField(_phoneController, 'Phone', keyboardType: TextInputType.phone),

                         const SizedBox(height: 25),

                         // Identity Verification
                         const Text("IDENTITY VERIFICATION", style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                         const SizedBox(height: 10),
                         _buildGlassTextField(_nrcController, 'NRC Number'),
                         const SizedBox(height: 15),
                         _buildGlassTextField(_passportController, 'Passport Number (Optional)'),

                         const SizedBox(height: 25),

                         // Conditional Sections
                         if (_selectedRole == 'CUSTOMER') ...[
                           const Text("CUSTOMER PREFERENCES", style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                           const SizedBox(height: 10),
                           _buildGlassTextField(_locationController, 'Location'),
                           const SizedBox(height: 15),
                           _buildGlassTextField(_reasonController, 'Reason for hiring'),
                           const SizedBox(height: 15),
                           Row(
                             children: [
                               Expanded(child: _buildGlassTextField(_preferredDurationController, 'Duration', keyboardType: TextInputType.number)),
                               const SizedBox(width: 10),
                               Expanded(
                                 child: DropdownButtonFormField<String>(
                                   value: _durationUnit,
                                   dropdownColor: const Color(0xFF1C2541),
                                   style: const TextStyle(color: Colors.white),
                                   decoration: InputDecoration(
                                     filled: true,
                                     fillColor: Colors.white.withOpacity(0.1),
                                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                   ),
                                   items: const [
                                     DropdownMenuItem(value: 'HOURS', child: Text('Hours')),
                                     DropdownMenuItem(value: 'DAYS', child: Text('Days')),
                                   ],
                                   onChanged: (val) => setState(() => _durationUnit = val!),
                                 ),
                               ),
                             ],
                           ),
                         ],

                         if (_selectedRole == 'DRIVER') ...[
                           const Text("DRIVER DETAILS", style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                           const SizedBox(height: 10),
                           _buildGlassTextField(_licenseController, 'License Number'),
                           const SizedBox(height: 15),
                           _buildGlassTextField(_experienceController, 'Years of Experience', keyboardType: TextInputType.number),
                         ],

                         const SizedBox(height: 30),

                         // Submit Button
                         SizedBox(
                           width: double.infinity,
                           height: 55,
                           child: ElevatedButton(
                             onPressed: _isLoading ? null : _register,
                             style: ElevatedButton.styleFrom(
                               backgroundColor: const Color(0xFF00C853),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                             ),
                             child: _isLoading
                                 ? const CircularProgressIndicator(color: Colors.white)
                                 : const Text('Create account', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                           ),
                         ),
                       ],
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

   Widget _buildGlassTextField(TextEditingController controller, String label, {bool obscureText = false, TextInputType? keyboardType}) {
     return TextField(
       controller: controller,
       obscureText: obscureText,
       keyboardType: keyboardType,
       style: const TextStyle(color: Colors.white),
       decoration: InputDecoration(
         hintText: label, // 🚀 Changed from labelText to hintText
         hintStyle: const TextStyle(color: Colors.white70),
         filled: true,
         fillColor: Colors.white.withOpacity(0.1),
         border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
       ),
     );
   }
 }