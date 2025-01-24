import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bedtime Countdown',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 1;

  void _onItemTapped(int index) {
    if (index == 0) {
      _launchAlarmApp();
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  Future<void> _launchAlarmApp() async {
    const url = 'alarm:';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open alarm app')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening alarm app')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 1 ? null : AppBar(title: const Text('Bedtime Countdown')),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          Placeholder(),
          HomeContent(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.alarm),
            label: 'Alarm',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        elevation: 2,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  DateTime? wakeUpTime;
  DateTime? bedtime;
  Duration remaining = Duration.zero;
  Timer? timer;
  int hoursBeforeBed = 9;

  static const String _wakeUpTimeKey = 'wakeUpTime';
  static const String _hoursBeforeBedKey = 'hoursBeforeBed';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hoursBeforeBed = prefs.getInt(_hoursBeforeBedKey) ?? 9;
      final savedTime = prefs.getString(_wakeUpTimeKey);
      if (savedTime != null) {
        wakeUpTime = DateTime.parse(savedTime);
        final now = DateTime.now();
        if (wakeUpTime!.isBefore(now)) {
          wakeUpTime = wakeUpTime!.add(const Duration(days: 1));
        }
        bedtime = wakeUpTime!.subtract(Duration(hours: hoursBeforeBed));
        _startTimer();
      }
    });
  }

  void _cancelCountdown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wakeUpTimeKey);

    setState(() {
      timer?.cancel();
      wakeUpTime = null;
      bedtime = null;
      remaining = Duration.zero;
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;

    final now = DateTime.now();
    DateTime selected = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (selected.isBefore(now)) selected = selected.add(const Duration(days: 1));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wakeUpTimeKey, selected.toIso8601String());

    setState(() {
      wakeUpTime = selected;
      bedtime = selected.subtract(Duration(hours: hoursBeforeBed));
    });
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (bedtime == null) return;
      final now = DateTime.now();
      setState(() => remaining = bedtime!.isAfter(now) ? bedtime!.difference(now) : Duration.zero);
    });
  }

  String _format(Duration d) {
    if (wakeUpTime == null) return "--:--:--";
    return [d.inHours, d.inMinutes.remainder(60), d.inSeconds.remainder(60)]
        .map((e) => e.toString().padLeft(2, '0'))
        .join(':');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      Colors.amber.shade300,
                      Colors.orange.shade300,
                    ],
                  ).createShader(bounds),
                  child: Text(
                    _format(remaining),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (wakeUpTime != null) ...[
                const SizedBox(height: 40),
                _buildTimeCard(
                  icon: Icons.wb_sunny,
                  title: 'Wake-up Time',
                  time: DateFormat('hh:mm a').format(wakeUpTime!),
                ),
                const SizedBox(height: 20),
                _buildTimeCard(
                  icon: Icons.nightlight,
                  title: 'Bedtime',
                  time: DateFormat('hh:mm a').format(bedtime!),
                ),
              ],
            ],
          ),

          if (wakeUpTime != null)
            _buildActionButtons()
          else
            _buildSetTimeButton(),
        ],
      ),
    );
  }

  Widget _buildTimeCard({required IconData icon, required String title, required String time}) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 32, color: Colors.amber),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  Text(time, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildButton(
            icon: Icons.edit,
            label: 'Change Time',
            onPressed: _pickTime,
            isPrimary: true,
          ),
          const SizedBox(width: 16),
          _buildButton(
            icon: Icons.cancel,
            label: 'Cancel',
            onPressed: _cancelCountdown,
            isPrimary: false,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return isPrimary
        ? FilledButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    )
        : OutlinedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildSetTimeButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SizedBox(
        width: double.infinity,
        child: _buildButton(
          icon: Icons.access_time,
          label: 'SET WAKE-UP TIME',
          onPressed: _pickTime,
          isPrimary: true,
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _hours = 9;

  @override
  void initState() {
    super.initState();
    _loadHours();
  }

  void _loadHours() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _hours = (prefs.getInt('hoursBeforeBed') ?? 9).toDouble());
  }

  void _saveHours(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hoursBeforeBed', value.round());

    final homeContentState = context.findAncestorStateOfType<_HomeContentState>();
    if (homeContentState != null && homeContentState.wakeUpTime != null) {
      homeContentState.setState(() {
        homeContentState.hoursBeforeBed = value.round();
        homeContentState.bedtime = homeContentState.wakeUpTime!
            .subtract(Duration(hours: value.round()));
      });
    }

    setState(() => _hours = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Sleep Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            const Icon(Icons.timer, size: 48, color: Colors.amber),
            const SizedBox(height: 24),
            Text(
              '${_hours.round()} hours',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Slider(
              value: _hours,
              min: 1,
              max: 12,
              divisions: 11,
              label: '${_hours.round()} hours before bed',
              onChanged: _saveHours,
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Colors.grey[300],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Adjust the time between bedtime and your wake-up time',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}