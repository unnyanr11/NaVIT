import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'indoor_navigation_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late GoogleMapController mapController;
  LatLng _initialPosition = LatLng(28.6139, 77.2090); // Default location (Delhi)
  Position? _currentPosition;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // Function to get current location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enable location services')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = position;
      _initialPosition = LatLng(position.latitude, position.longitude);
      _addMarker(position);
      _addCircle(position);
    });
  }

  // Function to add a marker at the current location
  void _addMarker(Position position) {
    final marker = Marker(
      markerId: MarkerId('current_location'),
      position: LatLng(position.latitude, position.longitude),
      infoWindow: InfoWindow(title: 'Current Location'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    );
    setState(() {
      _markers.clear(); // Clear existing markers
      _markers.add(marker);
    });
  }

  // Function to add a circle around the current location
  void _addCircle(Position position) {
    final circle = Circle(
      circleId: CircleId('current_location_circle'),
      center: LatLng(position.latitude, position.longitude),
      radius: 100, // Radius in meters
      fillColor: Colors.blue.withOpacity(0.2),
      strokeColor: Colors.blue,
      strokeWidth: 2,
    );
    setState(() {
      _circles.clear(); // Clear existing circles
      _circles.add(circle);
    });
  }

  // Function to move camera to current location
  void _moveCameraToCurrentLocation() {
    if (_currentPosition != null) {
      mapController.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 17.0, // Zoom level
        ),
      ));
      _addMarker(_currentPosition!);
      _addCircle(_currentPosition!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Campus Navigation'),
      ),
      body: Stack(
        children: <Widget>[
          // Google Map widget
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 14.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            circles: _circles,
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: TextField(
              onTap: () {
                // Navigate to Search screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SearchScreen()),
                );
              },
              decoration: InputDecoration(
                hintText: 'Search...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _moveCameraToCurrentLocation, // Move camera to current location
              child: Icon(Icons.my_location),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo widget
                  Image.asset(
                    'assets/logo.png', // Replace with your logo's path
                    width: 80, // Adjust the width
                    height: 80, // Adjust the height
                  ),
                  SizedBox(height: 10),
                  Text(
                    '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text('Settings'),
              onTap: () {
                // Navigate to Settings screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              },
            ),
            ListTile(
              title: Text('Indoor Navigation'),
              onTap: () {
                // Navigate to Indoor Navigation screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => IndoorNavigationScreen()),
                );
              },
            ),
            // Add more menu items here if needed
          ],
        ),
      ),
    );
  }
}
