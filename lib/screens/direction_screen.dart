import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class DirectionScreen extends StatefulWidget {
  final LatLng startLatLng;
  final LatLng destinationLatLng;

  DirectionScreen({required this.startLatLng, required this.destinationLatLng});

  @override
  _DirectionScreenState createState() => _DirectionScreenState();
}

class _DirectionScreenState extends State<DirectionScreen> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  String _directionText = "Loading...";
  String _travelTime = "Loading...";
  String _distance = "Loading...";
  String _arrivalTime = "Loading...";
  bool _isLoading = true;

  LatLng? _currentLatLng;

  @override
  void initState() {
    super.initState();
    _fetchInitialRouteAndSetupMarkers();
    _startLocationUpdates();
  }

  Future<void> _fetchInitialRouteAndSetupMarkers() async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${widget.startLatLng.latitude},${widget.startLatLng.longitude}&destination=${widget.destinationLatLng.latitude},${widget.destinationLatLng.longitude}&key=AIzaSyA4WuprFdnJfFU3eomuasm7fHoSLuuVySw');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'].isEmpty) {
        print('No routes found');
        setState(() => _isLoading = false);
        return;
      }

      final route = data['routes'][0]['overview_polyline']['points'];
      final polylinePoints = _decodePolyline(route);

      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: PolylineId('route'),
          points: polylinePoints,
          color: Colors.indigo,
          width: 5,
        ));
        _markers.add(Marker(
          markerId: MarkerId('start'),
          position: widget.startLatLng,
          infoWindow: InfoWindow(title: 'Start'),
        ));
        _markers.add(Marker(
          markerId: MarkerId('destination'),
          position: widget.destinationLatLng,
          infoWindow: InfoWindow(title: 'Destination'),
        ));
        _isLoading = false;
      });

      _moveCameraToBounds(polylinePoints);
    } else {
      print('Error fetching directions');
      setState(() => _isLoading = false);
    }
  }

  void _startLocationUpdates() {
    Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        )).listen((Position position) {
      final currentLatLng = LatLng(position.latitude, position.longitude);
      setState(() => _currentLatLng = currentLatLng);

      _updateMovingMarker(currentLatLng);
      _fetchRouteAndShowDirections(currentLatLng);
    });
  }

  Future<void> _updateMovingMarker(LatLng currentLatLng) async {
    BitmapDescriptor movingMarkerIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(48, 48)),
      'assets/imm2.png',
    );

    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'currentLocation');

      _markers.add(
        Marker(
          markerId: MarkerId('currentLocation'),
          position: currentLatLng,
          icon: movingMarkerIcon,
          infoWindow: InfoWindow(title: 'You are here'),
        ),
      );
    });

    _moveCameraToCurrentLocation(currentLatLng);
  }

  Future<void> _fetchRouteAndShowDirections(LatLng currentLatLng) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${currentLatLng.latitude},${currentLatLng.longitude}&destination=${widget.destinationLatLng.latitude},${widget.destinationLatLng.longitude}&key=AIzaSyA4WuprFdnJfFU3eomuasm7fHoSLuuVySw');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'].isEmpty) {
        print('No routes found');
        return;
      }

      final route = data['routes'][0]['overview_polyline']['points'];
      final polylinePoints = _decodePolyline(route);

      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: PolylineId('route'),
          points: polylinePoints,
          color: Colors.indigo,
          width: 5,
        ));

        _directionText = _parseHtmlString(data['routes'][0]['legs'][0]['steps'][0]['html_instructions']);
        _travelTime = data['routes'][0]['legs'][0]['duration']['text'];
        _distance = data['routes'][0]['legs'][0]['distance']['text'];
        _arrivalTime = "Estimated arrival: " + _calculateArrivalTime(data['routes'][0]['legs'][0]['duration']['value']);
      });
    } else {
      print('Error fetching directions');
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

  String _parseHtmlString(String htmlString) {
    return htmlString.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  String _calculateArrivalTime(int durationInSeconds) {
    final currentTime = DateTime.now();
    final arrivalTime = currentTime.add(Duration(seconds: durationInSeconds));
    return "${arrivalTime.hour}:${arrivalTime.minute.toString().padLeft(2, '0')}";
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

  void _moveCameraToCurrentLocation(LatLng currentLatLng) {
    _mapController?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: currentLatLng,
        zoom: 17,
      ),
    ));
  }

  void _recenterCamera() {
    if (_currentLatLng != null) {
      _moveCameraToCurrentLocation(_currentLatLng!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Current location not available.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Directions'),
        backgroundColor: Colors.indigo,
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.indigo))
              : Column(
            children: [
              Container(
                padding: EdgeInsets.all(8.0),
                color: Colors.indigo.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_directionText,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo)),
                    SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Travel time: $_travelTime',
                            style: TextStyle(color: Colors.indigo)),
                        Text('Distance: $_distance',
                            style: TextStyle(color: Colors.indigo)),
                        Text('Arrival: $_arrivalTime',
                            style: TextStyle(color: Colors.indigo)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: widget.startLatLng,
                    zoom: 17,
                  ),
                  polylines: _polylines,
                  markers: _markers,
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _recenterCamera,
              child: Icon(Icons.my_location, color: Colors.white),
              backgroundColor: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }
}