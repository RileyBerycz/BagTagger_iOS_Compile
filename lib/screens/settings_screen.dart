import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bag_data.dart';
import '../models/item_model.dart';

class SettingsScreen extends StatefulWidget {
  final BagManager bagManager;
  
  const SettingsScreen({super.key, required this.bagManager});
  
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBusy = false;
  final _importController = TextEditingController();
  
  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
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
    final String importData = _importController.text.trim();
    
    if (importData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste exported data')),
      );
      return;
    }
    
    setState(() => _isBusy = true);
    
    try {
      final Map<String, dynamic> importedJson = jsonDecode(importData);
      
      // Confirm import
      final bool? confirmImport = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Data'),
          content: Text('This will import ${importedJson.length} bags. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      
      if (confirmImport != true) {
        setState(() => _isBusy = false);
        return;
      }
      
      // Process import
      int imported = 0;
      int skipped = 0;
      
      for (final entry in importedJson.entries) {
        final String code = entry.key;
        final List<dynamic> itemsJson = entry.value as List<dynamic>;
        
        if (widget.bagManager.bags.containsKey(code)) {
          skipped++;
          continue;
        }
        
        final List<Item> items = itemsJson
            .map((json) => Item.fromJson(json as Map<String, dynamic>))
            .toList();
        await widget.bagManager.createBag(items, customCode: code);
        imported++;
      }
      
      // Clear the input field
      _importController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $imported bags. Skipped $skipped (code conflicts).')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    } finally {
      setState(() => _isBusy = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Data Management', 
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Export your data to save or transfer between devices. '
                       'Import previously exported data to restore your bags.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isBusy ? null : _exportData,
            icon: const Icon(Icons.upload),
            label: const Text('Export Data (Copy to Clipboard)'),
          ),
          const SizedBox(height: 24),
          const Text('Import Data:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _importController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Paste exported data here',
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _isBusy ? null : _importData,
            icon: const Icon(Icons.download),
            label: const Text('Import Data'),
          ),
          if (_isBusy)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}