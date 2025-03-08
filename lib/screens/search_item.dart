import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import '../models/bag_data.dart';
import '../models/item_model.dart';
import 'bag_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchItemScreen extends StatefulWidget {
  final BagManager bagManager;

  const SearchItemScreen({super.key, required this.bagManager});

  @override
  State<SearchItemScreen> createState() => _SearchItemScreenState();
}

class _SearchItemScreenState extends State<SearchItemScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, List<_ScoredItem>> _searchResults = {};
  List<String> _recentSearches = [];
  List<String> _suggestions = [];
  bool _hasSearched = false;
  bool _isLoading = false;
  Timer? _debounceTimer;
  
  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recentSearches') ?? [];
    });
  }
  
  Future<void> _saveRecentSearch(String searchTerm) async {
    if (searchTerm.isEmpty) return;
    
    // Add to recent searches (without duplicates)
    if (!_recentSearches.contains(searchTerm)) {
      _recentSearches = [searchTerm, ..._recentSearches.take(9)];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recentSearches', _recentSearches);
    }
  }
  
  void _onSearchChanged() {
    // Debounce search input to avoid excessive processing
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _updateSuggestions();
    });
  }
  
  void _updateSuggestions() {
    final input = _searchController.text.toLowerCase().trim();
    if (input.isEmpty) {
      setState(() {
        _suggestions = _recentSearches.take(5).toList();
      });
      return;
    }
    
    // Get all unique descriptors and values from items
    final allItems = <String>[];
    final descriptorValues = <String>[];
    
    widget.bagManager.bags.forEach((_, items) {
      for (var item in items) {
        if (!allItems.contains(item.name.toLowerCase())) {
          allItems.add(item.name.toLowerCase());
        }
        
        item.descriptors.forEach((key, value) {
          final descriptorText = "$key: $value".toLowerCase();
          if (!descriptorValues.contains(descriptorText)) {
            descriptorValues.add(descriptorText);
          }
          if (!descriptorValues.contains(value.toLowerCase())) {
            descriptorValues.add(value.toLowerCase());
          }
        });
      }
    });
    
    // Find matching suggestions
    final matchingNames = allItems
        .where((name) => name.contains(input))
        .take(3)
        .toList();
    
    final matchingDescriptors = descriptorValues
        .where((desc) => desc.contains(input))
        .take(3)
        .toList();
    
    final matchingRecent = _recentSearches
        .where((search) => search.toLowerCase().contains(input))
        .take(2)
        .toList();
    
    // Combine suggestions with no duplicates
    final allSuggestions = {...matchingNames, ...matchingDescriptors, ...matchingRecent};
    
    setState(() {
      _suggestions = allSuggestions.toList();
      if (_suggestions.length > 5) {
        _suggestions = _suggestions.sublist(0, 5);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Search for an item:', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'Enter item name or descriptor',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _suggestions = _recentSearches.take(5).toList();
                      });
                    },
                  )
                : null,
            ),
            onSubmitted: (_) => _searchItems(),
          ),
          
          // Suggestions list
          if (_suggestions.isNotEmpty && _searchController.text.isNotEmpty && !_hasSearched)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.search, size: 18),
                    title: Text(_suggestions[index]),
                    onTap: () {
                      _searchController.text = _suggestions[index];
                      _searchItems();
                    },
                  );
                },
              ),
            ),
          
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _searchItems,
            child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Search Items'),
          ),
          
          // Recent searches chips
          if (_recentSearches.isNotEmpty && !_hasSearched && _searchController.text.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent searches:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _recentSearches.take(6).map((search) => InputChip(
                      label: Text(search),
                      onPressed: () {
                        _searchController.text = search;
                        _searchItems();
                      },
                      onDeleted: () {
                        setState(() {
                          _recentSearches.remove(search);
                        });
                        SharedPreferences.getInstance().then((prefs) {
                          prefs.setStringList('recentSearches', _recentSearches);
                        });
                      },
                    )).toList(),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          if (_hasSearched)
            Expanded(
              child: _buildSearchResults(),
            ),
        ],
      ),
    );
  }
  
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text('No items found matching your search',
          style: TextStyle(fontSize: 16, color: Colors.grey)
        ),
      );
    }
    
    // Convert _searchResults to a sorted list of entries based on best item score
    List<MapEntry<String, List<_ScoredItem>>> sortedEntries = _searchResults.entries.toList();
    sortedEntries.sort((a, b) {
      // Sort by highest score in each bag
      final aHighestScore = a.value.isNotEmpty ? a.value.first.score : 0;
      final bHighestScore = b.value.isNotEmpty ? b.value.first.score : 0;
      return bHighestScore.compareTo(aHighestScore);
    });
    
    return ListView.builder(
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        final bagCode = entry.key;
        final scoredItems = entry.value;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: SelectableText(
                        'Bag: $bagCode',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    OutlinedButton(
                      child: const Text('View All'),
                      onPressed: () {
                        _navigateToBag(bagCode);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(),
                ...scoredItems.take(3).map((scoredItem) {
                  final item = scoredItem.item;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.image != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                File(item.image!),
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(Icons.inventory, size: 60, color: Colors.grey),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name,
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              if (item.descriptors.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  children: item.descriptors.entries.take(4).map((e) => 
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      padding: EdgeInsets.zero,
                                      labelStyle: const TextStyle(fontSize: 11),
                                      label: Text("${e.key}: ${e.value}"),
                                    )
                                  ).toList(),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () => _showItemDetails(item),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                if (scoredItems.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton(
                      onPressed: () => _navigateToBag(bagCode),
                      child: Text(
                        'Show ${scoredItems.length - 3} more items...',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _searchItems() async {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    
    // Save to recent searches
    await _saveRecentSearch(searchTerm);
    
    try {
      // Split search into individual words for multi-word search
      final searchWords = searchTerm.toLowerCase().split(" ")
          .where((word) => word.isNotEmpty)
          .toList();
      
      final results = <String, List<_ScoredItem>>{};
      
      // Perform advanced search with scoring
      widget.bagManager.bags.forEach((bagCode, items) {
        final scoredItems = <_ScoredItem>[];
        
        for (var item in items) {
          int score = 0;
          final itemName = item.name.toLowerCase();
          
          // Check if any search word is in the item name
          for (var word in searchWords) {
            if (itemName.contains(word)) {
              // Higher score for name matches
              score += 10;
              
              // Even higher score for exact name match
              if (itemName == word) {
                score += 30;
              }
            }
          }
          
          // Check if search words are in the descriptors
          item.descriptors.forEach((key, value) {
            for (var word in searchWords) {
              if (value.toLowerCase().contains(word)) {
                // Points for descriptor matches
                score += 5;
                
                // Extra points for exact descriptor match
                if (value.toLowerCase() == word) {
                  score += 10;
                }
              }
            }
          });
          
          // Boost score if all search words are found somewhere
          final allContent = itemName + " " + 
              item.descriptors.entries
                  .map((e) => "${e.key} ${e.value}")
                  .join(" ")
                  .toLowerCase();
                  
          if (searchWords.every((word) => allContent.contains(word))) {
            score += 15;
          }
          
          // Only include items with some match
          if (score > 0) {
            scoredItems.add(_ScoredItem(item, score));
          }
        }
        
        // Sort items by score (highest first)
        scoredItems.sort((a, b) => b.score.compareTo(a.score));
        
        // Only add bags with matches
        if (scoredItems.isNotEmpty) {
          results[bagCode] = scoredItems;
        }
      });
      
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _navigateToBag(String bagCode) {
    // Get the matched items for this specific bag
    List<Item> matchedItems = _searchResults[bagCode]?.map((si) => si.item).toList() ?? [];
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BagDetailScreen(
          bagManager: widget.bagManager,
          bagCode: bagCode,
          filteredItems: matchedItems,
          searchTerm: _searchController.text.trim(),
        ),
      ),
    );
  }

  void _showItemDetails(Item item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.image != null)
                Center(
                  child: Image.file(
                    File(item.image!),
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),
              if (item.image != null)
                const SizedBox(height: 16),
              if (item.descriptors.isNotEmpty)
                const Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
              if (item.descriptors.isNotEmpty)
                const SizedBox(height: 8),
              ...item.descriptors.entries.map((entry) => 
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 2),
                  child: Row(
                    children: [
                      Text('${entry.key}:', 
                        style: const TextStyle(fontSize: 14, color: Colors.grey)
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(entry.value, style: const TextStyle(fontSize: 14))
                      ),
                    ],
                  ),
                )
              ).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

// Helper class for scored search results
class _ScoredItem {
  final Item item;
  final int score;
  
  _ScoredItem(this.item, this.score);
}