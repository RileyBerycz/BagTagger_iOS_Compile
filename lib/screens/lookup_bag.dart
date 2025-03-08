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
  bool _isLoading = false;
  Item? _editingItem;
  int? _editingIndex;
  String? _errorMessage;
  final _formKey = GlobalKey<FormState>();

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
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      if (items == null || items.isEmpty) {
        setState(() {
          _errorMessage = 'No bag found with code: $code';
        });
        return;
      }
      
      // Navigate to bag detail screen
      if (!mounted) return;
      
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
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }
  
  void _resetSearch() {
    setState(() {
      _codeController.clear();
      _foundItems = null;
      _currentCode = null;
    });
  }
  
  void _showItemEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ItemEditorDialog(initialItem: _editingItem),
      ),
    ).then((editedItem) {
      if (editedItem != null && editedItem is Item) {
        _saveEditedItem(editedItem);
      }
    });
  }
  
  Future<void> _saveEditedItem(Item item) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (_editingIndex != null) {
        // Update existing item
        await widget.bagManager.updateItemInBag(
          _currentCode!,
          item,           // Changed order - this should be the new item
          _editingIndex!  // Changed order - this should be the index
        );
        
        if (!mounted) return;
        
        setState(() {
          _foundItems![_editingIndex!] = item;
        });
      } else {
        // Add new item
        await widget.bagManager.addItemToBag(_currentCode!, item);
        
        if (!mounted) return;
        
        setState(() {
          _foundItems ??= [];
          _foundItems!.add(item);
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _editingItem = null;
          _editingIndex = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeItem(int index) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await widget.bagManager.removeItemFromBag(_currentCode!, index);
      
      if (!mounted) return;
      
      setState(() {
        _foundItems!.removeAt(index);
      });
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing item: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _deleteBag() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await widget.bagManager.deleteBag(_currentCode!);
      
      if (!mounted) return;
      
      _resetSearch();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting bag: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
}