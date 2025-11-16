import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for Platform Channels
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'dart:async'; // For the Timer
import 'dart:ui'; // For BackdropFilter (Glassmorphism)
import 'package:collection/collection.dart'; // For ListEquality
import 'package:rive/rive.dart' hide Image, LinearGradient; // For the Rive Pet Animation
import 'dart:collection'; // For UnmodifiableListView
import 'package:shimmer/shimmer.dart'; // For Gradient Title

// --- 1. MAIN APP ENTRYPOINT & LUXURY THEME ---

void main() {
  // We wrap the app in *MultiProvider* to manage all app states.
  runApp(
    MultiProvider(
      providers: [
        // The FocusProvider now "leads"
        ChangeNotifierProvider(create: (context) => FocusProvider()),
        ChangeNotifierProvider(create: (context) => TodoProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
        
        // --- THE PSYCHE-ACOUSTIC BRIDGE ---
        // The MusicProvider now *depends on* and *listens to* the FocusProvider.
        // This is the "market-killer" connection.
        ChangeNotifierProxyProvider<FocusProvider, MusicProvider>(
          create: (context) => MusicProvider(),
          update: (context, focus, music) {
            if (music == null) return MusicProvider();
            // This is the "bridge"!
            // We are telling the MusicProvider about the user's stress state.
            music.updateFocusState(focus.isStressed);
            return music;
          },
        ),
      ],
      child: const ProjectElara(),
    ),
  );
}

class ProjectElara extends StatelessWidget {
  const ProjectElara({super.key});

  // --- 1. DEFINING YOUR NEW THEME GLOBALLY ---
  static const Color sereneBlue = Color(0xFF89CFF0);
  static const Color darkCharcoal = Color(0xFF0F0F12); // Your new background
  static const Color lightCharcoal = Color(0xFF3A3A3A); // For cards

  @override
  Widget build(BuildContext context) {
    // Set up all your app-wide providers
    return MaterialApp(
      title: 'Project Elara',
      debugShowCheckedModeBanner: false, // Hides the debug banner
      
      // --- 2. YOUR NEW THEME SECTION (MERGED) ---
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkCharcoal,
        primaryColor: sereneBlue,
        
        // Use GoogleFonts to apply 'Inter' to the entire app's text theme
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme.copyWith(
                bodyLarge: const TextStyle(color: Color(0xFFE0E0E0)),
                bodyMedium: const TextStyle(color: Color(0xFFB0B0B0)),
                titleLarge: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                headlineSmall: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
        ),

        // Define the Glassmorphism Bottom Nav Bar theme
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white.withOpacity(0.05), // Glassmorphism
          selectedItemColor: sereneBlue,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),

        // Custom color scheme
        colorScheme: const ColorScheme.dark(
          primary: sereneBlue,
          secondary: sereneBlue,
          surface: lightCharcoal,
        ),
      ),
      // --- END THEME SECTION ---
      
      home: const MainScreen(), // Your main app screen (our old MainAppShell)
    );
  }
}

// --- 2. DATA MODELS ---

// This single file holds all our data models for a clean project.

/// The states for the pet animation (your "Empathetic Nudge")
/// These will map to the Rive State Machine
enum PetState { idle, focused, sad, celebrating }

/// A single To-Do task.
class Todo {
  final String id;
  final String title;
  bool isDone;
  // TODO: Add fields for your "Natural Language" spec
  // (e.g., DateTime? reminder, String? tag)

  Todo({
    required this.id,
    required this.title,
    this.isDone = false,
  });
}

/// A single music track.
class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String artworkUrl; // URL for the "Headspace" style card
  final Color gradientStart; // For the "luxury" card gradient
  final Color gradientEnd;

  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.gradientStart,
    required this.gradientEnd,
  });
}

/// A "Trophy" / Achievement.
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool isUnlocked;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
  });
}

// --- 3. STATE MANAGEMENT (PROVIDERS) ---

/// A Provider to manage the state of the Focus Timer.
/// This is the "brain" for the core focus loop.
/// It now *also* manages the PetState, as they are linked.
class FocusProvider with ChangeNotifier {
  Timer? _timer;
  final int _totalSeconds = 25 * 60; // 25 minutes
  int _currentSeconds;
  bool _isRunning = false;

  // Enum for the pet's state (links to your "Empathetic Nudge")
  PetState _petState = PetState.idle;

  // --- "MARKET-KILLER" BIOMETRIC STATE ---
  bool _isStressed = false;
  final double _userRestingHR = 65.0; // Simulated user data
  
  /// The "Psyche-Acoustic" trigger. True if HR is ~20% above resting.
  bool get isStressed => _isStressed;
  // --- END BIOMETRIC STATE ---

