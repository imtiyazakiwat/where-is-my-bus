import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:where_is_my_bus/LiveBus.dart';

class BusSchedulePage extends StatefulWidget {
  final String from;
  final String to;
  final List<Map<String, dynamic>> buses;

  BusSchedulePage({required this.from, required this.to, required this.buses});

  @override
  _BusSchedulePageState createState() => _BusSchedulePageState();
}

class _BusSchedulePageState extends State<BusSchedulePage> {
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
              '${_capitalizeFirstLetter(widget.from)} → ${_capitalizeFirstLetter(widget.to)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: filteredBuses.isEmpty
                ? Center(
              child: Text(
                'No buses currently available for this route',
                style: TextStyle(fontSize: 16),
              ),
            )
                : _buildBusList(filteredBuses),
          ),
        ],
      ),
    );
  }

  Widget _buildBusList(List<Map<String, dynamic>> filteredBuses) {
    List<Widget> busWidgets = [];
    bool hasUpcomingBuses = false;

    for (var bus in filteredBuses) {
      final departureTimes = bus['departure_times'] as List<dynamic>;
      for (var departureTime in departureTimes) {
        final fromTime = _calculateTimeAtStop(departureTime, bus['from_index'], bus);
        final toTime = _calculateTimeAtStop(departureTime, bus['to_index'], bus);

        if (fromTime == null || toTime == null) continue;

        final DateTime fromDateTime = _parseTime(fromTime);
        final DateTime now = DateTime.now();
        final bool isPassed = fromDateTime.isBefore(now);
        final bool isRecent = isPassed && now.difference(fromDateTime).inMinutes <= 5;
        final bool isUpcoming = fromDateTime.isAfter(now) || isRecent;

        if (!isUpcoming && !isRecent) continue;

        hasUpcomingBuses = true;
        busWidgets.add(
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LiveBusPage(
                    busRoute: bus,
                    departureTimeIndex: departureTimes.indexOf(departureTime),
                    from: widget.from,
                    to: widget.to,
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
                    Text(
                      _getFullRouteName(bus),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text(_getRunningDays(bus)),
                  ],
                ),
                trailing: Text('Runs Daily'),
              ),
            ),
          ),
        );
      }
    }

    if (!hasUpcomingBuses) {
      return Center(
        child: Text(
          'No upcoming buses available',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView(children: busWidgets);
  }

  List<Map<String, dynamic>> _filterBuses() {
    return widget.buses.map((bus) {
      Map<String, dynamic> newBus = Map.from(bus);
      List<Map<String, dynamic>> stops = List<Map<String, dynamic>>.from(bus['bus_stops']);
      int fromIndex = stops.indexWhere((stop) => stop['stop_name'].toLowerCase() == widget.from.toLowerCase());
      int toIndex = stops.indexWhere((stop) => stop['stop_name'].toLowerCase() == widget.to.toLowerCase());
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

  String _getFullRouteName(Map<String, dynamic> bus) {
    List<Map<String, dynamic>> stops = List<Map<String, dynamic>>.from(bus['bus_stops']);
    List<String> uniqueStops = [];

    if (stops.first['stop_name'].toLowerCase() != widget.from.toLowerCase()) {
      uniqueStops.add(stops.first['stop_name']);
    }

    uniqueStops.add(widget.from);

    if (widget.to.toLowerCase() != widget.from.toLowerCase()) {
      uniqueStops.add(widget.to);
    }

    if (stops.last['stop_name'].toLowerCase() != widget.to.toLowerCase() &&
        stops.last['stop_name'].toLowerCase() != widget.from.toLowerCase()) {
      uniqueStops.add(stops.last['stop_name']);
    }

    return uniqueStops.join('-');
  }
}