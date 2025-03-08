import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/item_model.dart';

// Full-screen editor used by CreateBagScreen
class ItemEditor extends StatefulWidget {
  final Item? initialItem;
  final Function(Item) onSave;
  final VoidCallback onCancel;

  const ItemEditor({
    Key? key,
    this.initialItem,
    required this.onSave,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<ItemEditor> {
  final _nameController = TextEditingController();
  final _newKeyController = TextEditingController();
  final _newValueController = TextEditingController();
  Map<String, String> _descriptors = {};
  String? _imagePath;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      _nameController.text = widget.initialItem!.name;
      _descriptors = Map.from(widget.initialItem!.descriptors);
      _imagePath = widget.initialItem!.image;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newKeyController.dispose();
    _newValueController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  void _addDescriptor() {
    final key = _newKeyController.text.trim();
    final value = _newValueController.text.trim();
    
    if (key.isNotEmpty && value.isNotEmpty) {
      setState(() {
        _descriptors[key] = value;
        _newKeyController.clear();
        _newValueController.clear();
      });
    }
  }
  
  void _removeDescriptor(String key) {
    setState(() {
      _descriptors.remove(key);
    });
  }

  void _editDescriptor(String key, String value) {
    _newKeyController.text = key;
    _newValueController.text = value;
    showDialog(
      context: context,
      builder: (context) => _buildEditDescriptorDialog(key),
    );
  }

  void _saveItem() {
    if (_formKey.currentState?.validate() ?? false) {
      final item = Item(
        name: _nameController.text.trim(),
        descriptors: _descriptors,
        image: _imagePath,
      );
      widget.onSave(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppBar(
            title: Text(widget.initialItem == null ? 'Add New Item' : 'Edit Item'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onCancel,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _saveItem,
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name*',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an item name';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 24.0),
                  
                  // Image picker
                  const Text('Item Image', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8.0),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: _imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.file(
                                File(_imagePath!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 40),
                                  Text('Tap to add image'),
                                ],
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 24.0),
                  
                  // Descriptors
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Descriptors', style: TextStyle(fontSize: 16)),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                        onPressed: () {
                          _newKeyController.clear();
                          _newValueController.clear();
                          showDialog(
                            context: context,
                            builder: (context) => _buildAddDescriptorDialog(),
                          );
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8.0),
                  
                  // Descriptors list
                  if (_descriptors.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No descriptors added'),
                      ),
                    )
                  else
                    ...(_descriptors.entries.map((entry) => Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        title: Text(entry.key),
                        subtitle: Text(entry.value),
                        onTap: () => _editDescriptor(entry.key, entry.value),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editDescriptor(entry.key, entry.value),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _removeDescriptor(entry.key),
                            ),
                          ],
                        ),
                      ),
                    ))),
                ],
              ),
            ),
          ),
          
          // Bottom action buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveItem,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Dialog for adding a new descriptor
  Widget _buildAddDescriptorDialog() {
    return AlertDialog(
      title: const Text('Add Descriptor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _newKeyController,
            decoration: const InputDecoration(
              labelText: 'Key',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16.0),
          TextField(
            controller: _newValueController,
            decoration: const InputDecoration(
              labelText: 'Value',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            _addDescriptor();
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  // Dialog for editing an existing descriptor
  Widget _buildEditDescriptorDialog(String originalKey) {
    return AlertDialog(
      title: const Text('Edit Descriptor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _newKeyController,
            decoration: const InputDecoration(
              labelText: 'Key',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16.0),
          TextField(
            controller: _newValueController,
            decoration: const InputDecoration(
              labelText: 'Value',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final newKey = _newKeyController.text.trim();
            final newValue = _newValueController.text.trim();
            
            if (newKey.isNotEmpty && newValue.isNotEmpty) {
              setState(() {
                // Remove the original key-value pair
                _descriptors.remove(originalKey);
                // Add the new key-value pair
                _descriptors[newKey] = newValue;
              });
            }
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Dialog version used by BagDetailScreen
class ItemEditorDialog extends StatefulWidget {
  final Item? initialItem;
  
  const ItemEditorDialog({super.key, this.initialItem});

  @override
  State<ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<ItemEditorDialog> {
  final _nameController = TextEditingController();
  final _newKeyController = TextEditingController();
  final _newValueController = TextEditingController();
  Map<String, String> _descriptors = {};
  String? _imagePath;
  
  @override
  void initState() {
    super.initState();
    
    if (widget.initialItem != null) {
      _nameController.text = widget.initialItem!.name;
      _descriptors = Map.from(widget.initialItem!.descriptors);
      _imagePath = widget.initialItem!.image;
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _newKeyController.dispose();
    _newValueController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }
  
  void _addDescriptor() {
    final key = _newKeyController.text.trim();
    final value = _newValueController.text.trim();
    
    if (key.isNotEmpty && value.isNotEmpty) {
      setState(() {
        _descriptors[key] = value;
        _newKeyController.clear();
        _newValueController.clear();
      });
    }
  }
  
  void _removeDescriptor(String key) {
    setState(() {
      _descriptors.remove(key);
    });
  }

  void _editDescriptor(String key, String value) {
    _newKeyController.text = key;
    _newValueController.text = value;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Edit Descriptor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _newKeyController,
              decoration: const InputDecoration(
                labelText: 'Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newValueController,
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final newKey = _newKeyController.text.trim();
                      final newValue = _newValueController.text.trim();
                      
                      if (newKey.isNotEmpty && newValue.isNotEmpty) {
                        setState(() {
                          // Remove the original key-value pair
                          _descriptors.remove(key);
                          // Add the new key-value pair
                          _descriptors[newKey] = newValue;
                        });
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialItem == null ? 'Add Item' : 'Edit Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            const Text('Image:'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _imagePath != null
                  ? Image.file(File(_imagePath!), fit: BoxFit.cover)
                  : const Center(child: Text('Tap to select image')),
              ),
            ),
            const SizedBox(height: 16),
            
            const Text('Descriptors:'),
            const SizedBox(height: 8),
            ..._descriptors.entries.map((entry) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(entry.key),
                subtitle: Text(entry.value),
                onTap: () => _editDescriptor(entry.key, entry.value),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _editDescriptor(entry.key, entry.value),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _removeDescriptor(entry.key),
                    ),
                  ],
                ),
              ),
            )).toList(),
            
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Key',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _newValueController,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addDescriptor,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter an item name'))
              );
              return;
            }
            
            final item = Item(
              name: name,
              descriptors: _descriptors,
              image: _imagePath,
            );
            
            Navigator.pop(context, item);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}