  // --- HEALTH PLATFORM CHANNELS ---
  // "Method" channel for sending commands *to* native (start/stop)
  static const _healthMethodChannel = MethodChannel('com.elara.app/health_method');
  // "Event" channel for receiving streams *from* native (hr/hrv data)
  static const _healthEventChannel = EventChannel('com.elara.app/health_event');
  
  // This will hold the subscription to the native stream
  StreamSubscription? _healthStreamSubscription;
  // --- END HEALTH CHANNELS ---

  FocusProvider() : _currentSeconds = 25 * 60 {
    // --- HEALTH STREAM LISTENER ---
    // This is the "superpower". We listen to the native health stream.
    _healthStreamSubscription = _healthEventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        // We just received data from HealthKit / Wear OS!
        debugPrint('[Native Health Stream]: $data');

        // --- THIS IS THE "AI COACH" BRAIN ---
        // 1. Parse the data
        if (data is Map) {
          final double? hr = data['hr'] as double?;
          
          if (hr != null) {
            // 2. Detect "Stress" (e.g., HR is 20% over resting)
            if (hr > (_userRestingHR * 1.2) && !_isStressed) {
              debugPrint('[Psyche-Acoustic]: STRESS DETECTED (HR: $hr)');
              _isStressed = true;
              notifyListeners(); // Tell the MusicProvider!
              
              // 6. TODO: Call Haptic Pacer
              // _healthMethodChannel.invokeMethod('triggerHapticPacer');

            } 
            // 3. Detect "Recovery"
            else if (hr < (_userRestingHR * 1.1) && _isStressed) {
              debugPrint('[Psyche-Acoustic]: RECOVERY DETECTED (HR: $hr)');
              _isStressed = false;
              notifyListeners(); // Tell the MusicProvider!
            }
          }
        }
        // --- END AI COACH BRAIN ---

      },
      onError: (dynamic error) {
        debugPrint('[Native Health Stream]: Error: $error');
      },
      cancelOnError: false,
    );
  }

  // Getters
  int get currentSeconds => _currentSeconds;
  int get totalSeconds => _totalSeconds;
  bool get isRunning => _isRunning;
  double get progress => _totalSeconds > 0 ? _currentSeconds / _totalSeconds : 0.0;
  PetState get petState => _petState;

  String get displayTime {
    final int minutes = (_currentSeconds / 60).floor();
    final int seconds = _currentSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Actions
  Future<void> startStopTimer() async {
    if (_isRunning) {
      _timer?.cancel();
      _isRunning = false;
      _petState = PetState.sad; // "Empathetic Nudge" when pausing!
      
      // --- STOP HEALTH STREAM ---
      try {
        await _healthMethodChannel.invokeMethod('stopHealthStream');
        debugPrint('[Health Bridge]: Stopped native stream.');
        _isStressed = false; // Reset stress state
        notifyListeners();
      } on PlatformException catch (e) {
        debugPrint("Failed to stop health stream: '${e.message}'.");
      }

    } else {
      _isRunning = true;
      _petState = PetState.focused;
      
      // --- START HEALTH STREAM ---
      try {
        // This tells the native side to start sending data
        await _healthMethodChannel.invokeMethod('startHealthStream');
        debugPrint('[Health Bridge]: Started native stream.');
      } on PlatformException catch (e) {
        debugPrint("Failed to start health stream: '${e.message}'.");
      }
      // --- END HEALTH STREAM ---
      
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_currentSeconds > 0) {
          _currentSeconds--;
        } else {
          _timer?.cancel();
          _isRunning = false;
          _petState = PetState.celebrating;
          
          // --- STOP HEALTH STREAM on complete ---
          _healthMethodChannel.invokeMethod('stopHealthStream');
          _isStressed = false; // Reset stress state
          notifyListeners();

          // TODO: Trigger "Level Up" / "Coins Earned" modal
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void resetTimer() {
    _timer?.cancel();
    _isRunning = false;
    _currentSeconds = _totalSeconds;
    _petState = PetState.idle;
    
    // --- STOP HEALTH STREAM ---
    _healthMethodChannel.invokeMethod('stopHealthStream');
    _isStressed = false; // Reset stress state
    notifyListeners();
  }

  // Clean up the stream when the Provider is disposed
  @override
  void dispose() {
    _healthStreamSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}

/// A Provider to manage the To-Do list.
class TodoProvider with ChangeNotifier {
  final List<Todo> _tasks = [
    // Add some default tasks for the prototype
    Todo(id: '1', title: 'Build Project Elara', isDone: true),
    Todo(id: '2', title: 'Design "Luxury" UI'),
    Todo(id: '3.1', title: 'Architect "Empathetic Nudge"'),
    Todo(id: '4', title: 'Implement "Todoist" style input'),
  ];

  UnmodifiableListView<Todo> get tasks => UnmodifiableListView(_tasks);

  void addTask(String title) {
    if (title.trim().isEmpty) return;
    final newTodo = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
    );
    _tasks.add(newTodo);
    notifyListeners();
  }

  void toggleTask(String id) {
    final task = _tasks.firstWhereOrNull((t) => t.id == id);
    if (task != null) {
      task.isDone = !task.isDone;
      notifyListeners();
    }
  }

  void removeTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}

/// A Provider to manage the music player and "Dynamic Island" state.
class MusicProvider with ChangeNotifier {
  // Full library of tracks (our "Headspace" / "Calm" library)
  final List<MusicTrack> _playlist = [
    MusicTrack(
      id: '1',
      title: 'Lo-Fi & Binaural',
      artist: 'Elara Studios',
      artworkUrl: 'https://placehold.co/600x400/89CFF0/2E2E2E?text=Focus',
      gradientStart: ProjectElara.sereneBlue.withOpacity(0.7),
      gradientEnd: ProjectElara.lightCharcoal,
    ),
    MusicTrack(
      id: '2',
      title: 'Peaceful Piano',
      artist: 'Elara Studios',
      artworkUrl: 'https://placehold.co/600x400/FFC0CB/2E2E2E?text=Calm',
      gradientStart: const Color(0xFFFFC0CB).withOpacity(0.7),
      gradientEnd: ProjectElara.lightCharcoal,
    ),
    MusicTrack(
      id: '3',
      title: 'Rainy-Day Cafe',
      artist: 'Elara Studios',
      artworkUrl: 'https://placehold.co/600x400/B0E0E6/2E2E2E?text=Ambient',
      gradientStart: const Color(0xFFB0E0E6).withOpacity(0.7),
      gradientEnd: ProjectElara.lightCharcoal,
    ),
  ];

  UnmodifiableListView<MusicTrack> get playlist =>
      UnmodifiableListView(_playlist);

  MusicTrack? _currentTrack;
  bool _isPlaying = false;
  bool _isIslandExpanded = false;

  // --- "PSYCHE-ACOUSTIC" STATE ---
  MusicTrack? _userChosenTrack; // The track the user *was* listening to
  bool _isCalmOverrideActive = false;
  bool get isCalmOverrideActive => _isCalmOverrideActive;
  // --- END STATE ---

  MusicTrack? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  bool get isIslandExpanded => _isIslandExpanded;

  void playTrack(MusicTrack track) {
    // TODO: Add actual audio player logic (e.g., just_audio)
    _currentTrack = track;
    _isPlaying = true;
    _isIslandExpanded = false; // Start as a "pill"
    
    // If the user *manually* selects a track, stop the override.
    _isCalmOverrideActive = false;
    _userChosenTrack = null;

    notifyListeners();
  }

  /// Helper to play a track by its ID.
  void _playTrackById(String id) {
    final track = _playlist.firstWhereOrNull((t) => t.id == id);
    if (track != null) {
      // TODO: Add actual audio player logic (e.g., just_audio)
      _currentTrack = track;
      _isPlaying = true;
      _isIslandExpanded = false;
      notifyListeners();
    }
  }

  /// Called by the ProxyProvider when the user's stress state changes.
  void updateFocusState(bool isUserStressed) {
    if (isUserStressed && !_isCalmOverrideActive) {
      // User is stressed, and we haven't intervened yet.
      _triggerPsycheAcousticOverride();
    } else if (!isUserStressed && _isCalmOverrideActive) {
      // User has recovered, and we are in an override state.
      _stopPsycheAcousticOverride();
    }
  }

  /// The "market-killer" function.
  /// Overrides the current music with a "Calm" track.
  void _triggerPsycheAcousticOverride() {
    debugPrint('[Psyche-Acoustic]: Overriding music with "Peaceful Piano".');
    
    // 1. Save the user's current track (if they were playing one)
    if (_isPlaying) {
      _userChosenTrack = _currentTrack;
    }
    
    // 2. Set the override flag
    _isCalmOverrideActive = true;
    
    // 3. Play the "Calm" track (ID '2')
    _playTrackById('2');
  }

  /// Returns the user to their original music.
  void _stopPsycheAcousticOverride() {
    debugPrint('[Psyche-Acoustic]: User recovered. Returning to original track.');
    
    // 1. Clear the override flag
    _isCalmOverrideActive = false;
    
    // 2. Go back to the user's chosen track
    if (_userChosenTrack != null) {
      playTrack(_userChosenTrack!);
      _userChosenTrack = null;
    } else {
      // If they weren't listening to anything, just stop.
      _isPlaying = false;
      notifyListeners();
    }
  }

  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void toggleIsland() {
    _isIslandExpanded = !_isIslandExpanded;
    notifyListeners();
  }
}

/// A Provider to manage the User's profile, level, titles, and store.
class UserProvider with ChangeNotifier {
  // User Profile Data (from your "Dual-Vector" spec)
  final int _level = 40; // XP-Based
  final int _xp = 350;
  final int _xpForNextLevel = 1000;
  final int _cumulativeHours = 100; // Time-Based

  // "Trophy Case"
  final List<Achievement> _achievements = [
    Achievement(id: '1', title: 'Focused', description: 'Complete 1 session', icon: Icons.check, isUnlocked: true),
    Achievement(id: '2', title: 'Scholar', description: 'Reach 10 hours', icon: Icons.school_outlined, isUnlocked: true),
    Achievement(id: '3', title: 'Night Owl', description: 'Study past midnight', icon: Icons.nightlight_round, isUnlocked: true),
    Achievement(id: '4', title: '30-Day Streak', description: 'Focus for 30 days straight', icon: Icons.calendar_today),
    Achievement(id: '5', title: 'Zen Master', description: 'Reach 1,000 hours', icon: Icons.self_improvement_outlined),
  ];

  // --- AI COACH DATA (Module B) ---
  // This is simulated data for the AI Coach dashboard.
  final double _focusQualityScore = 8.7; // The "Market-Killer" Metric
  final String _proactiveNudge = 'Your "Logic" focus is 35% higher on weekday mornings. Try scheduling Physics for 10 AM.';
  
  // Data for "Time by Subject" chart
  final Map<String, double> _timeBySubject = {
    '#School': 0.6, // 60%
    '#Creative': 0.25, // 25%
    '#Admin': 0.15, // 15%
  };

  // Data for "Productivity Heatmap" (7 days, 0.0 to 1.0 intensity)
  final List<double> _heatmapData = [0.2, 0.8, 0.4, 0.9, 0.7, 0.3, 0.5];

  // Getters
  int get level => _level;
  double get xpProgress => _xp / _xpForNextLevel;
  String get xpDisplay => '$_xp / $_xpForNextLevel XP';
  int get cumulativeHours => _cumulativeHours;
  String get gradientTitle => _getTitleForHours(_cumulativeHours);
  List<Color> get gradientColors => _getColorsForHours(_cumulativeHours);
  UnmodifiableListView<Achievement> get achievements => UnmodifiableListView(_achievements);

  // AI Coach Getters
  double get focusQualityScore => _focusQualityScore;
  String get proactiveNudge => _proactiveNudge;
  Map<String, double> get timeBySubject => _timeBySubject;
  List<double> get heatmapData => _heatmapData;

  // Logic for the "Gradient Title" system (your "Mastery Path")
  String _getTitleForHours(int hours) {
    if (hours > 500) return 'Zen Master'; // Tier 4
    if (hours > 150) return 'Luminary'; // Tier 3
    if (hours > 25) return 'Scholar'; // Tier 2
    return 'Novice'; // Tier 1
  }

  // This maps to your "cool-to-hot" gradient spec
  List<Color> _getColorsForHours(int hours) {
    if (hours > 500) { // Tier 4 (Pulsing Red-Gold)
      return [Colors.red[600]!, Colors.orange[400]!, Colors.yellow[600]!];
    }
    if (hours > 150) { // Tier 3 (Warm Red-Orange)
      return [Colors.red[500]!, Colors.deepOrange[300]!];
    }
    if (hours > 25) { // Tier 2 (Emerald Green)
      return [const Color(0xFF26D0CE), const Color(0xFF1A2980)];
    }
    // Tier 1 (Cool Blue)
    return [ProjectElara.sereneBlue, Colors.blue[800]!];
  }
}

// --- 4. MAIN APP SHELL (THE 5-TAB NAVIGATION) ---

// This is our old "MainAppShell", renamed to "MainScreen"
// to match your import in main.dart.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const FocusScreen(),
    const TodoScreen(),
    const MusicScreen(),
    const CoachScreen(), // Replaced "Stats" with "AI Coach"
    const AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // We wrap the body in a Stack to allow the
      // "Dynamic Island" to float on top.
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          // This is the "Dynamic Island"
          const DynamicIslandOverlay(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_outlined),
            label: 'Focus',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: 'To-Do',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note_outlined),
            label: 'Music',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_outlined), // "AI Coach"
            label: 'Coach',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}


