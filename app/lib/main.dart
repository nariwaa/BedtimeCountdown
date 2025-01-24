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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.yellow),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.yellow,
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
      appBar: AppBar(title: const Text('Bedtime Countdown')),
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

  @override
  void dispose() {
    timer?.cancel();
    if (wakeUpTime != null) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_wakeUpTimeKey, wakeUpTime!.toIso8601String());
      });
    }
    super.dispose();
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

  String _format(Duration d) => [d.inHours, d.inMinutes.remainder(60), d.inSeconds.remainder(60)]
      .map((e) => e.toString().padLeft(2, '0'))
      .join(':');

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (wakeUpTime == null)
            ElevatedButton(
              onPressed: _pickTime,
              child: const Text('SET WAKE-UP TIME'),
            )
          else ...[
            Text('Wake-up: ${DateFormat('hh:mm a').format(wakeUpTime!)}'),
            Text('Bedtime: ${DateFormat('hh:mm a').format(bedtime!)}'),
            const SizedBox(height: 20),
            Text(
              remaining.inSeconds > 0 ? _format(remaining) : 'TIME TO SLEEP!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickTime,
              child: const Text('CHANGE WAKE-UP TIME'),
            ),
          ],
        ],
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
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Hours Before Bedtime:', style: TextStyle(fontSize: 20)),
            Text('${_hours.round()}', style: const TextStyle(fontSize: 24)),
            Slider(
              value: _hours,
              min: 1,
              max: 12,
              divisions: 11,
              label: '${_hours.round()}',
              onChanged: _saveHours,
            ),
          ],
        ),
      ),
    );
  }
}