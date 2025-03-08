import 'dart:async';
import 'dart:convert'; // Added import for jsonEncode
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/item_model.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static DatabaseHelper get instance => _instance;
  
  static Database? _db;
  
  DatabaseHelper._internal();
  
  Future<Database> get database async {
    if (_db != null) return _db!;
    
    _db = await _initDatabase();
    return _db!;
  }
  
  Future<Database> _initDatabase() async {
    try {
      // Get proper application support directory for persistent storage
      Directory appDir;
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop platforms, use the app documents directory
        appDir = await getApplicationDocumentsDirectory();
        // Create a specific subfolder for your app
        final dbDir = Directory('${appDir.path}/BagTagger');
        if (!await dbDir.exists()) {
          await dbDir.create(recursive: true);
        }
        String path = join(dbDir.path, 'bag_tagger.db');
        debugPrint("Database path: $path");
        return await openDatabase(path, version: 1, onCreate: _onCreate);
      } else {
        // For mobile platforms, use the default path
        String path = join(await getDatabasesPath(), 'bag_tagger.db');
        debugPrint("Database path: $path");
        return await openDatabase(path, version: 1, onCreate: _onCreate);
      }
    } catch (e) {
      debugPrint("Error initializing database: $e");
      rethrow;
    }
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // Bags table
    await db.execute('''
      CREATE TABLE bags(
        id TEXT PRIMARY KEY,
        name TEXT,
        created_at INTEGER
      )
    ''');
    
    // Items table with bag reference
    await db.execute('''
      CREATE TABLE items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bag_id TEXT,
        name TEXT,
        image TEXT,
        FOREIGN KEY (bag_id) REFERENCES bags (id) ON DELETE CASCADE
      )
    ''');
    
    // Descriptors table with item reference
    await db.execute('''
      CREATE TABLE descriptors(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER,
        key TEXT,
        value TEXT,
        FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE CASCADE
      )
    ''');
  }
  
  // Bag operations
  Future<String> insertBag(String id, {String? name, ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort}) async {
    final db = await database;
    await db.insert(
      'bags',
      {
        'id': id,
        'name': name ?? '',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: conflictAlgorithm
    );
    return id;
  }
  
  // Alias for insertBag with standard parameters
  Future<void> createBag(String code, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort}) async {
    await insertBag(code, name: null, conflictAlgorithm: conflictAlgorithm);
  }
  
  Future<void> updateBagId(String oldId, String newId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('bags', {'id': newId}, where: 'id = ?', whereArgs: [oldId]);
      await txn.update('items', {'bag_id': newId}, where: 'bag_id = ?', whereArgs: [oldId]);
    });
  }
  
  Future<void> updateBagName(String id, String name) async {
    final db = await database;
    await db.update('bags', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }
  
  Future<void> deleteBag(String id) async {
    final db = await database;
    await db.delete('bags', where: 'id = ?', whereArgs: [id]);
  }
  
  Future<void> clearAllBags() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('descriptors');
      await txn.delete('items');
      await txn.delete('bags');
    });
  }
  
  // Item operations
  Future<int> insertItem(String bagId, Item item) async {
    final db = await database;
    int itemId = await db.insert('items', {
      'bag_id': bagId,
      'name': item.name,
      'image': item.image,
    });
    
    // Insert all descriptors
    for (var entry in item.descriptors.entries) {
      await db.insert('descriptors', {
        'item_id': itemId,
        'key': entry.key,
        'value': entry.value,
      });
    }
    
    return itemId;
  }
  
  // Alias for insertItem with standard parameters
  Future<void> addItemToBag(String code, Item item) async {
    await insertItem(code, item);
  }
  
  Future<void> updateItem(int id, Item item) async {
    final db = await database;
    await db.transaction((txn) async {
      // Update item
      await txn.update('items', {
        'name': item.name,
        'image': item.image,
      }, where: 'id = ?', whereArgs: [id]);
      
      // Delete old descriptors
      await txn.delete('descriptors', where: 'item_id = ?', whereArgs: [id]);
      
      // Insert new descriptors
      for (var entry in item.descriptors.entries) {
        await txn.insert('descriptors', {
          'item_id': id,
          'key': entry.key,
          'value': entry.value,
        });
      }
    });
  }
  
  Future<void> deleteItem(int id) async {
    final db = await database;
    await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }
  
  Future<void> deleteAllItemsFromBag(String bagId) async {
    final db = await database;
    
    // Get all items for this bag
    final items = await db.query('items', 
      columns: ['id'], 
      where: 'bag_id = ?', 
      whereArgs: [bagId]
    );
    
    // Delete all descriptors and items in a transaction
    await db.transaction((txn) async {
      for (var item in items) {
        int itemId = item['id'] as int;
        await txn.delete('descriptors', where: 'item_id = ?', whereArgs: [itemId]);
      }
      await txn.delete('items', where: 'bag_id = ?', whereArgs: [bagId]);
    });
  }
  
  Future<void> updateItemInBag(String bagId, Item oldItem, Item newItem) async {
    final db = await database;
    
    // Find the item ID by name
    final List<Map<String, dynamic>> result = await db.query(
      'items',
      columns: ['id'],
      where: 'bag_id = ? AND name = ?',
      whereArgs: [bagId, oldItem.name],
      limit: 1
    );
    
    if (result.isEmpty) {
      // Item not found, insert it as new
      await addItemToBag(bagId, newItem);
      return;
    }
    
    final itemId = result.first['id'] as int;
    
    // Update the item using a transaction
    await db.transaction((txn) async {
      // Update item basic info
      await txn.update('items', {
        'name': newItem.name,
        'image': newItem.image,
      }, where: 'id = ?', whereArgs: [itemId]);
      
      // Delete old descriptors
      await txn.delete('descriptors', where: 'item_id = ?', whereArgs: [itemId]);
      
      // Insert new descriptors
      for (var entry in newItem.descriptors.entries) {
        await txn.insert('descriptors', {
          'item_id': itemId,
          'key': entry.key,
          'value': entry.value,
        });
      }
    });
  }
  
  // Querying data
  Future<Map<String, List<Item>>> getAllBags() async {
    final db = await database;
    final bags = await db.query('bags', orderBy: 'created_at DESC');
    
    Map<String, List<Item>> result = {};
    
    for (var bag in bags) {
      String bagId = bag['id'] as String;
      List<Item> items = await getItemsForBag(bagId);
      result[bagId] = items;
    }
    
    return result;
  }
  
  Future<List<Item>> getItemsForBag(String bagId) async {
    final db = await database;
    final items = await db.query('items', where: 'bag_id = ?', whereArgs: [bagId]);
    
    List<Item> result = [];
    
    for (var item in items) {
      int itemId = item['id'] as int;
      String name = item['name'] as String;
      String? image = item['image'] as String?;
      
      // Get descriptors
      final descriptors = await db.query(
        'descriptors',
        where: 'item_id = ?',
        whereArgs: [itemId]
      );
      
      Map<String, String> descriptorMap = {};
      for (var desc in descriptors) {
        descriptorMap[desc['key'] as String] = desc['value'] as String;
      }
      
      result.add(Item(
        name: name,
        descriptors: descriptorMap,
        image: image,
      ));
    }
    
    return result;
  }
  
  Future<Map<String, List<Item>>> searchItems(String query) async {
    final db = await database;
    query = '%$query%';
    
    // Search in item names
    final itemMatches = await db.rawQuery('''
      SELECT i.*, b.id as bag_id 
      FROM items i
      JOIN bags b ON i.bag_id = b.id
      WHERE i.name LIKE ?
    ''', [query]);
    
    // Search in descriptors
    final descriptorMatches = await db.rawQuery('''
      SELECT i.*, b.id as bag_id
      FROM items i
      JOIN descriptors d ON i.id = d.item_id
      JOIN bags b ON i.bag_id = b.id
      WHERE d.key LIKE ? OR d.value LIKE ?
      GROUP BY i.id
    ''', [query, query]);
    
    // Combine results
    Map<String, Set<int>> bagItemIds = {};
    
    for (var item in [...itemMatches, ...descriptorMatches]) {
      String bagId = item['bag_id'] as String;
      int itemId = item['id'] as int;
      
      if (!bagItemIds.containsKey(bagId)) {
        bagItemIds[bagId] = {};
      }
      
      bagItemIds[bagId]!.add(itemId);
    }
    
    // Fetch complete items
    Map<String, List<Item>> results = {};
    
    for (var entry in bagItemIds.entries) {
      String bagId = entry.key;
      List<Item> items = [];
      
      for (var itemId in entry.value) {
        List<Item> matchingItems = await _getItemById(itemId);
        items.addAll(matchingItems);
      }
      
      results[bagId] = items;
    }
    
    return results;
  }
  
  Future<List<Item>> _getItemById(int id) async {
    final db = await database;
    final items = await db.query('items', where: 'id = ?', whereArgs: [id]);
    
    if (items.isEmpty) return [];
    
    var item = items.first;
    String name = item['name'] as String;
    String? image = item['image'] as String?;
    
    // Get descriptors
    final descriptors = await db.query(
      'descriptors',
      where: 'item_id = ?',
      whereArgs: [id]
    );
    
    Map<String, String> descriptorMap = {};
    for (var desc in descriptors) {
      descriptorMap[desc['key'] as String] = desc['value'] as String;
    }
    
    return [Item(
      name: name,
      descriptors: descriptorMap,
      image: image,
    )];
  }
}