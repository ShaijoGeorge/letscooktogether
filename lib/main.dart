import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FocusClockApp());
}

class FocusClockApp extends StatelessWidget {
  const FocusClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus Clock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'Courier', 
        useMaterial3: true,
      ),
      home: const ClockScreen(),
    );
  }
}

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  late Timer _timeTimer;
  DateTime _currentTime = DateTime.now();
  bool _is24HourFormat = true;

  @override
  void initState() {
    super.initState();
    // Start the clock ticker
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timeTimer.cancel();
    super.dispose();
  }

  void _toggleFormat() {
    setState(() {
      _is24HourFormat = !_is24HourFormat;
    });
  }

  String _getFormattedTime() {
    return DateFormat(_is24HourFormat ? 'HH:mm:ss' : 'h:mm:ss a')
        .format(_currentTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleFormat,
        child: Center(
          child: Text(
            _getFormattedTime(),
            style: const TextStyle(
              fontSize: 80,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Courier',
            ),
          ),
        ),
      ),
    );
  }
}