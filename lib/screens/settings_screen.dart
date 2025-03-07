import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/bag_data.dart';
import '../models/item_model.dart';
import '../data/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  final BagManager bagManager;
  
  const SettingsScreen({super.key, required this.bagManager});
  
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBusy = false;
  final _importController = TextEditingController();
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  bool _isLoading = false;
  String _appVersion = '';
  
  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
    _getAppVersion();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDarkMode = prefs.getBool('darkMode') ?? false;
        _notificationsEnabled = prefs.getBool('notifications') ?? true;
      });
    }
  }
  
  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }
  
  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = '1.0.0'; // Fallback version
        });
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('Are you sure you want to delete all data? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirmed) {
      setState(() => _isLoading = true);
      try {
        // Clear database using the DatabaseHelper directly
        final db = DatabaseHelper.instance;
        await db.clearAllBags();
        await widget.bagManager.loadBags();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All data has been deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _optimizeDatabase() async {
    setState(() => _isLoading = true);
    try {
      // Get database instance
      final db = DatabaseHelper.instance;
      final database = await db.database;
      
      // Run simple optimization commands
      await database.execute('VACUUM');
      await database.execute('ANALYZE');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database optimized successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Optimization error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportData() async {
    setState(() => _isBusy = true);
    
    try {
      // Convert bags to JSON
      final Map<String, dynamic> exportData = {};
      
      widget.bagManager.bags.forEach((code, items) {
        exportData[code] = items.map((item) => item.toJson()).toList();
      });
      
      final jsonString = jsonEncode(exportData);
      
      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: jsonString));
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data copied to clipboard')),
        );
      }
      
      // Also save to shared preferences as backup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bag_tagger_export', jsonString);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      setState(() => _isBusy = false);
    }
  }
  
  Future<void> _importData() async {
    setState(() => _isBusy = true);
    
    try {
      final file = await _pickFile();
      if (file == null) {
        setState(() => _isBusy = false);
        return;
      }
      
      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      
      // First clear existing data if user confirms
      bool shouldReplace = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Strategy'),
          content: const Text('Do you want to replace existing bags with the same IDs? Choose "No" to skip existing bags.'),
          actions: [
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ) ?? false;
      
      int importedBags = 0;
      final db = DatabaseHelper.instance;
      
      // Process all bags
      for (var entry in data.entries) {
        final bagId = entry.key;
        final itemsData = entry.value as List;
        
        try {
          // Use REPLACE if replacing, otherwise use IGNORE to skip existing
          final conflictAlgorithm = shouldReplace 
            ? ConflictAlgorithm.replace 
            : ConflictAlgorithm.ignore;
          
          // If replacing, first delete all items from the bag
          if (shouldReplace) {
            await db.deleteAllItemsFromBag(bagId);
          }
          
          // Create or replace the bag
          await db.createBag(bagId, conflictAlgorithm: conflictAlgorithm);
          
          // Add all items
          for (var itemData in itemsData) {
            final item = Item(
              name: itemData['name'],
              descriptors: Map<String, String>.from(itemData['descriptors']),
              image: itemData['image'],
            );
            await db.addItemToBag(bagId, item);
          }
          
          importedBags++;
        } catch (e) {
          print('Error importing bag $bagId: $e');
          // Continue with next bag
        }
      }
      
      // Reload bags in BagManager
      await widget.bagManager.loadBags();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully imported $importedBags bags')),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    } finally {
      setState(() => _isBusy = false);
    }
  }
  
  Future<File?> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      );
      
      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      } else {
        // User canceled the picker
        return null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Theme settings
            const ListTile(
              title: Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold)),
              contentPadding: EdgeInsets.zero,
            ),
            Card(
              child: SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Enable dark theme'),
                value: _isDarkMode,
                onChanged: (value) {
                  setState(() {
                    _isDarkMode = value;
                  });
                  _saveSetting('darkMode', value);
                  // In a real app, you would update your theme here
                },
              ),
            ),

            const SizedBox(height: 16),
            
            // Notifications
            const ListTile(
              title: Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
              contentPadding: EdgeInsets.zero,
            ),
            Card(
              child: SwitchListTile(
                title: const Text('Enable Notifications'),
                subtitle: const Text('Get important updates and reminders'),
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  _saveSetting('notifications', value);
                },
              ),
            ),

            const SizedBox(height: 16),
            
            // Data Management
            const ListTile(
              title: Text('Data Management', style: TextStyle(fontWeight: FontWeight.bold)),
              contentPadding: EdgeInsets.zero,
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Clear App Data'),
                    subtitle: const Text('Delete all saved bags and items'),
                    trailing: const Icon(Icons.delete_forever),
                    onTap: _clearAllData,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Optimize Database'),
                    subtitle: const Text('Improve app performance'),
                    trailing: const Icon(Icons.speed),
                    onTap: _optimizeDatabase,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            
            // About
            const ListTile(
              title: Text('About', style: TextStyle(fontWeight: FontWeight.bold)),
              contentPadding: EdgeInsets.zero,
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Version'),
                    subtitle: Text(_appVersion),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Navigate to Terms of Service
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Navigate to Privacy Policy
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Send Feedback'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Open feedback form or email
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}