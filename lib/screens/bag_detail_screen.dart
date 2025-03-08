// filepath: /C:/Projects/BagTagger/Dart BagTagger/bag_tagger/lib/screens/bag_detail_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import '../models/bag_data.dart';
import '../models/item_model.dart';
import '../widgets/item_editor.dart';
import '../data/database_helper.dart';

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
  List<Item>? _allItems;
  List<Item>? _displayedItems;
  bool _isFiltered = false;
  String? _currentSearchTerm;
  bool _isLoading = true;
  bool _isEditing = false;
  final TextEditingController _codeController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadBag();
    _codeController.text = widget.bagCode;
    _allItems = widget.bagManager.lookupBag(widget.bagCode);
    
    // If filtered items are provided, use them as the initial display
    if (widget.filteredItems != null && widget.filteredItems!.isNotEmpty) {
      _displayedItems = widget.filteredItems;
      _isFiltered = true;
      _currentSearchTerm = widget.searchTerm;
    } else {
      _displayedItems = _allItems;
    }
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
    if (widget.filteredItems != null && widget.filteredItems!.isNotEmpty && _isFiltered) {
      _displayedItems = widget.filteredItems;
    } else {
      _displayedItems = _allItems;
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
  
  void _editItem(int index) async {
    final editedItem = await showDialog<Item>(
      context: context,
      builder: (context) => ItemEditorDialog(
        initialItem: _displayedItems![index],
      ),
    );
    
    if (editedItem != null) {
      // Update the item in the database
      final bagId = widget.bagCode;
      await DatabaseHelper.instance.updateItemInBag(
        bagId, 
        _displayedItems![index],  // original item
        editedItem  // updated item
      );
      
      // Update local data
      setState(() {
        // Update in the displayed items list
        _displayedItems![index] = editedItem;
        
        // If using filtered items, also update the original list
        if (_allItems != _displayedItems) {
          final originalIndex = _allItems!.indexOf(_displayedItems![index]);
          if (originalIndex >= 0) {
            _allItems![originalIndex] = editedItem;
          }
        }
      });
      
      // Update the BagManager's data
      widget.bagManager.updateItemInBag(widget.bagCode, editedItem, index);
    }
  }
  
  Future<void> _deleteItem(int index) async {
    if (_displayedItems == null || index >= _displayedItems!.length) return;
    
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

  void _clearFilter() {
    setState(() {
      _displayedItems = _allItems;
      _isFiltered = false;
      _currentSearchTerm = null;
    });
  }

  void _showFilterDialog() {
    // Your existing filter dialog code
    // When filter is applied, set:
    // _displayedItems = filteredResults;
    // _isFiltered = true;
    // _currentSearchTerm = searchText;
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
        title: Text(_isFiltered && _currentSearchTerm != null 
          ? 'Results for "${_currentSearchTerm}"' 
          : 'Bag Details'),
        actions: [
          // If we have a filter active, show a "Clear Filter" button
          if (_isFiltered)
            IconButton(
              icon: const Icon(Icons.filter_list_off),
              tooltip: 'Clear filter',
              onPressed: _clearFilter,
            )
          else
            IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filter items',
              onPressed: _showFilterDialog,
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
          : _displayedItems == null
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
                      child: _displayedItems!.isEmpty
                          ? const Center(child: Text('No items in this bag'))
                          : ListView.builder(
                              itemCount: _displayedItems!.length,
                              itemBuilder: (context, index) {
                                final item = _displayedItems![index];
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
      floatingActionButton: _displayedItems != null && !_isLoading ? FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add),
      ) : null,
    );
  }
}