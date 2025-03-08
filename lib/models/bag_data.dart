import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/database_helper.dart';
import 'item_model.dart';

class BagManager extends ChangeNotifier {
  static Database? _database;
  final DatabaseHelper _db = DatabaseHelper.instance;
  Map<String, List<Item>> bags = {};

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initializeDatabase();
    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    // Get the application documents directory
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String dbPath = join(appDocDir.path, 'bag_tagger.db');

    // Open the database at the specified path
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE
      )
    ''');
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bagId INTEGER,
        name TEXT,
        descriptors TEXT,
        image TEXT,
        FOREIGN KEY (bagId) REFERENCES bags(id)
      )
    ''');
  }

  // Load bags from database
  Future<void> loadBags() async {
    try {
      print("Starting to load bags from DatabaseHelper");
      // Use the DatabaseHelper to get bags instead of direct DB access
      bags = await _db.getAllBags();
      print("Loaded ${bags.length} bags");
    } catch (e) {
      print("Error loading bags: $e");
      bags = {};
      rethrow;
    }
  }

  // Generate a random bag code
  String generateCode({int length = 6}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    
    String code;
    do {
      code = String.fromCharCodes(
        List.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
      );
    } while (bags.containsKey(code));
    
    return code;
  }

  // Create a new bag
  Future<String> createBag(List<Item> items, {String? customCode}) async {
    final code = customCode ?? generateCode();
    
    try {
      // Try to insert bag in database with REPLACE conflict strategy
      await _db.insertBag(code, conflictAlgorithm: ConflictAlgorithm.replace);
      
      // If we're replacing an existing bag, first delete any old items
      if (bags.containsKey(code)) {
        await _deleteAllItems(code);
      }
      
      // Insert all items
      for (var item in items) {
        await _db.insertItem(code, item);
      }
      
      // Update in-memory cache
      bags[code] = List.from(items);
      
      return code;
    } catch (e) {
      print("Error creating bag: $e");
      throw e;
    }
  }
  
  // Update bag code
  Future<bool> updateBagCode(String oldCode, String newCode) async {
    if (bags.containsKey(newCode) && oldCode != newCode) {
      return false; // Code already exists
    }
    
    await _db.updateBagId(oldCode, newCode);
    
    // Update in-memory cache
    if (bags.containsKey(oldCode)) {
      bags[newCode] = bags[oldCode]!;
      bags.remove(oldCode);
    }
    
    return true;
  }

  // Look up bag by code
  List<Item>? lookupBag(String code) {
    return bags[code.toUpperCase()];
  }
  
  // Add item to bag
  Future<void> addItemToBag(String code, Item item) async {
    await _db.insertItem(code, item);
    
    // Update in-memory cache
    if (bags.containsKey(code)) {
      bags[code]!.add(item);
    } else {
      bags[code] = [item];
    }
  }
  
  // Remove item from bag
  Future<void> removeItemFromBag(String code, int index) async {
    if (!bags.containsKey(code) || index >= bags[code]!.length) {
      return;
    }
    
    // We need the item ID to delete it
    // This is a simplification - in the real implementation, 
    // items should store their database IDs
    var items = await _db.getItemsForBag(code);
    if (index < items.length) {
      // For simplicity, assuming indexes match
      // In reality, you'd need to track item IDs
      await _db.deleteItem(index + 1); // Simplified - should use actual ID
    }
    
    // Update in-memory cache
    bags[code]!.removeAt(index);
  }
  
  // Update item in bag
  Future<void> updateItemInBag(String code, Item updatedItem, int index) async {
    if (!bags.containsKey(code)) {
      return;
    }
    
    int targetIndex = index;
    
    // If index is invalid, try to find the item by name
    if (index < 0 || index >= bags[code]!.length) {
      targetIndex = bags[code]!.indexWhere((item) => item.name == updatedItem.name);
      if (targetIndex < 0) {
        return; // Item not found
      }
    }
    
    // Get current item to update in database
    final currentItem = bags[code]![targetIndex];
    
    // Update in database
    try {
      await _db.updateItemInBag(code, currentItem, updatedItem);
    } catch (e) {
      print("Error updating item in database: $e");
      throw e;
    }
    
    // Update in-memory cache
    bags[code]![targetIndex] = updatedItem;
    
    // Notify listeners
    notifyListeners();
  }

  // Search for an item
  Future<Map<String, List<Item>>> searchItem(String searchTerm) async {
    final Map<String, List<Item>> results = {};
    
    if (searchTerm.trim().isEmpty) {
      return results;
    }
    
    // Split search term into individual words
    final List<String> searchTerms = searchTerm.toLowerCase().split(' ')
      .where((term) => term.isNotEmpty).toList();
    
    // Helper function to calculate string similarity (0-1)
    double calculateSimilarity(String s1, String s2) {
      s1 = s1.toLowerCase();
      s2 = s2.toLowerCase();
      
      // Exact match
      if (s1 == s2) return 1.0;
      
      // Substring match
      if (s1.contains(s2) || s2.contains(s1)) {
        return 0.9;
      }
      
      // Calculate Levenshtein distance for short strings
      if (s1.length < 10 && s2.length < 10) {
        // Simple approximation of similarity based on common chars
        final Set<String> set1 = s1.split('').toSet();
        final Set<String> set2 = s2.split('').toSet();
        final double commonChars = set1.intersection(set2).length.toDouble();
        return commonChars / (set1.union(set2).length.toDouble());
      }
      
      return 0.0;
    }
    
    // Check if a string is similar to any search term
    bool isStringSimilarToAnyTerm(String string, List<String> terms) {
      for (final term in terms) {
        if (calculateSimilarity(string, term) > 0.7) {
          return true;
        }
      }
      return false;
    }
    
    // For each bag
    bags.forEach((bagCode, items) {
      final matchingItems = items.where((item) {
        // Check item name against all search terms
        if (searchTerms.any((term) => 
            isStringSimilarToAnyTerm(item.name.toLowerCase(), [term]))) {
          return true;
        }
        
        // Check each descriptor against all search terms
        for (var entry in item.descriptors.entries) {
          final key = entry.key.toLowerCase();
          final value = entry.value.toLowerCase();
          
          if (searchTerms.any((term) => 
              isStringSimilarToAnyTerm(key, [term]) || 
              isStringSimilarToAnyTerm(value, [term]))) {
            return true;
          }
          
          // Check descriptor's full content against the whole search term
          // This handles cases like "cheddar cheese" matching "Type: cheddar" and "Name: cheese"
          if (isStringSimilarToAnyTerm("$key $value", searchTerms) ||
              searchTerms.length > 1 && 
              searchTerms.every((term) => 
                  ("$key $value").toLowerCase().contains(term))) {
            return true;
          }
        }
        
        // Also try with the complete search phrase
        if (isStringSimilarToAnyTerm(item.name.toLowerCase(), [searchTerm.toLowerCase()])) {
          return true;
        }
        
        return false;
      }).toList();
      
      if (matchingItems.isNotEmpty) {
        results[bagCode] = matchingItems;
      }
    });
    
    return results;
  }
  
  // Delete a bag
  Future<void> deleteBag(String code) async {
    final db = await database;
    final bagId = await _getBagId(code);
    if (bagId == null) return;

    await db.delete(
      'items',
      where: 'bagId = ?',
      whereArgs: [bagId],
    );
    await db.delete(
      'bags',
      where: 'id = ?',
      whereArgs: [bagId],
    );
    bags.remove(code);
  }

  Future<void> replaceAllBags(Map<String, List<Item>> newBags) async {
    // Clear database
    await _db.clearAllBags();
    
    // Update with new bags
    for (final entry in newBags.entries) {
      final bagCode = entry.key;
      final items = entry.value;
      
      // Add to database
      await _db.createBag(bagCode);
      for (final item in items) {
        await _db.addItemToBag(bagCode, item);
      }
    }
    
    // Update in-memory bags
    bags.clear();
    bags.addAll(newBags);
  }

  Future<void> addBag(String code) async {
    final db = await database;
    await db.insert(
      'bags',
      {'code': code},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    bags[code] = [];
  }

  Future<void> addItem(String code, Item item) async {
    final db = await database;
    final bagId = await _getBagId(code);
    if (bagId == null) return;

    await db.insert(
      'items',
      {
        'bagId': bagId,
        'name': item.name,
        'descriptors': item.descriptors.entries.map((e) => '${e.key}:${e.value}').join(','),
        'image': item.image,
      },
    );
    bags[code]?.add(item);
  }

  Future<int?> _getBagId(String code) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'bags',
      columns: ['id'],
      where: 'code = ?',
      whereArgs: [code],
    );
    return result.isNotEmpty ? result.first['id'] as int : null;
  }
  
  // Delete all items for a bag
  Future<void> _deleteAllItems(String code) async {
    final db = await database;
    final bagId = await _getBagId(code);
    if (bagId == null) return;

    await db.delete(
      'items',
      where: 'bagId = ?',
      whereArgs: [bagId],
    );
  }

  Future<void> deleteItem(String code, Item item) async {
    final db = await database;
    final bagId = await _getBagId(code);
    if (bagId == null) return;

    await db.delete(
      'items',
      where: 'bagId = ? AND name = ? AND descriptors = ? AND image = ?',
      whereArgs: [bagId, item.name, item.descriptors, item.image],
    );
    bags[code]?.remove(item);
  }

  // Add this method
  Future<Map<String, List<Item>>> searchItemInDatabase(String searchTerm) async {
    final db = await database;
    final searchTermLower = searchTerm.toLowerCase();
    Map<String, List<Item>> results = {};

    for (var bagCode in bags.keys) {
      List<Item> matchedItems = [];
      final bagId = await _getBagId(bagCode);
      if (bagId == null) continue;

      final List<Map<String, dynamic>> itemMaps = await db.query(
        'items',
        where: 'bagId = ? AND (lower(name) LIKE ? OR lower(descriptors) LIKE ?)',
        whereArgs: [bagId, '%$searchTermLower%', '%$searchTermLower%'],
      );

      matchedItems = itemMaps.map((itemMap) => Item(
        name: itemMap['name'] as String,
        descriptors: (itemMap['descriptors'] as String?)?.split(',').fold<Map<String, String>>({}, (map, descriptor) {
          final parts = descriptor.split(':');
          if (parts.length == 2) {
            map[parts[0]] = parts[1];
          }
          return map;
        }) ?? {},
        image: itemMap['image'] as String?,
      )).toList();

      if (matchedItems.isNotEmpty) {
        results[bagCode] = matchedItems;
      }
    }

    return results;
  }

  // And add this helper method for importing:
  Future<int> importBagsFromJson(Map<String, dynamic> data, bool replaceExisting) async {
    int importedBags = 0;
    
    for (var entry in data.entries) {
      final bagId = entry.key;
      final itemsData = entry.value as List;
      
      try {
        // Use REPLACE if replacing, otherwise use IGNORE to skip existing
        final conflictAlgorithm = replaceExisting 
          ? ConflictAlgorithm.replace 
          : ConflictAlgorithm.ignore;
        
        // If replacing, first delete all items from the bag
        if (replaceExisting && bags.containsKey(bagId)) {
          await _db.deleteAllItemsFromBag(bagId);
        }
        
        // Create or replace the bag
        await _db.createBag(bagId, conflictAlgorithm: conflictAlgorithm);
        
        // Add all items
        for (var itemData in itemsData) {
          final item = Item(
            name: itemData['name'],
            descriptors: Map<String, String>.from(itemData['descriptors']),
            image: itemData['image'],
          );
          await _db.addItemToBag(bagId, item);
        }
        
        importedBags++;
      } catch (e) {
        print('Error importing bag $bagId: $e');
        // Continue with next bag
      }
    }
    
    // Reload bags after import
    await loadBags();
    
    return importedBags;
  }
}