// --- 5. DYNAMIC ISLAND WIDGETS ---
// These are part of the "shell" UI.

/// This is the "Dynamic Island" player. It floats on top of the app.
class DynamicIslandOverlay extends StatelessWidget {
  const DynamicIslandOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    // Consume the MusicProvider to get the current track and state
    final music = context.watch<MusicProvider>();
    final track = music.currentTrack;

    // If no track is playing, be invisible.
    if (track == null) {
      return const SizedBox.shrink();
    }

    // This is the core animation. We use AnimatedContainer to
    // animate between the "pill" and "expanded" states.
    return Positioned(
      top: 40, // Just below the (potential) system notch
      left: 20,
      right: 20,
      child: GestureDetector(
        onTap: music.toggleIsland,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          width: double.infinity,
          height: music.isIslandExpanded ? 140 : 60,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black, // The "island" is always black
            borderRadius: BorderRadius.circular(music.isIslandExpanded ? 40 : 30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: music.isIslandExpanded
                ? ExpandedPlayerControls(track: track, music: music)
                : PillPlayerControls(track: track, music: music),
          ),
        ),
      ).animate().slideY(
            begin: -2.0,
            duration: 500.ms,
            curve: Curves.easeOutBack,
          ), // "Luxury" slide-in animation
    );
  }
}

