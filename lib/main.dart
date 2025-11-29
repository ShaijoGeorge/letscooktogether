import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      title: 'Lets Cook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const ClockScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Centered Content (Icon)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icon/icon.png',
                    width: 150,
                    height: 150,
                  ),
                ],
              ),
            ),

            // 2. Bottom Info (Credits + Version)
            const Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "by SHAIJO GEORGE",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontFamily: 'Inter',
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 4), // Spacing between name and version
                  Text(
                    "v1.0.0",
                    style: TextStyle(
                      color: Colors.white24, // Slightly darker than the name
                      fontSize: 10,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

    // Check for tutorial
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstRun());
  }

  Future<void> _checkFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    final bool? seenTutorial = prefs.getBool('seenTutorial');

    if (seenTutorial == null || seenTutorial == false) {
      _showTutorial();
      await prefs.setBool('seenTutorial', true);
    }
  }

  void _showTutorial() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => const TutorialDialog(),
    );
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
      if (_isLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
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
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  // --- Pomodoro Logic ---

  Future<void> _playBeep() async {
    try {
      // Use a short, publicly available beep sound URL
      await _audioPlayer.play(
        UrlSource(
          '[https://actions.google.com/sounds/v1/alarms/beep_short.ogg](https://actions.google.com/sounds/v1/alarms/beep_short.ogg)',
        ),
      );
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
    return DateFormat(
      _is24HourFormat ? 'HH:mm:ss' : 'h:mm:ss a',
    ).format(_currentTime);
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
    if (_currentMode == AppMode.pomodoro &&
        !_isPomodoroRunning &&
        !_isTimerFinished) {
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
                      // Helper Text Logic
                      if (_currentMode == AppMode.pomodoro)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _isTimerFinished
                                ? "TAP SCREEN TO RESET"
                                : (!_isPomodoroRunning
                                      ? "DOUBLE TAP TO START • LONG PRESS TO RESET"
                                      : ""),
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                            ),
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
                  tooltip: _currentMode == AppMode.clock
                      ? "Switch to Timer"
                      : "Switch to Clock",
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
                  icon: const Icon(
                    Icons.screen_rotation_alt,
                    color: Colors.white24,
                    size: 32,
                  ),
                  tooltip: "Rotate Screen",
                ),
              ),
            ),

            // Tutorial Info Button (Top Left)
            Positioned(
              top: 30,
              left: 30,
              child: AnimatedOpacity(
                opacity: _areControlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IconButton(
                  onPressed: _areControlsVisible ? _showTutorial : null,
                  icon: const Icon(
                    Icons.info_outline,
                    color: Colors.white24,
                    size: 32,
                  ),
                  tooltip: "How to use",
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
                    DateFormat(
                      'EEEE, MMM d',
                    ).format(_currentTime).toUpperCase(),
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

class TutorialDialog extends StatelessWidget {
  const TutorialDialog({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine orientation
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: isLandscape
                  ? _buildLandscapeLayout()
                  : _buildPortraitLayout(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGesturesSection(),
        const SizedBox(height: 30),
        _buildButtonsSection(),
        const SizedBox(height: 40),
        _buildFooter(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: _buildGesturesSection()),
            const SizedBox(width: 40),
            Expanded(child: _buildButtonsSection()),
          ],
        ),
        const SizedBox(height: 30),
        _buildFooter(),
      ],
    );
  }

  Widget _buildGesturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "GESTURES",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 20),
        _buildGuideItem(Icons.touch_app, "Single Tap", "Hide / Show Controls"),
        _buildGuideItem(
          Icons.ads_click,
          "Double Tap",
          "Toggle Format (AM/PM)\nStart / Pause (Pomodoro Timer)",
        ),
        _buildGuideItem(
          Icons.gesture,
          "Long Press",
          "Reset Timer (Pomodoro Mode)",
        ),
      ],
    );
  }

  Widget _buildButtonsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "BUTTONS",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 20),
        _buildGuideItem(Icons.info_outline, "Top Left", "Show this guide"),
        _buildGuideItem(
          Icons.screen_rotation_alt,
          "Top Right",
          "Rotate Screen",
        ),
        _buildGuideItem(
          Icons.swap_horiz,
          "Bottom Right",
          "Switch Clock / Pomodoro Timer",
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Text(
        "TAP ANYWHERE TO CLOSE",
        style: TextStyle(color: Colors.white30, fontSize: 12),
      ),
    );
  }

  Widget _buildGuideItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
