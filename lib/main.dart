import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Add this import
import 'models/bag_data.dart';
import 'screens/create_bag.dart';
import 'screens/lookup_bag.dart';
import 'screens/search_item.dart';

void main() async {
  // Initialize FFI for Windows SQLite support
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create and initialize the BagManager
  final bagManager = BagManager();
  
  // Run the app with a FutureBuilder to handle loading
  runApp(MyApp(bagManager: bagManager));
}

class MyApp extends StatelessWidget {
  final BagManager bagManager;
  
  const MyApp({super.key, required this.bagManager});

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
  
  const HomeScreen({super.key, required this.bagManager});

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
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        error = e.toString();
      });
      print("Error initializing app: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BagTagger'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.add), text: 'Create'),
              Tab(icon: Icon(Icons.search), text: 'Lookup'),
              Tab(icon: Icon(Icons.find_in_page), text: 'Search'),
            ],
            labelColor: Colors.white,
          ),
        ),
        body: TabBarView(
          children: [
            CreateBagScreen(bagManager: widget.bagManager),
            LookupBagScreen(bagManager: widget.bagManager),
            SearchItemScreen(bagManager: widget.bagManager),
          ],
        ),
      ),
    );
  }
}