/// The "Pill" (collapsed) state of the Dynamic Island.
class PillPlayerControls extends StatelessWidget {
  const PillPlayerControls({super.key, required this.track, required this.music});
  final MusicTrack track;
  final MusicProvider music;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            track.artworkUrl,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (c, o, s) => Container(width: 36, height: 36, color: track.gradientStart),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            track.title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          music.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 28,
        ),
      ],
    );
  }
}

/// The "Expanded" state of the Dynamic Island.
class ExpandedPlayerControls extends StatelessWidget {
  const ExpandedPlayerControls({super.key, required this.track, required this.music});
  final MusicTrack track;
  final MusicProvider music;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                track.artworkUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => Container(width: 50, height: 50, color: track.gradientStart),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    track.artist,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Icon(
              Icons.skip_previous_rounded,
              color: Colors.white70,
              size: 30,
            ),
            IconButton(
              icon: Icon(
                music.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 40,
              ),
              onPressed: music.togglePlayPause,
            ),
            const Icon(
              Icons.skip_next_rounded,
              color: Colors.white70,
              size: 30,
            ),
          ],
        )
      ],
    );
  }
}

// --- 6. FOCUS SCREEN ---

class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  // --- AR PLATFORM CHANNEL ---
  // This is the "bridge" to our native code.
  static const _arChannel = MethodChannel('com.elara.app/ar');

  // This function calls the native code.
  Future<void> _launchARHabitat() async {
    try {
      // This "invokeMethod" call is the magic.
      // It tells Flutter to run the native function named "launchAR".
      await _arChannel.invokeMethod('launchAR');
    } on PlatformException catch (e) {
      // Handle errors (e.g., AR is not supported on this device)
      debugPrint("Failed to launch AR: '${e.message}'.");
    }
  }
  // --- END AR PLATFORM CHANNEL ---

  @override
  Widget build(BuildContext context) {
    // This screen "consumes" the FocusTimerProvider
    // "watch" means this widget will rebuild every second (for the timer)
    final timer = context.watch<FocusProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Elara',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // This button now calls our native AR "bridge"
          IconButton(
            icon: const Icon(Icons.view_in_ar_outlined),
            onPressed: _launchARHabitat, // Hooked up!
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. The Circular Timer
            CircularPercentIndicator(
              radius: 140.0,
              lineWidth: 15.0,
              percent: timer.progress,
              // Reverse progress to count down
              progressColor: ProjectElara.sereneBlue,
              backgroundColor: ProjectElara.lightCharcoal,
              circularStrokeCap: CircularStrokeCap.round,
              reverse: true,
              center: Stack(
                alignment: Alignment.center,
                children: [
                  // This is the RIVE Pet Animation!
                  // It replaces the placeholder Icon.
                  _PetRiveAnimation(
                    petState: timer.petState,
                  ),

                  // Timer Text
                  Positioned(
                    bottom: 40,
                    child: Text(
                      timer.displayTime,
                      style: GoogleFonts.inter(
                        fontSize: 50,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),

            // 2. The Start/Stop Button (Neumorphic)
            NeumorphicButton(
              onPressed: () {
                // We use "read" here because we are *calling a function*,
                // not just reading a value.
                context.read<FocusProvider>().startStopTimer();
              },
              icon: timer.isRunning
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
            const SizedBox(height: 20),

            // 3. The Reset Button
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
              iconSize: 30,
              onPressed: () {
                context.read<FocusProvider>().resetTimer();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// This widget loads and controls the Rive Pet Animation.
class _PetRiveAnimation extends StatefulWidget {
  final PetState petState;
  const _PetRiveAnimation({required this.petState});

  @override
  State<_PetRiveAnimation> createState() => _PetRiveAnimationState();
}

class _PetRiveAnimationState extends State<_PetRiveAnimation> {
  Artboard? _riveArtboard;
  SMIInput<String>? _stateInput;

  @override
  void initState() {
    super.initState();
    // Load the Rive file
    rootBundle.load('assets/pet.riv').then(
      (data) async {
        try {
          final file = RiveFile.import(data);
          final artboard = file.mainArtboard;
          // Find the State Machine Controller
          var controller =
              StateMachineController.fromArtboard(artboard, 'State Machine 1');
          if (controller != null) {
            artboard.addController(controller);
            // Find the "state" input we created in the Rive editor
            _stateInput = controller.findInput<String>('state');
          }
          setState(() {
            _riveArtboard = artboard;
            // Set the initial state
            _stateInput?.value = 'IDLE';
          });
        } catch (e) {
          debugPrint('Error loading Rive file: $e');
        }
      },
    );
  }

  @override
  void didUpdateWidget(covariant _PetRiveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petState != widget.petState) {
      // This is the "magic" that connects our Provider to the animation!
      switch (widget.petState) {
        case PetState.idle:
          _stateInput?.value = 'IDLE';
          break;
        case PetState.focused:
          _stateInput?.value = 'FOCUSED';
          break;
        case PetState.sad:
          _stateInput?.value = 'SAD';
          break;
        case PetState.celebrating:
          _stateInput?.value = 'CELEBRATING';
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: _riveArtboard == null
          ? const Center(child: CircularProgressIndicator())
          : Rive(
              artboard: _riveArtboard!,
              fit: BoxFit.contain,
            ),
    );
  }
}

/// A "Neumorphic" (Soft UI) button for the premium feel.
class NeumorphicButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;

  const NeumorphicButton({
    super.key,
    required this.onPressed,
    required this.icon,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: ProjectElara.darkCharcoal, // Use theme color
          shape: BoxShape.circle,
          // This is the "Neumorphic" shadow magic
          boxShadow: _isPressed
              ? [] // "Pressed" state
              : [
                  // "Unpressed" state
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(8, 8),
                    blurRadius: 15,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.05),
                    offset: const Offset(-8, -8),
                    blurRadius: 15,
                  ),
                ],
        ),
        child: Icon(
          widget.icon,
          size: 60,
          color: ProjectElara.sereneBlue,
        ),
      ),
    );
  }
}

// --- 7. TODO SCREEN ---

class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});
  @override
  Widget build(BuildContext context) {
    // This screen "consumes" the TodoProvider
    return Consumer<TodoProvider>(
      builder: (context, todo, child) {
        return Scaffold(
          // Use a CustomScrollView for the "Things 3" feel
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                title: Text(
                  'To-Do List',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
                backgroundColor: ProjectElara.darkCharcoal.withOpacity(0.8),
                elevation: 0,
              ),
              // A list of the tasks
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final task = todo.tasks[index];
                    return TodoItem(
                      task: task,
                      onToggle: () => todo.toggleTask(task.id),
                      onDismiss: (direction) => todo.removeTask(task.id),
                    );
                  },
                  childCount: todo.tasks.length,
                ),
              ),
              // Spacer at the bottom so the list doesn't hide
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
          // Stack the input field on top
          bottomSheet: const TodoInputField(),
        );
      },
    );
  }
}

