import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'bus_schedule_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Where is my Bus',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  List<Map<String, dynamic>> _busRoutes = [];
  List<String> _searchHistory = [];
  List<String> _suggestions = [];
  bool _isFromFocused = false;

  @override
  void initState() {
    super.initState();
    loadBusRoutes();
    _loadSearchHistory();
  }

  Future<void> loadBusRoutes() async {
    try {
      String jsonString = await rootBundle.loadString('assets/bus_routes.json');
      List<dynamic> jsonData = json.decode(jsonString);
      setState(() {
        _busRoutes = List<Map<String, dynamic>>.from(jsonData);
      });
      _calculateArrivalTimes();
    } catch (e) {
      print('Error loading bus routes: $e');
    }
  }

  void _calculateArrivalTimes() {
    for (var route in _busRoutes) {
      double totalDuration = _parseDuration(route['duration']);
      double totalDistance = double.parse(route['bus_stops'].last['stop_distance']);
      double averageSpeed = totalDistance / totalDuration;

      for (var stop in route['bus_stops']) {
        double distance = double.parse(stop['stop_distance']);
        double time = distance / averageSpeed;
        stop['arrival_time'] = time;
      }
    }
  }

  double _parseDuration(String duration) {
    List<String> parts = duration.split(' ');
    if (parts.length != 2) return 0;
    List<String> timeParts = parts[0].split('.');
    double hours = double.parse(timeParts[0]);
    double minutes = timeParts.length > 1 ? double.parse(timeParts[1]) / 60 : 0;
    return hours + minutes;
  }

  List<Map<String, dynamic>> findBuses(String from, String to) {
    return _busRoutes.where((bus) {
      List<Map<String, dynamic>> stops = List<Map<String, dynamic>>.from(bus['bus_stops']);
      int fromIndex = stops.indexWhere((stop) => stop['stop_name'].toLowerCase() == from.toLowerCase());
      int toIndex = stops.indexWhere((stop) => stop['stop_name'].toLowerCase() == to.toLowerCase());
      return fromIndex != -1 && toIndex != -1 && fromIndex < toIndex;
    }).toList();
  }

  Future<void> _loadSearchHistory() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _searchHistory = prefs.getStringList('search_history') ?? [];
      });
    } catch (e) {
      print('Error loading search history: $e');
    }
  }

  Future<void> _saveSearchHistory(String from, String to) async {
    try {
      String searchEntry = "$from - $to";
      if (!_searchHistory.contains(searchEntry)) {
        _searchHistory.insert(0, searchEntry);
        if (_searchHistory.length > 5) {
          _searchHistory.removeLast();
        }
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('search_history', _searchHistory);
      }
    } catch (e) {
      print('Error saving search history: $e');
    }
  }

  void _updateSuggestions(String query) {
    setState(() {
      _suggestions = _busRoutes
          .expand((route) => route['bus_stops'])
          .map<String>((stop) => stop['stop_name'] as String)
          .where((stop) => stop.toLowerCase().startsWith(query.toLowerCase()))
          .toSet()  // Remove duplicates
          .toList();
    });
  }

  void _swapStations() {
    setState(() {
      String temp = _fromController.text;
      _fromController.text = _toController.text;
      _toController.text = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Where is my Bus'),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {},
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _fromController,
              decoration: InputDecoration(
                hintText: 'From Station',
                prefixIcon: Icon(Icons.location_on),
                suffixIcon: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    _fromController.clear();
                    _updateSuggestions('');
                  },
                ),
              ),
              onChanged: (value) {
                _updateSuggestions(value);
                setState(() {
                  _isFromFocused = true;
                });
              },
              onTap: () {
                setState(() {
                  _isFromFocused = true;
                });
              },
            ),
            SizedBox(height: 16),
            TextField(
              controller: _toController,
              decoration: InputDecoration(
                hintText: 'To Station',
                prefixIcon: Icon(Icons.location_on),
                suffixIcon: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    _toController.clear();
                    _updateSuggestions('');
                  },
                ),
              ),
              onChanged: (value) {
                _updateSuggestions(value);
                setState(() {
                  _isFromFocused = false;
                });
              },
              onTap: () {
                setState(() {
                  _isFromFocused = false;
                });
              },
            ),
            SizedBox(height: 16),
            ElevatedButton(
              child: Text('Find buses'),
              onPressed: () async {
                String from = _fromController.text.trim();
                String to = _toController.text.trim();
                List<Map<String, dynamic>> buses = findBuses(from, to);
                await _saveSearchHistory(from, to);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BusSchedulePage(
                      from: from,
                      to: to,
                      buses: buses,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size(double.infinity, 36),
              ),
            ),
            SizedBox(height: 16),
            if (_suggestions.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_suggestions[index]),
                      onTap: () {
                        setState(() {
                          if (_isFromFocused) {
                            _fromController.text = _suggestions[index];
                          } else {
                            _toController.text = _suggestions[index];
                          }
                          _suggestions.clear();
                        });
                      },
                    );
                  },
                ),
              ),
            if (_suggestions.isEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEARCH HISTORY',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _searchHistory.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(_searchHistory[index]),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              List<String> parts = _searchHistory[index].split(' - ');
                              if (parts.length == 2) {
                                setState(() {
                                  _fromController.text = parts[0];
                                  _toController.text = parts[1];
                                });
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _swapStations,
        child: Icon(Icons.swap_vert),
        tooltip: 'Swap stations',
      ),
    );
  }
}