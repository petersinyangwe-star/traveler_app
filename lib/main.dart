import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'glass_card.dart';
import 'new_booking_screen.dart';
import 'register_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'delivery_screen.dart';
import 'package:google_fonts/google_fonts.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const TravelerApp());
}

class TravelerApp extends StatelessWidget {
  const TravelerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Traveler Car Hire',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00A8FF), // Electric Blue
              brightness: Brightness.dark,       //  Force Dark Mode as default
            ),
            useMaterial3: true,
            fontFamily: GoogleFonts.poppins().fontFamily,
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            scaffoldBackgroundColor: const Color(0xFF0A1128), // Deep Navy
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.white,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF1C2541), // Darker input field
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00A8FF), width: 2), // Glow on focus
              ),
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0D6EFD),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            fontFamily: GoogleFonts.poppins().fontFamily,
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            scaffoldBackgroundColor: const Color(0xFF121212),
          ),
          themeMode: currentMode,
          home: const LoginScreen(),
        );
      },
    );
  }
}

// ============================================================
// LOGIN SCREEN
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    // 1. Request permission (especially for iOS)
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    }

    // 2. Get the device token
    String? token = await FirebaseMessaging.instance.getToken();
    print("🔥 FCM TOKEN: $token"); //  Copy this from your console!

    // 3. Listen for foreground messages
    // 3. Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        // SHOW A SNACKBAR
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.notification!.title ?? 'New Notification',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(message.notification!.body ?? ''),
                ],
              ),
              backgroundColor: Colors.blue[800],
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('http://localhost:8080/api/auth/login');
      final response = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (context) => CustomerDashboard(
              username: data['username'],
              role: data['role'],
              token: data['token'],
            ),
          ));


          // Send FCM Token to Backend
          String? token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await http.post(
              Uri.parse('http://localhost:8080/api/users/save-fcm-token'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${data['token']}',
              },
              body: jsonEncode({'fcmToken': token}),
            );
          }

        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid credentials')));
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
      backgroundColor: const Color(0xFF0A1128), // Deep Navy
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // 🚀 Logo with a glow effect
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00A8FF).withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Image.asset('assets/logo.png', height: 120),
                ),
                const SizedBox(height: 20),
                const Text(
                  'TRAVELER',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Car hire and delivery, redefined.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 40),

                // 🚀 The Login Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A33), // Slightly lighter navy for the card
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Sign in',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 30),

                      // Username Field
                      TextField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          labelStyle: TextStyle(color: Colors.grey),
                          prefixIcon: Icon(Icons.person, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A8FF), // Electric blue
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 10,
                            shadowColor: const Color(0xFF00A8FF).withOpacity(0.5),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                            'LOGIN',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),

                      // Sign Up Link
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                        },
                        child: const Text(
                          "Don't have an account? Sign Up",
                          style: TextStyle(color: Color(0xFF00A8FF)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTextField(TextEditingController controller, String label, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText ? _obscurePassword : false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        suffixIcon: obscureText
            ? IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.white70,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        )
            : null,
      ),
    );
  }

}

// ============================================================
// CUSTOMER DASHBOARD
// ============================================================
class CustomerDashboard extends StatefulWidget {
  final String username;
  final String role;
  final String token;

  const CustomerDashboard({super.key, required this.username, required this.role, required this.token});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentIndex = 0;
  List<dynamic> _bookings = [];
  List<dynamic> _vehicles = [];
  List<dynamic> _routes = [];
  String _avatarUrl = "";
  bool _isLoading = true;
  dynamic _selectedRoute;
  List<LatLng> _currentRoadPath = [];
  List<int> _favorites = [];


  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final headers = {'Authorization': 'Bearer ${widget.token}'};

      final results = await Future.wait([
        http.get(Uri.parse('http://localhost:8080/api/users/me'), headers: headers),
        http.get(Uri.parse('http://localhost:8080/api/bookings'), headers: headers),
        http.get(Uri.parse('http://localhost:8080/api/vehicles'), headers: headers),
        http.get(Uri.parse('http://localhost:8080/api/routes'), headers: headers),
      ]);