/// A "Glassmorphism" input field for new tasks.
class TodoInputField extends StatefulWidget {
  const TodoInputField({super.key});

  @override
  State<TodoInputField> createState() => _TodoInputFieldState();
}

class _TodoInputFieldState extends State<TodoInputField> {
  final _controller = TextEditingController();

  void _submit() {
    context.read<TodoProvider>().addTask(_controller.text);
    _controller.clear();
    FocusScope.of(context).unfocus(); // Dismiss keyboard
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, 15, 20, 15 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: TextField(
            controller: _controller,
            onSubmitted: (value) => _submit(),
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add a new task...',
              // Your "natural language" prompt
              hintStyle: GoogleFonts.inter(color: Colors.white54),
              filled: true,
              fillColor: ProjectElara.lightCharcoal.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add, color: ProjectElara.sereneBlue),
                onPressed: _submit,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single, custom-styled Todo item.
class TodoItem extends StatelessWidget {
  final Todo task;
  final VoidCallback onToggle;
  final DismissDirectionCallback onDismiss;

  const TodoItem({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // The "Celebratory" micro-interaction:
    // When the task isDone, animate in.
    final bool isDone = task.isDone;

    return Dismissible(
      key: Key(task.id),
      onDismissed: onDismiss,
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.withOpacity(0.7),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: ListTile(
        onTap: onToggle,
        leading: GestureDetector(
          onTap: onToggle,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDone ? Colors.transparent : Colors.white54,
                width: 2,
              ),
              color: isDone ? ProjectElara.sereneBlue : Colors.transparent,
            ),
            child: isDone
                ? const Icon(Icons.check, color: Colors.black, size: 18)
                : null,
          ).animate(target: isDone ? 1 : 0).scale(
                duration: 300.ms,
                curve: Curves.easeOutBack,
              ), // This is the "celebratory" animation!
        ),
        title: Text(
          task.title,
          style: GoogleFonts.inter(
            color: isDone ? Colors.white54 : Colors.white,
            decoration: isDone ? TextDecoration.lineThrough : null,
            decorationColor: Colors.white54,
          ),
        ),
      ),
    );
  }
}

