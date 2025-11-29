import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

  void _toggleFormat() {
    setState(() {
      _is24HourFormat = !_is24HourFormat;
    });
  }

  void _toggleMode() {
    setState(() {
      _currentMode = (_currentMode == AppMode.clock) ? AppMode.pomodoro : AppMode.clock;
    });
  }

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

  String _getFormattedTime() {
    return DateFormat(_is24HourFormat ? 'HH:mm:ss' : 'h:mm:ss a').format(_currentTime);
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
          if (_currentMode == AppMode.pomodoro) _resetPomodoro();
        },
        child: Stack(
          children: [
            Center(
              child: Text(
                displayString,
                style: const TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Courier',
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              right: 30,
              child: IconButton(
                onPressed: _toggleMode,
                icon: Icon(
                  _currentMode == AppMode.clock ? Icons.timer_outlined : Icons.access_time,
                  color: Colors.white24,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}