      if (results[0].statusCode == 200) {
        setState(() => _avatarUrl = jsonDecode(results[0].body)['avatarUrl'] ?? "");
      }
      if (results[1].statusCode == 200) {
        setState(() => _bookings = jsonDecode(results[1].body));
      }
      if (results[2].statusCode == 200) {
        setState(() => _vehicles = jsonDecode(results[2].body));
      }
      if (results[3].statusCode == 200) {
        setState(() => _routes = jsonDecode(results[3].body));
      }
    } catch (e) {
      print(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HOME TAB ---
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            elevation: 5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage("http://localhost:8080$_avatarUrl") : null,
                    child: _avatarUrl.isEmpty ? Text(widget.username[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.white)) : null,
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back,', style: TextStyle(color: Colors.grey[600])),
                      Text(widget.username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          //  STAT CARDS
          Row(
            children: [
              _buildStatCard("Vehicles", "${_vehicles.length}", Icons.directions_car, [const Color(0xFF667EEA), const Color(0xFF764BA2)]),
              const SizedBox(width: 15),
              _buildStatCard("Bookings", "${_bookings.length}", Icons.calendar_today, [const Color(0xFFF093FB), const Color(0xFFF5576C)]),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildStatCard("Routes", "${_routes.length}", Icons.alt_route, [const Color(0xFF4FACFE), const Color(0xFF00F2FE)]),
              const SizedBox(width: 15),
              _buildStatCard("Earnings", "K0", Icons.attach_money, [const Color(0xFF43E97B), const Color(0xFF38F9D7)]),
            ],
          ),
          const SizedBox(height: 20),

          //  NEW BOOKING BUTTON
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => NewBookingScreen(token: widget.token)));
                if (result == true) _fetchData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6EFD),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 5,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.white),
                  SizedBox(width: 10),
                  Text('New Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Recent Bookings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _bookings.isEmpty
              ? const Text("No bookings yet.")
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _bookings.length > 3 ? 3 : _bookings.length,
            itemBuilder: (context, i) {
              final b = _bookings[i];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Color(0xFF0D6EFD)),
                  title: Text('${b['route']['pickupLocation']} → ${b['route']['dropoffLocation']}'),
                  subtitle: Text('Booking #${b['id']} - ${b['status']}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, List<Color> gradient) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: gradient.first.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 15),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 5),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9))),
          ],
        ),
      ),
    );
  }

  // --- BOOKINGS TAB ---
  Widget _buildBookingsTab() {
    if (_bookings.isEmpty) return const Center(child: Text("No bookings yet."));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookings.length,
      itemBuilder: (context, i) {
        final b = _bookings[i];
        Color statusColor = b['status'] == 'COMPLETED' ? Colors.green : (b['status'] == 'CANCELLED' ? Colors.red : Colors.blue);
        bool isPaid = b['paymentStatus'] == 'PAID';
        bool isCompleted = b['status'] == 'COMPLETED';
        bool isInProgress = b['status'] == 'IN_PROGRESS';
        bool isCancelled = b['status'] == 'CANCELLED';

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: const EdgeInsets.only(bottom: 15),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Booking #${b['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                      child: Text(b['status'], style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Details
                Row(children: [const Icon(Icons.location_on, size: 16, color: Colors.grey), const SizedBox(width: 5), Expanded(child: Text('${b['route']['pickupLocation']} → ${b['route']['dropoffLocation']}'))]),
                const SizedBox(height: 5),
                Row(children: [const Icon(Icons.directions_car, size: 16, color: Colors.grey), const SizedBox(width: 5), Text(b['vehicle']['plateNumber'])]),
                const SizedBox(height: 15),

                // Price & Payment Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('K${b['totalPrice']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: isPaid ? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(5)),
                      child: Text(isPaid ? 'PAID' : 'UNPAID', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),

                // 🚀 1. TRACK BUTTON (Only for IN_PROGRESS)
                if (isInProgress) ...[
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLiveTrackingModal(b),
                      icon: const Icon(Icons.map, size: 16, color: Colors.blue),
                      label: const Text('Track Driver', style: TextStyle(color: Colors.blue)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue)),
                    ),
                  ),
                ],

                // 🚀 2. RATE + INVOICE BUTTONS (For COMPLETED bookings)
                if (isCompleted) ...[
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Rate Button
                      OutlinedButton.icon(
                        onPressed: () => _showRatingDialog(b),
                        icon: const Icon(Icons.star, size: 16, color: Colors.orange),
                        label: const Text('Rate', style: TextStyle(color: Colors.orange)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
                      ),
                      const SizedBox(width: 10),
                      // Invoice Button (Works for both PAID and UNPAID completions)
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading invoice...'), duration: Duration(seconds: 1)));
                            final url = Uri.parse('http://localhost:8080/api/bookings/${b['id']}/invoice');
                            final response = await http.get(url, headers: {'Authorization': 'Bearer ${widget.token}'});
                            if (response.statusCode == 200) {
                              final dir = await getTemporaryDirectory();
                              final file = File('${dir.path}/invoice_${b['id']}.pdf');
                              await file.writeAsBytes(response.bodyBytes);
                              await OpenFile.open(file.path);
                            } else {
                              throw Exception("Failed");
                            }
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                        icon: const Icon(Icons.file_download, size: 16, color: Color(0xFF0D6EFD)),
                        label: const Text('Invoice', style: TextStyle(color: Color(0xFF0D6EFD))),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF0D6EFD))),
                      ),
                    ],
                  ),
                ],
                //  3. PAY NOW BUTTON (For UNPAID bookings that are not CANCELLED)
                if (!isPaid && !isCancelled) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final result = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Pay for Booking'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("Select Payment Method"),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () => Navigator.pop(context, 'CARD'),
                                  icon: const Icon(Icons.credit_card),
                                  label: const Text('Credit / Debit Card'),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  onPressed: () => Navigator.pop(context, 'MOBILE_MONEY'),
                                  icon: const Icon(Icons.phone_android),
                                  label: const Text('Mobile Money'),
                                ),
                              ],
                            ),
                          ),
                        );

                        if (result == null) return;

                        try {
                          final response = await http.post(
                            Uri.parse('http://localhost:8080/api/bookings/${b['id']}/pay'),
                            headers: {
                              'Content-Type': 'application/json',
                              'Authorization': 'Bearer ${widget.token}',
                            },
                            body: jsonEncode({'paymentMethod': result}),
                          );

                          if (response.statusCode == 200) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Payment Successful!'), backgroundColor: Colors.green),
                              );
                              _fetchData(); // Refresh the list
                            }
                          } else {
                            // Parse the error message from the backend
                            final errorData = jsonDecode(response.body);
                            throw Exception(errorData['message'] ?? "Payment failed");
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                            _fetchData(); // Refresh the list even on error to sync status
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6EFD)),
                      child: const Text('Pay Now', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // --- VEHICLES TAB ---
  Widget _buildVehiclesTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchData(); //  Reload data from the server
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          childAspectRatio: 1.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 15,
        ),
        itemCount: _vehicles.length,
        itemBuilder: (context, i) {
          final v = _vehicles[i];
          return Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 5,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Vehicle Image
                      v['imageUrl'] != null && v['imageUrl'].toString().isNotEmpty
                          ? Image.network(
                        v['imageUrl'].toString().startsWith('http')
                            ? v['imageUrl']
                            : "http://localhost:8080${v['imageUrl']}",
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[300],
                          child: const Center(child: Icon(Icons.directions_car, size: 50)),
                        ),
                      )
                          : Container(
                        color: Colors.grey[300],
                        child: const Center(child: Icon(Icons.directions_car, size: 50)),
                      ),

                      //  Favorite Icon (Tappable)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_favorites.contains(v['id'])) {
                                _favorites.remove(v['id']);
                              } else {
                                _favorites.add(v['id']);
                              }
                            });
                          },
                          child: CircleAvatar(
                            backgroundColor: Colors.white.withOpacity(0.9),
                            radius: 18,
                            child: Icon(
                              _favorites.contains(v['id']) ? Icons.favorite : Icons.favorite_border,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                      ),

                      //  Status Badge
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: v['status'] == 'AVAILABLE'
                                ? Colors.green
                                : (v['status'] == 'IN_USE' ? Colors.orange : Colors.red),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            v['status'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${v['make']} ${v['model']}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("K${v['pricePerDayZMW']}/day",
                              style: const TextStyle(color: Color(0xFF0D6EFD), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text("${v['plateNumber']} • ${v['capacity']} seats",
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NewBookingScreen(token: widget.token),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D6EFD),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Rent Now', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  // --- ROUTES TAB ---
  Widget _buildRoutesTab() {
    if (_routes.isEmpty) return const Center(child: Text("No routes available."));

    final validRoutes = _routes.where((r) {
      if (r['pickupLat'] == null || r['pickupLng'] == null) return false;
      double lat = (r['pickupLat'] as num).toDouble();
      double lng = (r['pickupLng'] as num).toDouble();
      return lat >= -18.0 && lat <= -8.0 && lng >= 22.0 && lng <= 34.0;
    }).toList();

    if (validRoutes.isEmpty) return const Center(child: Text("No valid routes found."));

    // IF A ROUTE IS SELECTED, SHOW FULL SCREEN MAP
    if (_selectedRoute != null) {
      final route = _selectedRoute;
      final pickup = LatLng((route['pickupLat'] as num).toDouble(), (route['pickupLng'] as num).toDouble());
      final dropoff = LatLng((route['dropoffLat'] as num).toDouble(), (route['dropoffLng'] as num).toDouble());

      return Scaffold(
        appBar: AppBar(
          title: Text("${route['pickupLocation']} → ${route['dropoffLocation']}"),
          backgroundColor: const Color(0xFF0D6EFD),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() { _selectedRoute = null; _currentRoadPath = []; }),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _currentRoadPath.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : FlutterMap(
                options: MapOptions(
                  initialCenter: pickup,
                  initialZoom: 12.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.travelerapp',
                  ),
                  MarkerLayer(markers: [
                    Marker(point: pickup, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.blue, size: 40)),
                    Marker(point: dropoff, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.green, size: 40)),
                  ]),
                  PolylineLayer(
                    polylines: [
                      Polyline(points: _currentRoadPath, color: Colors.blue, strokeWidth: 5.0),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Distance: ${route['distanceKm']} km", style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("Duration: ${route['estimatedDurationMin']} min", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    //  IF NO ROUTE IS SELECTED, SHOW THE LIST
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: validRoutes.length,
      itemBuilder: (context, i) {
        final r = validRoutes[i];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: const EdgeInsets.only(bottom: 15),
          child: ListTile(
            onTap: () => _selectRoute(r),
            leading: const Icon(Icons.location_on, color: Color(0xFF0D6EFD)),
            title: Text("${r['pickupLocation']} → ${r['dropoffLocation']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Distance: ${r['distanceKm']} km • ${r['estimatedDurationMin']} min"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        );
      },
    );
  }

  //  Function to fetch the real road path
  Future<void> _selectRoute(dynamic route) async {
    setState(() {
      _selectedRoute = route;
      _currentRoadPath = [];
    });

    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${route['pickupLng']},${route['pickupLat']};${route['dropoffLng']},${route['dropoffLat']}?overview=full&geometries=geojson');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final geometry = jsonDecode(response.body)['routes'][0]['geometry']['coordinates'] as List;
        setState(() {
          _currentRoadPath = geometry.map((coord) => LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble())).toList();
        });
      } else {
        throw Exception("Failed to load road path");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
      print("ROAD PATH ERROR: $e");
    }
  }



  // --- DELIVERIES TAB ---
  Widget _buildDeliveriesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Deliveries', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeliveryScreen(token: widget.token),
                    ),
                  );
                  if (result == true) {
                    _fetchData(); // Refresh data if a delivery was created
                  }
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Send Package', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6EFD)),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Placeholder for the deliveries list
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: const Padding(
              padding: EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("No deliveries yet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 5),
                  Text("Tap 'Send Package' to create one.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // --- PROFILE TAB ---
  Widget _buildProfileTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _pickAndUploadImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage("http://localhost:8080$_avatarUrl") : null,
                  child: _avatarUrl.isEmpty ? const Icon(Icons.person, size: 50) : null,
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Color(0xFF0D6EFD), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(widget.username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(widget.role, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 20),

          //  CONTACT SUPPORT SECTION
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text("Need Help?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      //  Call Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          final Uri phoneUri = Uri(scheme: 'tel', path: '260975307985'); // Replace with your number
                          try {
                            await launchUrl(phoneUri);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open dialer: $e')));
                          }
                        },
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      ),

                      //  WhatsApp Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          final Uri whatsappUri = Uri.parse('https://wa.me/260975307985?text=Hello%20Traveler%20Support%20Team,%20I%20need%20help%20with%20the%20following%20:'); // Replace with your number
                          try {
                            await launchUrl(whatsappUri);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open WhatsApp: $e')));
                          }
                        },
                        icon: const Icon(Icons.chat, size: 18),
                        label: const Text('WhatsApp'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          //  Change Password Button
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => _showChangePasswordDialog(),
            icon: const Icon(Icons.lock_reset),
            label: const Text('Change Password'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D6EFD),
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 45),
            ),
          ),
          const SizedBox(height: 20),

          // Dark Mode Switch
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, currentMode, child) {
              return SwitchListTile(
                title: const Text("Dark Mode"),
                value: currentMode == ThemeMode.dark,
                onChanged: (bool value) {
                  themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                },
                secondary: const Icon(Icons.dark_mode),
              );
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);
    try {
      final request = http.MultipartRequest('POST', Uri.parse('http://localhost:8080/api/users/upload-avatar'));
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.files.add(await http.MultipartFile.fromPath('file', pickedFile.path));
      final response = await request.send();
      if (response.statusCode == 200) {
        final data = jsonDecode(await response.stream.bytesToString());
        setState(() { _avatarUrl = data['avatarUrl']; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.green));
      } else {
        throw Exception("Failed");
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRatingDialog(dynamic booking) {
    int driverScore = 0, vehicleScore = 0;
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Rate your booking'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('How was the driver?'),
                    Row(children: List.generate(5, (index) => IconButton(icon: Icon(index < driverScore ? Icons.star : Icons.star_border, color: Colors.orange), onPressed: () => setModalState(() => driverScore = index + 1)))),
                    const SizedBox(height: 10),
                    const Text('Vehicle comfort?'),
                    Row(children: List.generate(5, (index) => IconButton(icon: Icon(index < vehicleScore ? Icons.star : Icons.star_border, color: Colors.orange), onPressed: () => setModalState(() => vehicleScore = index + 1)))),
                    const SizedBox(height: 10),
                    TextField(controller: commentController, decoration: const InputDecoration(labelText: 'Comment (optional)', border: OutlineInputBorder()), maxLines: 2),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (driverScore == 0 || vehicleScore == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide both ratings')));
                      return;
                    }
                    try {
                      final res = await http.post(
                        Uri.parse('http://localhost:8080/api/ratings'),
                        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
                        body: jsonEncode({'bookingId': booking['id'], 'driverScore': driverScore, 'vehicleScore': vehicleScore, 'comment': commentController.text.trim()}),
                      );
                      if (res.statusCode == 200) {
                        if (mounted) { Navigator.pop(context); _fetchData(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rating submitted!'), backgroundColor: Colors.green)); }
                      } else {
                        throw Exception("Failed");
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLiveTrackingModal(dynamic booking) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double currentLat = booking['currentLat'] ?? (booking['route']['pickupLat'] ?? -15.3875);
            double currentLng = booking['currentLng'] ?? (booking['route']['pickupLng'] ?? 28.3228);
            String status = booking['status'];

            Future<void> fetchLocation() async {
              try {
                final res = await http.get(Uri.parse('http://localhost:8080/api/bookings/${booking['id']}/location'), headers: {'Authorization': 'Bearer ${widget.token}'});
                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body);
                  if (mounted) {
                    setModalState(() {
                      currentLat = data['currentLat'] ?? currentLat;
                      currentLng = data['currentLng'] ?? currentLng;
                      status = data['status'] ?? status;
                    });
                  }
                }
              } catch (e) { print(e); }
            }

            final timer = Stream.periodic(const Duration(seconds: 3)).listen((_) => fetchLocation());

            return AlertDialog(
              title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Live Tracking'), IconButton(icon: const Icon(Icons.close), onPressed: () { timer.cancel(); Navigator.pop(context); })]),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    Expanded(
                      child: FlutterMap(
                        options: MapOptions(initialCenter: LatLng(currentLat, currentLng), initialZoom: 14.0),
                        children: [
                          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.traveler_app'),
                          MarkerLayer(markers: [
                            Marker(point: LatLng(currentLat, currentLng), width: 50, height: 50, child: const Icon(Icons.local_shipping, color: Colors.blue, size: 50)),
                            if (booking['route']['pickupLat'] != null) Marker(point: LatLng(booking['route']['pickupLat'], booking['route']['pickupLng']), width: 30, height: 30, child: const Icon(Icons.location_on, color: Colors.green, size: 30)),
                            if (booking['route']['dropoffLat'] != null) Marker(point: LatLng(booking['route']['dropoffLat'], booking['route']['dropoffLng']), width: 30, height: 30, child: const Icon(Icons.location_on, color: Colors.red, size: 30)),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Status:", style: TextStyle(fontWeight: FontWeight.bold)), Text(status, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))])),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final List<Widget> pages = [
      _buildHomeTab(),
      _buildBookingsTab(),
      _buildVehiclesTab(),
      _buildRoutesTab(),
      _buildDeliveriesTab(),
      _buildProfileTab(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('Traveler App'), backgroundColor: const Color(0xFF0D6EFD), foregroundColor: Colors.white),
      body: pages[_currentIndex],
      extendBody: true,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
                //  Refresh data when switching to Vehicles tab
                if (index == 2) {
                  _fetchData();
                }
              },
              selectedItemColor: const Color(0xFF0D6EFD),
              unselectedItemColor: Colors.grey,
              selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 10),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.calendar_today_rounded), label: 'Bookings'),
                BottomNavigationBarItem(icon: Icon(Icons.directions_car_rounded), label: 'Vehicles'),
                BottomNavigationBarItem(icon: Icon(Icons.alt_route_rounded), label: 'Routes'),
                BottomNavigationBarItem(icon: Icon(Icons.inbox_rounded), label: 'Deliveries'),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //  CHANGE PASSWORD DIALOG
  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setModalState(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: newController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setModalState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (currentController.text.isEmpty || newController.text.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New password must be at least 6 characters')));
                      return;
                    }
                    try {
                      final res = await http.post(
                        Uri.parse('http://localhost:8080/api/users/change-password'),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer ${widget.token}',
                        },
                        body: jsonEncode({
                          'currentPassword': currentController.text,
                          'newPassword': newController.text,
                        }),
                      );
                      if (res.statusCode == 200) {
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated!'), backgroundColor: Colors.green));
                        }
                      } else {
                        throw Exception(res.body);
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

}