// --- 8. MUSIC SCREEN ---

class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This screen "consumes" the MusicProvider
    final music = context.watch<MusicProvider>();

    return Scaffold(
      // Use a CustomScrollView for the "Headspace" feel
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(
              'Focus Music',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ProjectElara.darkCharcoal.withOpacity(0.8),
            elevation: 0,
          ),
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Curated for Focus',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Grid of music tracks
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = music.playlist[index];
                  return MusicTrackCard(
                    track: track,
                    onPlay: () => context.read<MusicProvider>().playTrack(track),
                  );
                },
                childCount: music.playlist.length,
              ),
            ),
          ),
          // Spacer at the bottom
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }
}

/// A "Headspace" inspired card for the music library.
class MusicTrackCard extends StatelessWidget {
  final MusicTrack track;
  final VoidCallback onPlay;

  const MusicTrackCard({
    super.key,
    required this.track,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 20),
      child: Stack(
        children: [
          // Background Image & Gradient
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: NetworkImage(track.artworkUrl),
                fit: BoxFit.cover,
                onError: (e, s) => const SizedBox(), // Handle image load error
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  track.gradientStart.withOpacity(0.8),
                  track.gradientEnd.withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Content
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPlay,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        track.title,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        track.artist,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Play Button
          Positioned(
            top: 20,
            right: 20,
            child: GestureDetector(
              onTap: onPlay,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.1);
  }
}

// --- 9. AI COACH SCREEN ---

class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});
  @override
  Widget build(BuildContext context) {
    // This screen consumes the UserProvider to get AI data
    final user = context.watch<UserProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(
              'AI Coach',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ProjectElara.darkCharcoal.withOpacity(0.8),
            elevation: 0,
          ),
          
          // 1. "Focus Quality" Card
          SliverToBoxAdapter(
            child: FocusQualityCard(
              score: user.focusQualityScore,
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
          ),

          // 2. "Proactive Nudge" Card
          SliverToBoxAdapter(
            child: ProactiveNudgeCard(
              nudge: user.proactiveNudge,
            ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.1),
          ),

          // 3. "Time by Subject" Chart
          SliverToBoxAdapter(
            child: SubjectBarChart(
              data: user.timeBySubject,
            ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.1),
          ),

          // 4. "Productivity Heatmap"
          SliverToBoxAdapter(
            child: HeatmapGrid(
              data: user.heatmapData,
            ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.1),
          ),
          
          // Spacer
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }
}

// --- AI COACH WIDGETS ---

/// The "Market-Killer" Metric: Focus Quality
class FocusQualityCard extends StatelessWidget {
  final double score;
  const FocusQualityCard({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ProjectElara.lightCharcoal,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Focus Quality Score',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  score.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: ProjectElara.sereneBlue,
                  ),
                ),
              ],
            ),
          ),
          CircularPercentIndicator(
            radius: 40.0,
            lineWidth: 8.0,
            percent: score / 10.0,
            progressColor: ProjectElara.sereneBlue,
            backgroundColor: Colors.white10,
            circularStrokeCap: CircularStrokeCap.round,
            center: Text(
              '${(score * 10).toInt()}%',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Proactive Nudge" UI
class ProactiveNudgeCard extends StatelessWidget {
  final String nudge;
  const ProactiveNudgeCard({super.key, required this.nudge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // Glassmorphism!
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: ProjectElara.sereneBlue, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              nudge,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Time by Subject" Bar Chart
class SubjectBarChart extends StatelessWidget {
  final Map<String, double> data;
  const SubjectBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: ProjectElara.lightCharcoal,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Time by Subject',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.entries.map((entry) {
              final color = _getColorForTag(entry.key);
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 100 * entry.value,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.key,
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getColorForTag(String tag) {
    if (tag == '#School') return ProjectElara.sereneBlue;
    if (tag == '#Creative') return Colors.purple[300]!;
    if (tag == '#Admin') return Colors.green[300]!;
    return Colors.grey;
  }
}

/// The "Productivity Heatmap"
class HeatmapGrid extends StatelessWidget {
  final List<double> data; // 7 days
  const HeatmapGrid({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: ProjectElara.lightCharcoal,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Productivity Heatmap (Last 7 Days)',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              return Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ProjectElara.sereneBlue.withOpacity(data[index]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    days[index],
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// --- 10. ACCOUNT SCREEN ---

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) {
    // This is the "Trophy Case" / Store UI
    return DefaultTabController(
      length: 2, // "Trophies" and "Store"
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                stretch: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: const UserProfileHeader(),
                  title: Text(
                    'My Account',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  centerTitle: false,
                  titlePadding:
                      EdgeInsets.only(left: 20, bottom: 16 + (Theme.of(context).platform == TargetPlatform.iOS ? 44 : 56)), // Adjust padding for TabBar
                ),
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Trophies'),
                    Tab(text: 'Store'),
                  ],
                ),
              ),
            ];
          },
          body: const TabBarView(
            children: [
              AchievementTab(),
              StoreTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// --- ACCOUNT SCREEN WIDGETS ---

/// The Header for the Account screen
class UserProfileHeader extends StatelessWidget {
  const UserProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    // Get the top padding (safe area)
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        color: ProjectElara.lightCharcoal,
      ),
      child: Padding(
        padding: EdgeInsets.only(top: topPadding + 60, left: 20, right: 20), // Adjust for status bar + app bar
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. The Gradient Title
            GradientTitle(
              title: user.gradientTitle,
              colors: user.gradientColors,
            ),

            const SizedBox(height: 30),

            // 2. The Stats Grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatItem(value: '${user.level}', label: 'Level'),
                StatItem(
                    value: '${user.cumulativeHours}', label: 'Hours'),
                const StatItem(value: '30', label: 'Day Streak'), // This is hardcoded, pull from provider
              ],
            ),

            const SizedBox(height: 30),

            // 3. The XP Bar
            Text(
              'Level ${user.level}  •  ${user.xpDisplay}',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            LinearPercentIndicator(
              percent: user.xpProgress,
              progressColor: ProjectElara.sereneBlue,
              backgroundColor: Colors.white10,
              lineHeight: 10,
              barRadius: const Radius.circular(5),
            ),
          ],
        ),
      ),
    );
  }
}

