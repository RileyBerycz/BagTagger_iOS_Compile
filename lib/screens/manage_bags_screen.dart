import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/bag_data.dart';
import '../models/item_model.dart';
import '../data/database_helper.dart';
import 'bag_detail_screen.dart';

class ManageBagsScreen extends StatefulWidget {
  final BagManager bagManager;
  
  const ManageBagsScreen({super.key, required this.bagManager});
  
  @override
  State<ManageBagsScreen> createState() => _ManageBagsScreenState();
}

class _ManageBagsScreenState extends State<ManageBagsScreen> {
  bool _isLoading = false;
  
  Future<void> _deleteBag(String code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bag'),
        content: Text('Are you sure you want to delete bag $code?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      
      try {
        await widget.bagManager.deleteBag(code);
        setState(() {});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting bag: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _deleteAllBags() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Bags'),
        content: const Text(
          'Are you sure you want to delete ALL bags? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      
      try {
        final db = DatabaseHelper.instance;
        await db.clearAllBags();
        await widget.bagManager.loadBags();
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All bags have been deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting bags: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _exportData() async {
    setState(() => _isLoading = true);
    
    try {
      // Convert bags to JSON
      final Map<String, dynamic> exportData = {};
      
      widget.bagManager.bags.forEach((code, items) {
        exportData[code] = items.map((item) => item.toJson()).toList();
      });
      
      final jsonString = jsonEncode(exportData);
      
      // Show dialog BEFORE copying to clipboard
      final exportOption = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Data'),
          content: const Text(
            'Choose how you want to export your bag data:'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'clipboard'),
              child: const Text('Copy to Clipboard'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'file'),
              child: const Text('Save as File'),
            ),
          ],
        ),
      );
      
      // Handle the user's choice
      if (exportOption == 'clipboard') {
        // Copy to clipboard
        await Clipboard.setData(ClipboardData(text: jsonString));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data copied to clipboard')),
          );
        }
      } else if (exportOption == 'file') {
        // Save to file implementation
        try {
          final timestamp = DateTime.now().toString().replaceAll(RegExp(r'[: .]'), '_');
          final fileName = 'all_data_bag_tagger.db_$timestamp.json';
          
          // Platform-specific file saving
          if (Platform.isAndroid || Platform.isIOS) {
            // Mobile implementation
            final directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
            final filePath = '${directory.path}/$fileName';
            final file = File(filePath);
            await file.writeAsString(jsonString);
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('File saved to: $filePath')),
              );
            }
          } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
            // Desktop implementation
            final saveResult = await FilePicker.platform.saveFile(
              dialogTitle: 'Save Bag Data',
              fileName: fileName,
              allowedExtensions: ['json'],
              type: FileType.custom,
            );
            
            if (saveResult != null) {
              final file = File(saveResult);
              await file.writeAsString(jsonString);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('File saved successfully')),
                );
              }
            }
          } else {
            // Web or other platforms - not implemented
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File saving not supported on this platform')),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving file: $e')),
            );
          }
        }
      }
      // If 'cancel' or null, do nothing
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _importData() async {
    setState(() => _isLoading = true);
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      );
      
      if (result == null || result.files.single.path == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      
      // Confirm import strategy
      bool shouldReplace = await showDialog<bool>(
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
      
      // Reload bags
      await widget.bagManager.loadBags();
      setState(() {}); // Refresh UI
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully imported $importedBags bags')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final bags = widget.bagManager.bags;
    
    return Scaffold(
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _exportData,
                            icon: const Icon(Icons.upload),
                            label: const Text('Export'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _importData,
                            icon: const Icon(Icons.download),
                            label: const Text('Import'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isLoading || bags.isEmpty ? null : _deleteAllBags,
                      icon: const Icon(Icons.delete_forever),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      label: const Text('Delete All Bags'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: bags.isEmpty
                  ? const Center(child: Text('No bags created yet'))
                  : ListView.builder(
                      itemCount: bags.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final code = bags.keys.elementAt(index);
                        final items = bags[code]!;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('Bag: $code'),
                            subtitle: Text('${items.length} items'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility),
                                  tooltip: 'View Details',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => BagDetailScreen(
                                          bagManager: widget.bagManager,
                                          bagCode: code,
                                        ),
                                      ),
                                    ).then((_) => setState(() {}));
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  tooltip: 'Delete Bag',
                                  onPressed: () => _deleteBag(code),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BagDetailScreen(
                                    bagManager: widget.bagManager,
                                    bagCode: code,
                                  ),
                                ),
                              ).then((_) => setState(() {}));
                            },
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
    );
  }
}