import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeliveryScreen extends StatefulWidget {
  final String token;
  const DeliveryScreen({super.key, required this.token});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _packageController = TextEditingController();
  final _weightController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitDelivery() async {
    if (_pickupController.text.isEmpty || _dropoffController.text.isEmpty || _packageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/deliveries/standalone'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'pickup': _pickupController.text.trim(),
          'dropoff': _dropoffController.text.trim(),
          'description': _packageController.text.trim(),
          'weight': double.tryParse(_weightController.text) ?? 0.0,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Delivery created successfully!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception("Failed to create delivery: ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Package'),
        backgroundColor: const Color(0xFF0D6EFD),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Package Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: _packageController,
              decoration: const InputDecoration(labelText: 'Package Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 25),

            const Text("Locations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: _pickupController,
              decoration: const InputDecoration(labelText: 'Pickup Location', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _dropoffController,
              decoration: const InputDecoration(labelText: 'Dropoff Location', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_off)),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitDelivery,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6EFD)),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SEND PACKAGE', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}