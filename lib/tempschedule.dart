import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:where_is_my_bus/LiveBus.dart';

class BusSchedulePage extends StatelessWidget {
  final String from;
  final String to;
  final List<Map<String, dynamic>> buses;

  BusSchedulePage({required this.from, required this.to, required this.buses});

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredBuses = _filterBuses();

    return Scaffold(
      appBar: AppBar(
        title: Text('Bus Schedule'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              // Handle menu item selection
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'All Dates',
                child: Text('All Dates'),
              ),
              PopupMenuItem<String>(
                value: 'Show fares',
                child: Text('Show fares'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '${_capitalizeFirstLetter(from)} → ${_capitalizeFirstLetter(to)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredBuses.length,
              itemBuilder: (context, index) {
                final bus = filteredBuses[index];
                final departureTimes = bus['departure_times'] as List<dynamic>;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        bus['route_name'],
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...departureTimes.map((departureTime) {
                      final fromTime = _calculateTimeAtStop(departureTime, bus['from_index'], bus);
                      final toTime = _calculateTimeAtStop(departureTime, bus['to_index'], bus);

                      if (fromTime == null || toTime == null) return SizedBox.shrink();

                      final DateTime fromDateTime = _parseTime(fromTime);
                      final DateTime now = DateTime.now();
                      final bool isPassed = fromDateTime.isBefore(now);
                      final bool isRecent = isPassed && now.difference(fromDateTime).inMinutes <= 5;
                      final bool isUpcoming = fromDateTime.isAfter(now) || isRecent;

                      if (!isUpcoming && !isRecent) return SizedBox.shrink();

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveBusPage(
                                busRoute: bus,
                                departureTimeIndex: departureTimes.indexOf(departureTime),
                                from: from,
                                to: to,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          child: ListTile(
                            leading: Container(
                              padding: EdgeInsets.all(4),
                              color: Colors.blue,
                              child: Text(
                                bus['route_id'],
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              '$fromTime → $toTime',
                              style: TextStyle(
                                color: isRecent ? Colors.red : Colors.black,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_getRunningDays(bus)),
                                Text('${bus['bus_stops'][bus['from_index']]['stop_name']} → ${bus['bus_stops'][bus['to_index']]['stop_name']}'),
                              ],
                            ),
                            trailing: Text('Runs Daily'),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterBuses() {
    return buses.map((bus) {
      Map<String, dynamic> newBus = Map.from(bus);
      List<Map<String, dynamic>> stops = List<Map<String, dynamic>>.from(bus['bus_stops']);
      int fromIndex = stops.indexWhere((stop) => stop['stop_name'].toLowerCase() == from.toLowerCase());
      int toIndex = stops.indexWhere((stop) => stop['stop_name'].toLowerCase() == to.toLowerCase());
      newBus['from_index'] = fromIndex;
      newBus['to_index'] = toIndex;
      return newBus;
    }).toList();
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String? _calculateTimeAtStop(String departureTime, int stopIndex, Map<String, dynamic> bus) {
    if (stopIndex < 0 || stopIndex >= bus['bus_stops'].length) return null;

    double arrivalTime = bus['bus_stops'][stopIndex]['arrival_time'];
    DateTime departure = _parseTime(departureTime);
    DateTime arrivalAtStop = departure.add(Duration(minutes: (arrivalTime * 60).round()));

    return DateFormat('hh:mm a').format(arrivalAtStop);
  }

  DateTime _parseTime(String time) {
    final now = DateTime.now();
    final timeFormat = DateFormat('hh:mm a');
    final dateTime = timeFormat.parse(time);
    return DateTime(now.year, now.month, now.day, dateTime.hour, dateTime.minute);
  }

  String _getRunningDays(Map<String, dynamic> bus) {
    // You would need to implement logic to determine running days
    // For now, we'll return a placeholder
    return 'S M T W T F S';
  }
}


//this is previous version of code