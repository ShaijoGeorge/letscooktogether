import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enforce full screen immersive mode
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  runApp(const FocusClockApp());
}

class FocusClockApp extends StatelessWidget {
  const FocusClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lets Cook Together',
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

enum AppMode { clock, pomodoro }

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> with WidgetsBindingObserver {
  // Clock State
  late Timer _timeTimer;
  DateTime _currentTime = DateTime.now();
  bool _is24HourFormat = true;
  AppMode _currentMode = AppMode.clock;

  // Pomodoro State
  Timer? _pomodoroTimer;
  static const int _workDurationSeconds = 25 * 60;
  int _remainingSeconds = _workDurationSeconds;
  bool _isPomodoroRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();

    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _timeTimer.cancel();
    _pomodoroTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      WakelockPlus.enable();
    }
  }

  // --- Logic Helpers ---

  void _toggleFormat() {
    setState(() {
      _is24HourFormat = !_is24HourFormat;
    });
  }

  void _toggleMode() {
    setState(() {
      if (_currentMode == AppMode.clock) {
        _currentMode = AppMode.pomodoro;
      } else {
        _currentMode = AppMode.clock;
      }
    });
  }

  // --- Pomodoro Logic ---

  void _togglePomodoro() {
    if (_isPomodoroRunning) {
      _pomodoroTimer?.cancel();
      setState(() {
        _isPomodoroRunning = false;
      });
    } else {
      setState(() {
        _isPomodoroRunning = true;
      });
      _pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          setState(() {
            _remainingSeconds--;
          });
        } else {
          // Timer finished
          _pomodoroTimer?.cancel();
          setState(() {
            _isPomodoroRunning = false;
            _remainingSeconds = _workDurationSeconds;
          });
        }
      });
    }
  }

  void _resetPomodoro() {
    _pomodoroTimer?.cancel();
    setState(() {
      _isPomodoroRunning = false;
      _remainingSeconds = _workDurationSeconds;
    });
  }

  // --- UI Helpers ---

  String _getFormattedTime() {
    return DateFormat(_is24HourFormat ? 'HH:mm:ss' : 'h:mm:ss a')
        .format(_currentTime);
  }

  String _getPomodoroTime() {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    String displayString = _currentMode == AppMode.clock
        ? _getFormattedTime()
        : _getPomodoroTime();

    Color textColor = Colors.white;
    if (_currentMode == AppMode.pomodoro && !_isPomodoroRunning) {
      textColor = Colors.white70;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_currentMode == AppMode.clock) {
            _toggleFormat();
          } else {
            _togglePomodoro();
          }
        },
        onLongPress: () {
          if (_currentMode == AppMode.pomodoro) {
            _resetPomodoro();
          }
        },
        child: Stack(
          children: [
            // Centered Time Display with FittedBox for Landscape support
            Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayString,
                        style: TextStyle(
                          fontSize: 120, 
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontFamily: 'Courier', 
                          letterSpacing: 4.0,
                        ),
                      ),
                      if (_currentMode == AppMode.pomodoro && !_isPomodoroRunning)
                         const Padding(
                           padding: EdgeInsets.only(top: 8.0),
                           child: Text(
                            "TAP TO START • LONG PRESS TO RESET",
                            style: TextStyle(color: Colors.white24, fontSize: 10),
                           ),
                         ),
                    ],
                  ),
                ),
              ),
            ),

            // Mode Toggle Button (Bottom Right)
            Positioned(
              bottom: 30,
              right: 30,
              child: IconButton(
                onPressed: _toggleMode,
                icon: Icon(
                  _currentMode == AppMode.clock 
                      ? Icons.timer_outlined 
                      : Icons.access_time,
                  color: Colors.white24,
                  size: 32,
                ),
              ),
            ),
            
            // Date Display (Bottom Left - Clock Mode Only)
            if (_currentMode == AppMode.clock)
              Positioned(
                bottom: 40,
                left: 40,
                child: Text(
                  DateFormat('EEEE, MMM d').format(_currentTime).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white24,
                    fontSize: 16,
                    fontFamily: 'Courier',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}