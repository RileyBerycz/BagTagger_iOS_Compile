import 'package:flutter/material.dart';
import 'dart:io';
import '../models/bag_data.dart';
import '../models/item_model.dart';
import 'bag_detail_screen.dart';

class SearchItemScreen extends StatefulWidget {
  final BagManager bagManager;

  const SearchItemScreen({super.key, required this.bagManager});

  @override
  State<SearchItemScreen> createState() => _SearchItemScreenState();
}

class _SearchItemScreenState extends State<SearchItemScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, List<Item>> _searchResults = {};
  bool _hasSearched = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter item name or descriptor',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (_) => _searchItems(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _searchItems,
            child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Search Items'),
          ),
          const SizedBox(height: 24),
          if (_hasSearched)
            Expanded(
              child: _searchResults.isNotEmpty
                ? ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final entry = _searchResults.entries.elementAt(index);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  SelectableText(
                                    'Bag: ${entry.key}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                                  ),
                                  OutlinedButton(
                                    child: const Text('View All'),
                                    onPressed: () {
                                      _navigateToBag(entry.key);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...entry.value.take(2).map((item) => Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 4),
                                child: Row(
                                  children: [
                                    if (item.image != null)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: Image.file(
                                            File(item.image!),
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      )
                                    else
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8),
                                        child: Icon(Icons.inventory, size: 40),
                                      ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.name,
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                          if (item.descriptors.isNotEmpty)
                                            Text(
                                              item.descriptors.entries
                                                  .take(2)
                                                  .map((e) => "${e.key}: ${e.value}")
                                                  .join(', '),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12),
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
                              )).toList(),
                              if (entry.value.length > 2)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'And ${entry.value.length - 2} more items...',
                                    style: const TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Text('No items found matching your search',
                      style: TextStyle(fontSize: 16, color: Colors.grey)
                    ),
                  ),
            ),
        ],
      ),
    );
  }

  Future<void> _searchItems() async {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final results = await widget.bagManager.searchItem(searchTerm);
      setState(() {
        _searchResults = results;
        _hasSearched = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Update the method
void _navigateToBag(String bagCode) {
  // Get the matched items for this specific bag
  List<Item> matchedItems = _searchResults[bagCode] ?? [];
  
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