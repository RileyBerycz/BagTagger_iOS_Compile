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
    final Map<String, List<Item>> results = {};
    
    if (searchTerm.trim().isEmpty) {
      return results;
    }
    
    // Split search term into individual words
    final List<String> searchTerms = searchTerm.toLowerCase().split(' ')
      .where((term) => term.isNotEmpty).toList();
    
    // Helper function to calculate string similarity (0-1)
    double _calculateSimilarity(String s1, String s2) {
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
    bool _isStringSimilarToAnyTerm(String string, List<String> terms) {
      for (final term in terms) {
        if (_calculateSimilarity(string, term) > 0.7) {
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
            _isStringSimilarToAnyTerm(item.name.toLowerCase(), [term]))) {
          return true;
        }
        
        // Check each descriptor against all search terms
        for (var entry in item.descriptors.entries) {
          final key = entry.key.toLowerCase();
          final value = entry.value.toLowerCase();
          
          if (searchTerms.any((term) => 
              _isStringSimilarToAnyTerm(key, [term]) || 
              _isStringSimilarToAnyTerm(value, [term]))) {
            return true;
          }
          
          // Check descriptor's full content against the whole search term
          // This handles cases like "cheddar cheese" matching "Type: cheddar" and "Name: cheese"
          if (_isStringSimilarToAnyTerm(key + " " + value, searchTerms) ||
              searchTerms.length > 1 && 
              searchTerms.every((term) => 
                  (key + " " + value).toLowerCase().contains(term))) {
            return true;
          }
        }
        
        // Also try with the complete search phrase
        if (_isStringSimilarToAnyTerm(item.name.toLowerCase(), [searchTerm.toLowerCase()])) {
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
    await _db.deleteBag(code);
    
    // Update in-memory cache
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
}