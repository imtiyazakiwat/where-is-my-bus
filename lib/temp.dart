import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class LiveBusPage extends StatefulWidget {
  final Map<String, dynamic> busRoute;
  final int departureTimeIndex;
  final String from;
  final String to;

  LiveBusPage({
    required this.busRoute,
    required this.departureTimeIndex,
    required this.from,
    required this.to,
  });

  @override
  _LiveBusPageState createState() => _LiveBusPageState();
}

class _LiveBusPageState extends State<LiveBusPage> with SingleTickerProviderStateMixin {
  late DateTime currentTime;
  String busStatus = '';
  int busPosition = -1;
  double busProgressBetweenStops = 0.0;
  bool hasStarted = false;
  bool hasArrived = false;
  late AnimationController _refreshIconController;
  late ScrollController _scrollController;
  late Timer _updateTimer;
  late Timer _arrivalCheckTimer;
  late List<dynamic> fullBusStops;
  late int fromIndex;
  late int toIndex;
  bool _showBusStatusOverlay = false;
  Timer? _busStatusOverlayTimer;

  @override
  void initState() {
    super.initState();
    currentTime = DateTime.now();
    _refreshIconController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _scrollController = ScrollController();
    fullBusStops = List<dynamic>.from(widget.busRoute['bus_stops']);
    fromIndex = fullBusStops.indexWhere((stop) => stop['stop_name'].toLowerCase() == widget.from.toLowerCase());
    toIndex = fullBusStops.indexWhere((stop) => stop['stop_name'].toLowerCase() == widget.to.toLowerCase());
    _calculateAllStopTimes();
    updateBusLocation();
    _startUpdateTimer();
    _startArrivalCheckTimer();
  }

  @override
  void dispose() {
    _refreshIconController.dispose();
    _scrollController.dispose();
    _updateTimer.cancel();
    _arrivalCheckTimer.cancel();
    _busStatusOverlayTimer?.cancel();
    super.dispose();
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(Duration(seconds: 20), (timer) {
      updateBusLocation();
    });
  }

