import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class IndoorNavigationScreen extends StatefulWidget {
  @override
  _IndoorNavigationScreenState createState() => _IndoorNavigationScreenState();
}

class _IndoorNavigationScreenState extends State<IndoorNavigationScreen> {
  late GoogleMapController _mapController;
  LatLng _currentPosition = LatLng(0, 0);
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String _destinationRoom = "";
  List<String> _suggestions = [];
  TextEditingController _searchController = TextEditingController();
  String _directions = "";
  bool _isMapLoaded = false;

  /// 🔑 **Google Maps API Key**
  final String _apiKey = "AIzaSyA4WuprFdnJfFU3eomuasm7fHoSLuuVySw";

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  /// ✅ **Initialize Map Data**
  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    await _loadGeoJson();
    setState(() {
      _isMapLoaded = true;
    });
  }

  /// ✅ **Loads GeoJSON Paths & Markers**
  Future<void> _loadGeoJson() async {
    List<String> geoJsonFiles = [
      'assets/NaVIT (Ground Floor) (1)/NaVIT (Ground Floor) (1)1.json',
      'assets/NaVIT (Ground Floor) (1)/NaVIT (Ground Floor) (1)2.json'
    ];

    Set<Polyline> newPolylines = {};
    Set<Marker> newMarkers = {};

    for (String file in geoJsonFiles) {
      try {
        String jsonString = await rootBundle.loadString(file);
        print("✅ Loaded JSON from $file");

        Map<String, dynamic> geoJsonData = jsonDecode(jsonString);
        if (geoJsonData['features'] == null) continue;

        for (var feature in geoJsonData['features']) {
          var geometry = feature['geometry'];
          var properties = feature['properties'];

          if (geometry['type'] == 'LineString' || geometry['type'] == 'Polygon') {
            List<LatLng> polylinePoints = [];

            if (geometry['type'] == 'Polygon') {
              for (var ring in geometry['coordinates']) {
                for (var coord in ring) {
                  polylinePoints.add(LatLng(coord[1], coord[0]));
                }
                break; // Take only the outer boundary
              }
            } else {
              for (var coord in geometry['coordinates']) {
                polylinePoints.add(LatLng(coord[1], coord[0]));
              }
            }

            newPolylines.add(
              Polyline(
                polylineId: PolylineId(properties['name'] ?? 'path_${newPolylines.length}'),
                points: polylinePoints,
                color: Colors.red,
                width: 5,
              ),
            );
          }
          else if (geometry['type'] == 'Point') {
            LatLng point = LatLng(geometry['coordinates'][1], geometry['coordinates'][0]);

            newMarkers.add(
              Marker(
                markerId: MarkerId(properties['name'] ?? 'marker_${newMarkers.length}'),
                position: point,
                infoWindow: InfoWindow(title: properties['name'] ?? 'Point'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ),
            );

            _suggestions.add(properties['name'] ?? '');
          }
        }
      } catch (e) {
        print("❌ Error loading $file: $e");
      }
    }

    setState(() {
      _markers.addAll(newMarkers);
      _polylines.addAll(newPolylines);
    });
  }

  /// ✅ **Get Current Location**
  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);

      _markers.removeWhere((marker) => marker.markerId.value == 'current_location');
      _markers.add(
        Marker(
          markerId: MarkerId('current_location'),
          position: _currentPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: 'Your Location'),
        ),
      );
    });
  }

  /// ✅ **Fetch & Display Combined Navigation Path**
  Future<void> _navigateToDestination() async {
    LatLng? destinationLatLng;
    LatLng? entranceLatLng;

    // Find Destination Marker
    for (var marker in _markers) {
      if (marker.infoWindow.title == _destinationRoom) {
        destinationLatLng = marker.position;
        break;
      }
    }

    if (destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Room not found!')),
      );
      return;
    }

    // 🔹 Step 1: Get Outdoor Route (Blue Path)
    String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${_currentPosition.latitude},${_currentPosition.longitude}&destination=${destinationLatLng.latitude},${destinationLatLng.longitude}&mode=walking&key=$_apiKey";
    http.Response response = await http.get(Uri.parse(url));
    Map<String, dynamic> data = jsonDecode(response.body);

    if (data['routes'].isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No route found!')),
      );
      return;
    }

    List<LatLng> routePoints = [];
    for (var step in data['routes'][0]['legs'][0]['steps']) {
      var polyline = step['polyline']['points'];
      routePoints.addAll(_decodePolyline(polyline));
    }
    setState(() {
      _directions = data['routes'][0]['legs'][0]['steps']
          .map((step) => step['html_instructions'])
          .join("\n");
    });


    // 🔹 Step 2: Find Nearest Entrance to Connect Outdoor & Indoor
    for (var marker in _markers) {
      if (marker.infoWindow.title?.toLowerCase().contains("entrance") == true) {
        entranceLatLng = marker.position;
        break;
      }
    }

    if (entranceLatLng != null) {
      // Ensure outdoor path reaches the entrance first
      List<LatLng> combinedPath = [...routePoints, entranceLatLng];

      // Append indoor path
      List<LatLng> indoorPath = _findIndoorPath(destinationLatLng);
      combinedPath.addAll(indoorPath);

      setState(() {
        _polylines.removeWhere((polyline) => polyline.polylineId.value == 'route');
        _polylines.add(
          Polyline(
            polylineId: PolylineId('route'),
            points: combinedPath,
            color: Colors.blue,
            width: 4,
          ),
        );
      });
    }



    // 🔹 Step 3: Merge Indoor Path (Red)
    List<LatLng> indoorPath = _findIndoorPath(destinationLatLng);
    List<LatLng> combinedPath = [...routePoints, ...indoorPath];

    setState(() {
      _polylines.removeWhere((polyline) => polyline.polylineId.value == 'route');
      _polylines.add(
        Polyline(
          polylineId: PolylineId('route'),
          points: combinedPath,
          color: Colors.blue,
          width: 4,
        ),
      );

      if (destinationLatLng != null) {
        _markers.add(
          Marker(
            markerId: MarkerId("destination"),
            position: destinationLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: _destinationRoom,
              snippet: "Tap to dismiss",  // Optional message
            ),
            onTap: () {
              setState(() {
                _markers = _markers.map((marker) {
                  if (marker.markerId.value == "destination") {
                    return marker.copyWith(
                      infoWindowParam: InfoWindow.noText, // Hide InfoWindow on tap
                    );
                  }
                  return marker;
                }).toSet();
              });
            },
          ),
        );

      } else {
        print("❌ Error: Destination LatLng is null!");
      }


      _directions = "Follow the blue path to ${_destinationRoom}.";
    });

    _mapController.animateCamera(CameraUpdate.newLatLngZoom(destinationLatLng, 18));
  }


  /// ✅ **Find the Indoor Path Leading to the Destination**
  List<LatLng> _findIndoorPath(LatLng destination) {
    for (Polyline polyline in _polylines) {
      if (polyline.points.contains(destination)) {
        return polyline.points;
      }
    }
    return [];
  }

  /// ✅ **Decodes Google Maps Encoded Polyline**
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += deltaLng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }
  void _onSearch() {
    setState(() {
      _destinationRoom = _searchController.text;
    });
    _navigateToDestination();
  }


  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Indoor Navigation")),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return _suggestions.where((suggestion) =>
                    suggestion.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (String selection) {
                setState(() {
                  _destinationRoom = selection;
                  _searchController.text = selection;
                });
                _navigateToDestination();
              },
              fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                _searchController = controller;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onEditingComplete: onEditingComplete,
                  decoration: InputDecoration(
                    hintText: "Enter Destination Room",
                    suffixIcon: IconButton(
                      icon: Icon(Icons.search),
                      onPressed: _onSearch,
                    ),
                  ),
                );
              },
            ),

          ),
          Expanded(
            child: _isMapLoaded
                ? GoogleMap(
              initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 18),
              onMapCreated: (controller) => _mapController = controller,
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
            )
                : Center(child: CircularProgressIndicator()),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(_directions, style: TextStyle(fontSize: 14, color: Colors.black)),
          ),

          ElevatedButton(
            onPressed: _navigateToDestination,
            child: Text("Navigate"),
          ),
        ],
      ),
    );
  }
}