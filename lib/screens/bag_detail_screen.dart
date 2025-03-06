// filepath: /C:/Projects/BagTagger/Dart BagTagger/bag_tagger/lib/screens/bag_detail_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import '../models/bag_data.dart';
import '../models/item_model.dart';
import '../widgets/item_editor.dart';

class BagDetailScreen extends StatefulWidget {
  final BagManager bagManager;
  final String bagCode;
  final List<Item>? filteredItems;
  final String? searchTerm;

  const BagDetailScreen({
    super.key, 
    required this.bagManager, 
    required this.bagCode,
    this.filteredItems,
    this.searchTerm,
  });

  @override
  State<BagDetailScreen> createState() => _BagDetailScreenState();
}

class _BagDetailScreenState extends State<BagDetailScreen> {
  List<Item>? _items;
  bool _isLoading = true;
  bool _isEditing = false;
  final TextEditingController _codeController = TextEditingController();
  bool _showingFilteredItems = false;
  List<Item>? _allItems;
  
  @override
  void initState() {
    super.initState();
    _loadBag();
    _codeController.text = widget.bagCode;
    _showingFilteredItems = widget.filteredItems != null && widget.filteredItems!.isNotEmpty;
  }
  
  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadBag() async {
    setState(() => _isLoading = true);
    
    // Always load all items to have them available
    _allItems = widget.bagManager.lookupBag(widget.bagCode);
    
    // Set initial items based on whether we have filtered items
    if (widget.filteredItems != null && widget.filteredItems!.isNotEmpty && _showingFilteredItems) {
      _items = widget.filteredItems;
    } else {
      _items = _allItems;
    }
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _updateBagCode() async {
    final newCode = _codeController.text.trim().toUpperCase();
    if (newCode.isEmpty || newCode == widget.bagCode) {
      return;
    }
    
    final success = await widget.bagManager.updateBagCode(widget.bagCode, newCode);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code already exists'))
      );
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bag code updated'))
    );
    
    Navigator.pop(context, newCode);
  }
  
  Future<void> _showAddItemDialog() async {
    final result = await showDialog<Item>(
      context: context,
      builder: (context) => const ItemEditorDialog(),
    );
    
    if (result != null) {
      await widget.bagManager.addItemToBag(widget.bagCode, result);
      await _loadBag();
    }
  }
  
  Future<void> _editItem(int index) async {
    if (_items == null || index >= _items!.length) return;
    
    final item = _items![index];
    final result = await showDialog<Item>(
      context: context,
      builder: (context) => ItemEditorDialog(initialItem: item),
    );
    
    if (result != null) {
      await widget.bagManager.updateItemInBag(widget.bagCode, index, result);
      await _loadBag();
    }
  }
  
  Future<void> _deleteItem(int index) async {
    if (_items == null || index >= _items!.length) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirmed) {
      await widget.bagManager.removeItemFromBag(widget.bagCode, index);
      await _loadBag();
    }
  }

  void _toggleFilter() {
    setState(() {
      _showingFilteredItems = !_showingFilteredItems;
      if (_showingFilteredItems && widget.filteredItems != null) {
        _items = widget.filteredItems;
      } else {
        _items = _allItems;
      }
    });
  }

Widget _highlightText(String text) {
  // Simply return regular text without highlighting
  return Text(
    text, 
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showingFilteredItems && widget.searchTerm != null 
          ? 'Results for "${widget.searchTerm}"' 
          : 'Bag Details'),
        actions: [
          // Only show filter toggle if we have filtered items
          if (widget.filteredItems != null && widget.filteredItems!.isNotEmpty)
            IconButton(
              icon: Icon(_showingFilteredItems ? Icons.filter_list_off : Icons.filter_list),
              tooltip: _showingFilteredItems ? 'Show all items' : 'Show search results only',
              onPressed: _toggleFilter,
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
                if (!_isEditing) {
                  _updateBagCode();
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items == null
              ? const Center(child: Text('Bag not found'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Text('Bag Code: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: _isEditing
                              ? TextField(
                                  controller: _codeController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  textCapitalization: TextCapitalization.characters,
                                )
                              : SelectableText(
                                  widget.bagCode,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ElevatedButton.icon(
                            onPressed: _showAddItemDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Item'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _items!.isEmpty
                          ? const Center(child: Text('No items in this bag'))
                          : ListView.builder(
                              itemCount: _items!.length,
                              itemBuilder: (context, index) {
                                final item = _items![index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                  child: ListTile(
                                    leading: item.image != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: Image.file(
                                              File(item.image!),
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(Icons.inventory, size: 40),
                                    title: _highlightText(item.name),
                                    subtitle: item.descriptors.isNotEmpty
                                        ? _highlightText(
                                            item.descriptors.entries
                                                .take(2)
                                                .map((e) => "${e.key}: ${e.value}")
                                                .join(', '),
                                          )
                                        : null,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _editItem(index),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () => _deleteItem(index),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _editItem(index),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: _items != null && !_isLoading ? FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add),
      ) : null,
    );
  }
}