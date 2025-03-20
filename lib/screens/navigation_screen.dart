import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'direction_screen.dart'; // Import the DirectionScreen

class NavigationScreen extends StatefulWidget {
  final String start;
  final String destination;

  NavigationScreen({required this.start, required this.destination});

  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  LatLng? _startLatLng;
  LatLng? _destinationLatLng;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  double? _distanceLeft;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  Future<void> _initializeNavigation() async {
    await _getRoute(widget.start, widget.destination);
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Error fetching current location: $e');
    }
  }

  Future<void> _getRoute(String start, String destination) async {
    try {
      List<Location> startLocation = await locationFromAddress(start);
      List<Location> endLocation = await locationFromAddress(destination);

      _startLatLng =
          LatLng(startLocation[0].latitude, startLocation[0].longitude);
      _destinationLatLng =
          LatLng(endLocation[0].latitude, endLocation[0].longitude);

      double distance = Geolocator.distanceBetween(
        _startLatLng!.latitude,
        _startLatLng!.longitude,
        _destinationLatLng!.latitude,
        _destinationLatLng!.longitude,
      );

      setState(() {
        _distanceLeft = distance / 1000; // Convert to kilometers
        _addMarkers(); // Add markers for start and destination
      });

      await _fetchAndDisplayRoute(
          _startLatLng!.latitude,
          _startLatLng!.longitude,
          _destinationLatLng!.latitude,
          _destinationLatLng!.longitude);

      _showDistanceDialog();
    } catch (e) {
      print('Error fetching route: $e');
    }
  }

  void _addMarkers() {
    if (_startLatLng != null && _destinationLatLng != null) {
      setState(() {
        _markers.clear();
        _markers.add(
          Marker(
            markerId: MarkerId('start'),
            position: _startLatLng!,
            infoWindow: InfoWindow(title: 'Start Point', snippet: widget.start),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
          ),
        );
        _markers.add(
          Marker(
            markerId: MarkerId('destination'),
            position: _destinationLatLng!,
            infoWindow: InfoWindow(
                title: 'Destination Point', snippet: widget.destination),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed),
          ),
        );
      });
    }
  }

  Future<void> _fetchAndDisplayRoute(
      double startLat, double startLng, double endLat, double endLng) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=$startLat,$startLng&destination=$endLat,$endLng&key=AIzaSyA4WuprFdnJfFU3eomuasm7fHoSLuuVySw');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'].isEmpty) {
        print('No routes found in the response.');
        return;
      }

      final route = data['routes'][0]['overview_polyline']['points'];
      final polylinePoints = _decodePolyline(route);

      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: PolylineId('route'),
          points: polylinePoints,
          color: Colors.blue,
          width: 5,
        ));
      });

      _moveCameraToBounds(polylinePoints);
    } else {
      print('Failed to fetch directions. Status Code: ${response.statusCode}');
    }
  }

  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  void _moveCameraToBounds(List<LatLng> polylinePoints) {
    if (_mapController == null || polylinePoints.isEmpty) return;

    double southWestLat = polylinePoints.first.latitude;
    double southWestLng = polylinePoints.first.longitude;
    double northEastLat = polylinePoints.first.latitude;
    double northEastLng = polylinePoints.first.longitude;

    for (var point in polylinePoints) {
      if (point.latitude < southWestLat) southWestLat = point.latitude;
      if (point.longitude < southWestLng) southWestLng = point.longitude;
      if (point.latitude > northEastLat) northEastLat = point.latitude;
      if (point.longitude > northEastLng) northEastLng = point.longitude;
    }

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  void _showDistanceDialog() {
    if (_distanceLeft != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Distance'),
          content: Text(
              'The distance between ${widget.start} and ${widget.destination} is ${_distanceLeft!.toStringAsFixed(2)} km.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _updateRouteFromCurrentLocation() async {
    await _getCurrentLocation();

    if (_currentLocation == null || _destinationLatLng == null) return;

    double distance = Geolocator.distanceBetween(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      _destinationLatLng!.latitude,
      _destinationLatLng!.longitude,
    );

    setState(() {
      _distanceLeft = distance / 1000; // Convert to kilometers
    });

    // Pass destination coordinates to the DirectionScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DirectionScreen(
          startLatLng: _currentLocation!,
          destinationLatLng: _destinationLatLng!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Navigation'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: LatLng(20.5937, 78.9629), // Center of India
              zoom: 5,
            ),
            polylines: _polylines,
            markers: _markers,
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start: ${widget.start}',
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Destination: ${widget.destination}',
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _updateRouteFromCurrentLocation, // Button action
              child: Text('Direction'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.symmetric(vertical: 15),
                textStyle: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
