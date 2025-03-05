import 'package:flutter/material.dart';
import 'dart:io';
import '../models/bag_data.dart';
import '../models/item_model.dart';
import '../widgets/item_editor.dart';
import 'bag_detail_screen.dart';

class LookupBagScreen extends StatefulWidget {
  final BagManager bagManager;

  const LookupBagScreen({super.key, required this.bagManager});

  @override
  State<LookupBagScreen> createState() => _LookupBagScreenState();
}

class _LookupBagScreenState extends State<LookupBagScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newCodeController = TextEditingController();
  List<Item>? _foundItems;
  String? _currentCode;
  bool _hasSearched = false;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isAddingItem = false;
  Item? _editingItem;
  int? _editingIndex;
  bool _showCodeEditor = false;
  String? _errorMessage;
  final _formKey = GlobalKey<FormState>();  // Add a form key for validation

  @override
  void dispose() {
    _codeController.dispose();
    _newCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter bag code:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g., ABC123',
                prefixIcon: Icon(Icons.search),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a bag code';
                }
                return null;
              },
              onFieldSubmitted: (_) => _lookupBag(),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _lookupBag,
              child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Lookup Bag'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search bar
        if (_currentCode == null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Enter bag code:', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter code',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _lookupBag,
                child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Lookup Bag'),
              ),
            ],
          ),
          
        // Results
        if (_hasSearched && _currentCode != null)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bag code header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SelectableText(
                      'Bag: $_currentCode',
                      style: const TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            setState(() {
                              _showCodeEditor = true;
                              _newCodeController.text = _currentCode!;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _confirmDeleteBag(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Editing mode controls
                Row(
                  children: [
                    const Text('Edit Mode:'),
                    Switch(
                      value: _isEditing,
                      onChanged: (value) {
                        setState(() {
                          _isEditing = value;
                        });
                      },
                    ),
                    if (_isEditing)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Item'),
                            onPressed: _addNewItem,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Items list
                if (_foundItems == null || _foundItems!.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No items in this bag'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _foundItems!.length,
                      itemBuilder: (context, index) {
                        final item = _foundItems![index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
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
                              : const Icon(Icons.inventory),
                            title: Text(item.name),
                            subtitle: Text(
                              item.descriptors.entries.map((e) => "${e.key}: ${e.value}").join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: _isEditing
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _editItem(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _confirmRemoveItem(index),
                                    ),
                                  ],
                                )
                              : null,
                            onTap: () => _showItemDetails(item),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          
        // No results message
        if (_hasSearched && _foundItems == null && _currentCode == null)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No bag found with that code.',
              style: TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
          
        // Reset search button
        if (_hasSearched && _currentCode != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ElevatedButton(
              onPressed: _resetSearch,
              child: const Text('Look Up Another Bag'),
            ),
          ),
      ],
    );
  }

  Widget _buildItemEditor() {
    return ItemEditor(
      initialItem: _editingItem,
      onSave: (Item item) async {
        setState(() {
          _isLoading = true;
        });
        
        try {
          if (_editingIndex != null) {
            // Update existing item
            await widget.bagManager.updateItemInBag(_currentCode!, _editingIndex!, item);
            setState(() {
              _foundItems![_editingIndex!] = item;
            });
          } else {
            // Add new item
            await widget.bagManager.addItemToBag(_currentCode!, item);
            if (_foundItems == null) {
              _foundItems = [];
            }
            setState(() {
              _foundItems!.add(item);
            });
          }
        } finally {
          setState(() {
            _isAddingItem = false;
            _editingItem = null;
            _editingIndex = null;
            _isLoading = false;
          });
        }
      },
      onCancel: () {
        setState(() {
          _isAddingItem = false;
          _editingItem = null;
          _editingIndex = null;
        });
      },
    );
  }

  Widget _buildCodeEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Change Bag Code:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text('Current Code: $_currentCode',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newCodeController,
          decoration: const InputDecoration(
            labelText: 'New Code',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateBagCode,
                child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Update Code'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _showCodeEditor = false;
                  });
                },
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _lookupBag() async {
    // Validate form first
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    
    final code = _codeController.text.trim().toUpperCase();
    
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a bag code';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    // Add a small delay to prevent state update issues
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      final items = widget.bagManager.lookupBag(code);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      if (items == null || items.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = 'No bag found with code: $code';
          });
        }
        return;
      }
      
      // Use Future.microtask to schedule navigation after the current event loop
      if (mounted) {
        Future.microtask(() {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BagDetailScreen(
                bagManager: widget.bagManager,
                bagCode: code,
              ),
            ),
          ).then((result) {
            // If code was updated in detail screen, clear the text field
            if (result != null && result is String) {
              _codeController.clear();
            }
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }
  
  void _resetSearch() {
    setState(() {
      _codeController.clear();
      _foundItems = null;
      _currentCode = null;
      _hasSearched = false;
      _isEditing = false;
    });
  }

  void _addNewItem() {
    setState(() {
      _isAddingItem = true;
      _editingItem = null;
      _editingIndex = null;
    });
  }

  void _editItem(int index) {
    setState(() {
      _isAddingItem = true;
      _editingItem = _foundItems![index].clone();
      _editingIndex = index;
    });
  }
  
  Future<void> _confirmRemoveItem(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: const Text('Are you sure you want to remove this item from the bag?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      _removeItem(index);
    }
  }

  Future<void> _removeItem(int index) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await widget.bagManager.removeItemFromBag(_currentCode!, index);
      setState(() {
        _foundItems!.removeAt(index);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing item: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
              ...item.descriptors.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entry.key}:', style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _updateBagCode() async {
    final newCode = _newCodeController.text.trim().toUpperCase();
    if (newCode.isEmpty || newCode == _currentCode) {
      setState(() {
        _showCodeEditor = false;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await widget.bagManager.updateBagCode(_currentCode!, newCode);
      if (success) {
        setState(() {
          _currentCode = newCode;
          _showCodeEditor = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code already in use')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating code: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _confirmDeleteBag() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bag'),
        content: const Text('Are you sure you want to delete this bag and all its items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      _deleteBag();
    }
  }
  
  Future<void> _deleteBag() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await widget.bagManager.deleteBag(_currentCode!);
      _resetSearch();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting bag: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
}