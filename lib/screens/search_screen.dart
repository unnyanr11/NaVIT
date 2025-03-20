import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:geocoding/geocoding.dart'; // Import geocoding for resolving addresses
import 'navigation_screen.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController startController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: 'AIzaSyA4WuprFdnJfFU3eomuasm7fHoSLuuVySw');
  List<Prediction> _startSuggestions = [];
  List<Prediction> _destinationSuggestions = [];
  Position? _currentPosition;
  String _currentAddress = '';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // Get current location and resolve address
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorDialog('Location services are disabled. Please enable them in your device settings.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever) {
          _showErrorDialog('Location permissions are permanently denied. Please enable them in your device settings.');
          return;
        } else if (permission == LocationPermission.denied) {
          _showErrorDialog('Location permissions are denied. Please grant permission to proceed.');
          return;
        }
      }

      // Fetch current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      // Resolve address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        setState(() {
          _currentAddress =
          "${placemark.name}, ${placemark.locality}, ${placemark.country}";
          startController.text = _currentAddress; // Set resolved address
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to get current location. Please try again.');
    }
  }

  // Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Fetch suggestions from Google Places API
  Future<void> _fetchSuggestions(String input, bool isStart) async {
    if (input.isEmpty) {
      setState(() {
        if (isStart) {
          _startSuggestions = [];
        } else {
          _destinationSuggestions = [];
        }
      });
      return;
    }

    PlacesAutocompleteResponse response = await _places.autocomplete(
      input,
      components: [Component(Component.country, 'in')], // Restrict to India
    );

    if (response.isOkay) {
      setState(() {
        if (isStart) {
          _startSuggestions = response.predictions;
        } else {
          _destinationSuggestions = response.predictions;
        }
      });
    } else {
      _showErrorDialog('Error fetching suggestions: ${response.errorMessage}');
    }
  }

  // Navigate to the navigation screen
  void _navigateToNavigationScreen() {
    if (startController.text.isEmpty || destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter both starting and destination points')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationScreen(
          start: startController.text,
          destination: destinationController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            // Starting point text field with suggestions
            TextField(
              controller: startController,
              decoration: InputDecoration(
                hintText: 'Starting Point',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) => _fetchSuggestions(value, true),
            ),
            if (_startSuggestions.isNotEmpty)
              _buildSuggestionsList(_startSuggestions, (suggestion) {
                startController.text = suggestion.description ?? '';
                setState(() => _startSuggestions = []);
              }),
            SizedBox(height: 10),
            // Destination point text field with suggestions
            TextField(
              controller: destinationController,
              decoration: InputDecoration(
                hintText: 'Destination',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) => _fetchSuggestions(value, false),
            ),
            if (_destinationSuggestions.isNotEmpty)
              _buildSuggestionsList(_destinationSuggestions, (suggestion) {
                destinationController.text = suggestion.description ?? '';
                setState(() => _destinationSuggestions = []);
              }),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _navigateToNavigationScreen,
              child: Text('Start Navigation'),
            ),
          ],
        ),
      ),
    );
  }

  // Widget to build suggestions list
  Widget _buildSuggestionsList(
      List<Prediction> suggestions, Function(Prediction) onTap) {
    return Container(
      height: 150,
      child: ListView.builder(
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(suggestions[index].description ?? ''),
            onTap: () => onTap(suggestions[index]),
          );
        },
      ),
    );
  }
}