/// A "Stat" item for the grid
class StatItem extends StatelessWidget {
  final String value;
  final String label;
  const StatItem({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
        ),
      ],
    );
  }
}

/// Your "Gradient Title" widget.
/// It uses Shimmer to create the "animated iridescent" effect.
class GradientTitle extends StatelessWidget {
  final String title;
  final List<Color> colors;

  const GradientTitle({super.key, required this.title, required this.colors});

  @override
  Widget build(BuildContext context) {
    final text = Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 42,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );

    // Only apply the "shimmer" for Tier 4 (Legendary)
    if (colors.length > 2) {
      return Shimmer(
        gradient: LinearGradient(colors: colors, stops: const [0.1, 0.5, 0.9]),
        period: 2000.ms, // Make the shimmer slower
        child: text,
      );
    }

    // Otherwise, just a standard gradient
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: text,
    );
  }
}

/// The "Trophy Case" Tab
class AchievementTab extends StatelessWidget {
  const AchievementTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: user.achievements.length,
      itemBuilder: (context, index) {
        final ach = user.achievements[index];
        final isUnlocked = ach.isUnlocked;

        return Container(
          decoration: BoxDecoration(
            color: isUnlocked
                ? ProjectElara.lightCharcoal
                : ProjectElara.lightCharcoal.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isUnlocked ? ach.icon : Icons.lock_outline,
                size: 40,
                color: isUnlocked
                    ? ProjectElara.sereneBlue
                    : Colors.white24,
              ),
              const SizedBox(height: 10),
              Text(
                ach.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: isUnlocked ? Colors.white : Colors.white54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The "Store" Tab (Pillar 3)
class StoreTab extends StatelessWidget {
  const StoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    // This is a placeholder for your "premium boutique" UI.
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 1. "Buy Gems" (Hard Currency)
        Text(
          'Get Gems',
          style: GoogleFonts.inter(
              fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        const StoreItem(
          title: 'Small Pouch',
          description: '100 Gems',
          price: '\$0.99',
          color: ProjectElara.sereneBlue,
        ),
        const StoreItem(
          title: 'Standard Box',
          description: '550 Gems (10% Bonus)',
          price: '\$4.99',
          color: Colors.green,
        ),
        const StoreItem(
          title: 'Large Crate',
          description: '1200 Gems (20% Bonus)',
          price: '\$9.99',
          color: Colors.purple,
        ),
        const SizedBox(height: 30),

        // 2. "Spend Coins" (Soft Currency)
        Text(
          'Coin Shop',
          style: GoogleFonts.inter(
              fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        const StoreItem(
          title: 'Mystery Box',
          description: 'A chance at rare items!',
          price: '500 Coins',
          color: ProjectElara.lightCharcoal,
        ),
      ],
    );
  }
}

/// A Reusable "Store Item" widget.
class StoreItem extends StatelessWidget {
  final String title;
  final String description;
  final String price;
  final Color color;

  const StoreItem({
    super.key,
    required this.title,
    required this.description,
    required this.price,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ProjectElara.lightCharcoal,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
                Text(
                  description,
                  style: GoogleFonts.inter(color: Colors.white70),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(price, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}