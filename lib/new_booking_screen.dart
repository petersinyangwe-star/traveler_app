 import 'package:flutter/material.dart';
 import 'package:http/http.dart' as http;
 import 'dart:convert';

 class NewBookingScreen extends StatefulWidget {
   final String token;
   const NewBookingScreen({super.key, required this.token});

   @override
   State<NewBookingScreen> createState() => _NewBookingScreenState();
 }

 class _NewBookingScreenState extends State<NewBookingScreen> {
   final _pickupController = TextEditingController();
   final _dropoffController = TextEditingController();
   final _durationController = TextEditingController(text: '1');

   List<dynamic> _vehicles = [];
   List<dynamic> _routes = [];

   String? _selectedVehicleId;
   String? _selectedRouteId;

   bool _isLoading = true;
   bool _isSubmitting = false;

   double _calculatedPrice = 0.0;
   String _priceUnit = "DAYS";

   @override
   void initState() {
     super.initState();
     _fetchData();
   }

   Future<void> _fetchData() async {
     try {
       final headers = {'Authorization': 'Bearer ${widget.token}'};

       final responses = await Future.wait([
         http.get(Uri.parse('http://localhost:8080/api/vehicles'), headers: headers),
         http.get(Uri.parse('http://localhost:8080/api/routes'), headers: headers),
       ]);

       if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
         setState(() {
           _vehicles = jsonDecode(responses[0].body);
           _routes = jsonDecode(responses[1].body);
         });
       }
     } catch (e) {
       print("Error fetching data: $e");
     } finally {
       if (mounted) setState(() => _isLoading = false);
     }
   }

   void _calculatePrice() {
     if (_selectedVehicleId == null) return;

     final vehicle = _vehicles.firstWhere((v) => v['id'].toString() == _selectedVehicleId);
     final duration = int.tryParse(_durationController.text) ?? 1;

     double price = 0;
     if (_priceUnit == "DAYS" && vehicle['pricePerDayZMW'] != null) {
       price = vehicle['pricePerDayZMW'] * duration;
     } else if (_priceUnit == "HOURS" && vehicle['pricePerHourZMW'] != null) {
       price = vehicle['pricePerHourZMW'] * duration;
     }

     setState(() {
       _calculatedPrice = price.toDouble();
     });
   }

   Future<void> _submitBooking() async {
     if (_selectedVehicleId == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a vehicle')));
       return;
     }

     setState(() => _isSubmitting = true);

     try {
       int routeId;
       final headers = {
         'Content-Type': 'application/json',
         'Authorization': 'Bearer ${widget.token}',
       };

       // 1. If no existing route is selected, create a new one
       if (_selectedRouteId == null) {
         if (_pickupController.text.isEmpty || _dropoffController.text.isEmpty) {
           throw Exception("Please fill in pickup and dropoff locations");
         }

         final routeRes = await http.post(
           Uri.parse('http://localhost:8080/api/routes'),
           headers: headers,
           body: jsonEncode({
             'pickupLocation': _pickupController.text.trim(),
             'dropoffLocation': _dropoffController.text.trim(),
           }),
         );

         if (routeRes.statusCode != 200) throw Exception("Failed to create route");
         routeId = jsonDecode(routeRes.body)['id'];
       } else {
         routeId = int.parse(_selectedRouteId!);
       }

       // 2. Create the booking
       final bookingRes = await http.post(
         Uri.parse('http://localhost:8080/api/bookings'),
         headers: headers,
         body: jsonEncode({
           'routeId': routeId,
           'vehicleId': int.parse(_selectedVehicleId!),
           'duration': int.tryParse(_durationController.text) ?? 1,
           'durationUnit': _priceUnit,
         }),
       );

       if (bookingRes.statusCode == 200) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Booking created successfully!'), backgroundColor: Colors.green),
           );
           Navigator.pop(context, true); // Return true so dashboard refreshes
         }
       } else {
         throw Exception("Failed to create booking");
       }
     } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
         );
       }
     } finally {
       if (mounted) setState(() => _isSubmitting = false);
     }
   }

   @override
   Widget build(BuildContext context) {
     return Scaffold(
       appBar: AppBar(
         title: const Text('New Booking'),
         backgroundColor: const Color(0xFF0D6EFD),
         foregroundColor: Colors.white,
       ),
       body: _isLoading
           ? const Center(child: CircularProgressIndicator())
           : SingleChildScrollView(
               padding: const EdgeInsets.all(20.0),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   // --- Route Section ---
                   const Text("Route", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 10),
                   DropdownButtonFormField<String>(
                     decoration: const InputDecoration(labelText: 'Select Existing Route (Optional)', border: OutlineInputBorder()),
                     items: [
                       const DropdownMenuItem<String>(value: null, child: Text('-- Create New Route --')),
                       ..._routes.map((r) => DropdownMenuItem<String>(
                         value: r['id'].toString(),
                         child: Text("${r['pickupLocation']} → ${r['dropoffLocation']}"),
                       )),
                     ],
                     onChanged: (val) => setState(() => _selectedRouteId = val),
                   ),

                   if (_selectedRouteId == null) ...[
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
                   ],

                   const SizedBox(height: 25),

                   // --- Vehicle & Duration Section ---
                   const Text("Vehicle & Duration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 10),
                   DropdownButtonFormField<String>(
                     decoration: const InputDecoration(labelText: 'Select Vehicle', border: OutlineInputBorder()),
                     items: _vehicles.map((v) => DropdownMenuItem<String>(
                       value: v['id'].toString(),
                       child: Text("${v['make']} ${v['model']} (${v['plateNumber']})"),
                     )).toList(),
                     onChanged: (val) {
                       setState(() => _selectedVehicleId = val);
                       _calculatePrice();
                     },
                   ),
                   const SizedBox(height: 15),
                   Row(
                     children: [
                       Expanded(
                         child: TextField(
                           controller: _durationController,
                           keyboardType: TextInputType.number,
                           decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
                           onChanged: (val) => _calculatePrice(),
                         ),
                       ),
                       const SizedBox(width: 10),
                       Expanded(
                         child: DropdownButtonFormField<String>(
                           value: _priceUnit,
                           decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                           items: const [
                             DropdownMenuItem(value: "DAYS", child: Text("Days")),
                             DropdownMenuItem(value: "HOURS", child: Text("Hours")),
                           ],
                           onChanged: (val) {
                             setState(() => _priceUnit = val!);
                             _calculatePrice();
                           },
                         ),
                       ),
                     ],
                   ),

                   const SizedBox(height: 20),
                   Container(
                     padding: const EdgeInsets.all(15),
                     decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         const Text("Estimated Total:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                         Text("K${_calculatedPrice.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D6EFD))),
                       ],
                     ),
                   ),

                   const SizedBox(height: 30),
                   SizedBox(
                     width: double.infinity,
                     height: 50,
                     child: ElevatedButton(
                       onPressed: _isSubmitting ? null : _submitBooking,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: const Color(0xFF0D6EFD),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                       ),
                       child: _isSubmitting
                           ? const CircularProgressIndicator(color: Colors.white)
                           : const Text('CREATE BOOKING', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                     ),
                   ),
                 ],
               ),
             ),
     );
   }
 }