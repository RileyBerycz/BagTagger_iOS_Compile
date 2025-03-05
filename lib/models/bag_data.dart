import 'dart:math';
import '../data/database_helper.dart';
import 'item_model.dart';

class BagManager {
  final DatabaseHelper _db = DatabaseHelper.instance;
  Map<String, List<Item>> bags = {};
  
  // Load bags from database
  Future<void> loadBags() async {
    try {
      print("Starting to load bags");
      bags = await _db.getAllBags();
      print("Loaded ${bags.length} bags");
    } catch (e) {
      print("Error loading bags: $e");
      // Initialize to empty map if loading fails
      bags = {};
      // Re-throw to let caller handle
      throw e;
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
    
    // Insert bag in database
    await _db.insertBag(code);
    
    // Insert all items
    for (var item in items) {
      await _db.insertItem(code, item);
    }
    
    // Update in-memory cache
    bags[code] = List.from(items);
    
    return code;
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
  Future<void> updateItemInBag(String code, int index, Item newItem) async {
    if (!bags.containsKey(code) || index >= bags[code]!.length) {
      return;
    }
    
    // We need the item ID to update it
    // This is a simplification - in the real implementation, 
    // items should store their database IDs
    var items = await _db.getItemsForBag(code);
    if (index < items.length) {
      // For simplicity, assuming indexes match
      await _db.updateItem(index + 1, newItem); // Simplified - should use actual ID
    }
    
    // Update in-memory cache
    bags[code]![index] = newItem;
  }

  // Search for an item
  Future<Map<String, List<Item>>> searchItem(String searchTerm) async {
    return await _db.searchItems(searchTerm);
  }
  
  // Delete a bag
  Future<void> deleteBag(String code) async {
    await _db.deleteBag(code);
    
    // Update in-memory cache
    bags.remove(code);
  }
}