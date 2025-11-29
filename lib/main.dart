import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';

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
      title: 'Focus Clock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'Inter', 
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

  // Orientation State
  bool _isLandscape = false;

  // Controls Visibility State
  bool _areControlsVisible = true;
  Timer? _hideControlsTimer;

  // Pomodoro State
  Timer? _pomodoroTimer;
  static const int _workDurationSeconds = 25 * 60;
  int _remainingSeconds = _workDurationSeconds;
  bool _isPomodoroRunning = false;
  bool _isTimerFinished = false; 
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();

    // Start in Portrait mode by default
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });

    // Start auto-hide timer
    _startHideTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([]);
    _timeTimer.cancel();
    _pomodoroTimer?.cancel();
    _hideControlsTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      WakelockPlus.enable();
      // Re-enforce current orientation choice
      if (_isLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft, 
          DeviceOrientation.landscapeRight
        ]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    }
  }

  // --- Logic Helpers ---

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _areControlsVisible = false;
      });
    });
  }

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
      _isTimerFinished = false; 
      setState(() {
        _areControlsVisible = true;
      });
      _startHideTimer();
    });
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
      _areControlsVisible = true;
    });
    _startHideTimer();
    
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  // --- Pomodoro Logic ---

  Future<void> _playBeep() async {
    try {
      // Use a short, publicly available beep sound URL
      await _audioPlayer.play(UrlSource('[https://actions.google.com/sounds/v1/alarms/beep_short.ogg](https://actions.google.com/sounds/v1/alarms/beep_short.ogg)'));
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
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
        _isTimerFinished = false; 
      });
      _pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          setState(() {
            _remainingSeconds--;
          });
        } else {
          // Timer finished
          _pomodoroTimer?.cancel();
          
          _playBeep();

          setState(() {
            _isPomodoroRunning = false;
            _isTimerFinished = true; 
          });
        }
      });
    }
  }

  void _resetPomodoro() {
    _pomodoroTimer?.cancel();
    setState(() {
      _isPomodoroRunning = false;
      _isTimerFinished = false;
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
    String displayString;
    if (_currentMode == AppMode.clock) {
      displayString = _getFormattedTime();
    } else {
      displayString = _isTimerFinished ? "DONE" : _getPomodoroTime();
    }

    Color textColor = Colors.white;
    if (_currentMode == AppMode.pomodoro && !_isPomodoroRunning && !_isTimerFinished) {
      textColor = Colors.white70;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_currentMode == AppMode.pomodoro && _isTimerFinished) {
            _resetPomodoro();
            return;
          }

          setState(() {
            _areControlsVisible = !_areControlsVisible;
          });
          if (_areControlsVisible) {
            _startHideTimer();
          } else {
            _hideControlsTimer?.cancel();
          }
        },
        onDoubleTap: () {
          // Double tap handles functionality (Toggle Format or Pomodoro)
          if (_currentMode == AppMode.clock) {
            _toggleFormat();
          } else {
            if (!_isTimerFinished) {
               _togglePomodoro();
            }
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
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayString,
                        style: TextStyle(
                          fontSize: 200, 
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          fontFamily: 'Inter', 
                          letterSpacing: 4.0,
                        ),
                      ),
                      if (_currentMode == AppMode.pomodoro)
                         Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Text(
                            _isTimerFinished 
                                ? "TAP SCREEN TO RESET" 
                                : (!_isPomodoroRunning ? "DOUBLE TAP TO START • LONG PRESS TO RESET" : ""),
                            style: const TextStyle(color: Colors.white24, fontSize: 10),
                           ),
                         ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 30,
              right: 30,
              child: AnimatedOpacity(
                opacity: _areControlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IconButton(
                  onPressed: _areControlsVisible ? _toggleMode : null,
                  icon: Icon(
                    _currentMode == AppMode.clock 
                        ? Icons.timer_outlined 
                        : Icons.access_time,
                    color: Colors.white24,
                    size: 32,
                  ),
                ),
              ),
            ),
            
            // Rotation Toggle Button (Top Right)
            Positioned(
              top: 30,
              right: 30,
              child: AnimatedOpacity(
                opacity: _areControlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IconButton(
                  onPressed: _areControlsVisible ? _toggleOrientation : null,
                  icon: Icon(
                    _isLandscape ? Icons.screen_lock_landscape : Icons.screen_lock_portrait,
                    color: Colors.white24,
                    size: 32,
                  ),
                  tooltip: "Rotate Screen",
                ),
              ),
            ),

            if (_currentMode == AppMode.clock)
              Positioned(
                bottom: 40,
                left: 40,
                child: AnimatedOpacity(
                  opacity: _areControlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    DateFormat('EEEE, MMM d').format(_currentTime).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 16,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}