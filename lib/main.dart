import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'models/bag_data.dart';
import 'screens/create_bag.dart';
import 'screens/lookup_bag.dart';
import 'screens/search_item.dart';
import 'screens/manage_bags_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/account_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for desktop platforms
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize BagManager
  final bagManager = BagManager();
  await bagManager.loadBags(); // Load bags here

  runApp(MyApp(bagManager: bagManager));
}

class MyApp extends StatelessWidget {
  final BagManager bagManager;

  const MyApp({Key? key, required this.bagManager}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BagTagger',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: HomeScreen(bagManager: bagManager),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final BagManager bagManager;

  const HomeScreen({Key? key, required this.bagManager}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await widget.bagManager.loadBags();
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          error = e.toString();
        });
      }
      print("Error initializing app: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading bags...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeApp,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BagTagger'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.add), text: 'Create'),
              Tab(icon: Icon(Icons.search), text: 'Lookup'),
              Tab(icon: Icon(Icons.find_in_page), text: 'Search'),
              Tab(icon: Icon(Icons.list), text: 'Manage Bags'),
              Tab(icon: Icon(Icons.account_circle), text: 'Account'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
            ],
            labelColor: Colors.white,
          ),
        ),
        body: TabBarView(
          children: [
            CreateBagScreen(bagManager: widget.bagManager),
            LookupBagScreen(bagManager: widget.bagManager),
            SearchItemScreen(bagManager: widget.bagManager),
            ManageBagsScreen(bagManager: widget.bagManager),
            AccountScreen(bagManager: widget.bagManager),
            SettingsScreen(bagManager: widget.bagManager),
          ],
        ),
      ),
    );
  }
}