  void _startArrivalCheckTimer() {
    _arrivalCheckTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _checkForArrival();
    });
  }

  void _checkForArrival() {
    if (busPosition >= 0 && busPosition < fullBusStops.length - 1) {
      Map<String, dynamic> nextStop = fullBusStops[busPosition + 1];
      DateTime nextStopTime = _parseTime(nextStop['arrivalTime']);

      if (DateTime.now().isAfter(nextStopTime) || DateTime.now().isAtSameMomentAs(nextStopTime)) {
        setState(() {
          busPosition++;
          busProgressBetweenStops = 0.0;
          _updateBusStatus();
        });
        _scrollToBusPosition();
        _triggerBusStatusOverlay();
      }
    }
  }

  void _calculateAllStopTimes() {
    List<dynamic> departureTimes = widget.busRoute['departure_times'] ?? [];
    String initialDepartureTime = departureTimes.isNotEmpty ? departureTimes[widget.departureTimeIndex].toString() : '';
    DateTime departureTime = _parseTime(initialDepartureTime);

    for (int i = 0; i < fullBusStops.length; i++) {
      double arrivalTime = fullBusStops[i]['arrival_time'];
      DateTime stopTime = departureTime.add(Duration(minutes: (arrivalTime * 60).round()));
      fullBusStops[i]['arrivalTime'] = i == 0 ? 'Start' : DateFormat('hh:mm a').format(stopTime);
      fullBusStops[i]['departureTime'] = i == fullBusStops.length - 1 ? 'End' : DateFormat('hh:mm a').format(stopTime);
    }
  }

  Future<void> updateBusLocation() async {
    _refreshIconController.repeat();
    await Future.delayed(Duration(seconds: 2)); // Simulating update time
    setState(() {
      currentTime = DateTime.now();
      _calculateBusPosition();
    });
    _refreshIconController.stop();
    _scrollToBusPosition();
    _triggerBusStatusOverlay();
  }

  void _triggerBusStatusOverlay() {
    setState(() {
      _showBusStatusOverlay = true;
    });

    _busStatusOverlayTimer?.cancel();
    _busStatusOverlayTimer = Timer(Duration(seconds: 3), () {
      setState(() {
        _showBusStatusOverlay = false;
      });
    });
  }

  void _scrollToBusPosition() {
    if (busPosition >= 0) {
      double itemHeight = 80.0; // Height of a station item
      double inBetweenHeight = 80.0; // Height of an in-between item
      double totalItemHeight = itemHeight + inBetweenHeight; // Total height for each stop (including in-between space)

      double offset = busPosition * totalItemHeight;

      // Adjust for the progress between stops
      if (busProgressBetweenStops > 0) {
        offset += itemHeight + (inBetweenHeight * busProgressBetweenStops);
      }

      // Adjust to center the bus in the viewport
      double viewportHeight = _scrollController.position.viewportDimension;
      offset = offset - (viewportHeight / 2) + (itemHeight / 2);

      // Ensure the scroll position is within bounds
      offset = offset.clamp(0.0, _scrollController.position.maxScrollExtent);

      _scrollController.animateTo(
        offset,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.busRoute['route_name'] ?? 'Bus Route'),
        actions: [
          IconButton(icon: Icon(Icons.more_vert), onPressed: () {}),
        ],
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          _buildHeaderRow(),
          Expanded(
            child: _buildStationList(),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      color: Colors.blue,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              DropdownButton<String>(
                value: 'Today',
                style: TextStyle(color: Colors.white),
                dropdownColor: Colors.blue,
                underline: Container(),
                icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                items: ['Today', 'Tomorrow', 'Day after'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (_) {},
              ),
              SizedBox(width: 8),
              Text(
                '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.white),
              SizedBox(width: 16),
              Icon(Icons.share, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      color: Colors.grey[300],
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text('Arrival', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text('Stop Name', style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: 80, child: Text('Departure', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildStationList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: fullBusStops.length * 2 - 1, // Add space for in-between items
      itemBuilder: (context, index) {
        if (index.isOdd) {
          // In-between item
          int stationIndex = index ~/ 2;
          bool isBusHere = stationIndex == busPosition && busProgressBetweenStops > 0;
          return _buildInBetweenItem(stationIndex, isBusHere);
        } else {
          // Station item
          int stationIndex = index ~/ 2;
          Map<String, dynamic> stop = fullBusStops[stationIndex];
          bool isHighlighted = stationIndex >= fromIndex && stationIndex <= toIndex;
          bool isBusHere = stationIndex == busPosition && busProgressBetweenStops == 0;
          return _buildStationItem(stop, isHighlighted, isBusHere);
        }
      },
    );
  }

  Widget _buildStationItem(Map<String, dynamic> stop, bool isHighlighted, bool isBusHere) {
    return Container(
      height: 80,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(stop['arrivalTime'], style: TextStyle(color: Colors.green)),
              ),
              Container(
                width: 16,
                height: 80,
                color: Colors.lightBlue[100],
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      stop['stop_name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isHighlighted ? Colors.blue : Colors.black,
                      ),
                    ),
                    Text('${stop['stop_distance']} km'),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(stop['departureTime'], style: TextStyle(color: Colors.indigo[900]), textAlign: TextAlign.right),
              ),
            ],
          ),
          if (isBusHere)
            Positioned(
              left: 68,
              child: _buildBusIcon(),
            ),
        ],
      ),
    );
  }

  Widget _buildInBetweenItem(int stationIndex, bool isBusHere) {
    return Container(
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              SizedBox(width: 80),
              Container(
                width: 16,
                color: Colors.lightBlue[100],
              ),
              Expanded(child: SizedBox()),
            ],
          ),
          if (isBusHere)
            Positioned(
              left: 72,
              top: busProgressBetweenStops <= 0.5
                  ? 40 * busProgressBetweenStops - 15
                  : (busProgressBetweenStops == 0.5 ? 5 : 40 * busProgressBetweenStops + 15),
              child: _buildBusIcon(),
            ),
        ],
      ),
    );
  }

  Widget _buildBusIcon() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.directions_bus, color: Colors.white, size: 20),
        ),
        if (_showBusStatusOverlay)
          AnimatedOpacity(
            opacity: _showBusStatusOverlay ? 1.0 : 0.0,
            duration: Duration(milliseconds: 200),
            child: Container(
              margin: EdgeInsets.only(left: 8),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                busStatus,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.blueGrey[50],
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(busStatus, style: TextStyle(color: Colors.orange[500])),
                Text('Updated ${_getUpdateTime()}', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          RotationTransition(
            turns: Tween(begin: 0.0, end: 1.0).animate(_refreshIconController),
            child: IconButton(
              icon: Icon(Icons.refresh),
              onPressed: updateBusLocation,
            ),
          ),
        ],
      ),
    );
  }

  void _calculateBusPosition() {
    List<dynamic> departureTimes = widget.busRoute['departure_times'] ?? [];
    String initialDepartureTime = departureTimes.isNotEmpty ? departureTimes[widget.departureTimeIndex].toString() : '';
    DateTime departureTime = _parseTime(initialDepartureTime);

    busPosition = -1;
    busProgressBetweenStops = 0.0;
    hasStarted = currentTime.isAfter(departureTime);
    hasArrived = false;

    for (int index = 0; index < fullBusStops.length - 1; index++) {
      Map<String, dynamic> currentStop = fullBusStops[index];
      Map<String, dynamic> nextStop = fullBusStops[index + 1];
      DateTime currentStopTime = _parseTime(currentStop['departureTime']);
      DateTime nextStopTime = _parseTime(nextStop['arrivalTime']);

      if (currentTime.isAfter(currentStopTime) && currentTime.isBefore(nextStopTime)) {
        busPosition = index;
        Duration totalDuration = nextStopTime.difference(currentStopTime);
        Duration elapsedDuration = currentTime.difference(currentStopTime);
        busProgressBetweenStops = elapsedDuration.inSeconds / totalDuration.inSeconds;
        break;
      }
    }

    if (busPosition == -1) {
      if (hasStarted) {
        hasArrived = true;
        busPosition = fullBusStops.length - 1;
      } else {
        busPosition = 0;
      }
    }

    _updateBusStatus();
  }

  void _updateBusStatus() {
    if (!hasStarted) {
      busStatus = 'Not started from ${fullBusStops[0]['stop_name']}';
    } else if (hasArrived) {
      busStatus = 'Bus has arrived at ${fullBusStops.last['stop_name']}';
    } else {
      String currentStop = fullBusStops[busPosition]['stop_name'];

      if (busProgressBetweenStops == 0) {
        busStatus = 'At $currentStop';
      } else {
        String nextStop = fullBusStops[busPosition + 1]['stop_name'];
        String arrivalTime = fullBusStops[busPosition + 1]['arrivalTime'];
        Duration timeSinceDeparture = DateTime.now().difference(_parseTime(fullBusStops[busPosition]['departureTime']));
        int minutesToNextStop = _parseTime(arrivalTime).difference(DateTime.now()).inMinutes;
        double totalDistance = double.parse(fullBusStops[busPosition + 1]['stop_distance']) - double.parse(fullBusStops[busPosition]['stop_distance']);
        double remainingDistance = totalDistance * (1 - busProgressBetweenStops);

        String timeSinceDepartureStr;
        if (timeSinceDeparture.inMinutes == 0) {
          timeSinceDepartureStr = '${timeSinceDeparture.inSeconds} seconds';
        } else {
          timeSinceDepartureStr = '${timeSinceDeparture.inMinutes} minute${timeSinceDeparture.inMinutes > 1 ? 's' : ''}';
        }

        if (busProgressBetweenStops <= 0.5) {
          busStatus = 'Left $currentStop $timeSinceDepartureStr ago, ${remainingDistance.toStringAsFixed(1)} km to $nextStop';
        } else {
          busStatus = '${remainingDistance.toStringAsFixed(1)} km to $nextStop (ETA: $minutesToNextStop minutes)';
        }
      }
    }
  }
  String _getUpdateTime() {
    final now = DateTime.now();
    final difference = now.difference(currentTime);
    if (difference.inSeconds < 60) {
      return 'a few seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return '${difference.inHours} hours ago';
    }
  }

  DateTime _parseTime(String time) {
    if (time.isEmpty) return DateTime.now();
    if (time == 'Start' || time == 'End') return DateTime.now();

    try {
      final now = DateTime.now();
      final timeFormat = DateFormat('hh:mm a');
      final dateTime = timeFormat.parse(time);
      return DateTime(now.year, now.month, now.day, dateTime.hour, dateTime.minute);
    } catch (e) {
      print("Error parsing time: $time");
      return DateTime.now(); // Return current time if parsing fails
    }
  }
}

class Station {
  final String name;
  final String distance;
  final String arrivalTime;
  final String departureTime;
  final bool isStart;
  final bool isEnd;
  final bool isBusHere;
  final bool isHighlighted;

  Station({
    required this.name,
    required this.distance,
    required this.arrivalTime,
    required this.departureTime,
    this.isStart = false,
    this.isEnd = false,
    this.isBusHere = false,
    this.isHighlighted = false,
  });
}