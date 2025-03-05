import 'package:flutter/material.dart';
import '../models/bag_data.dart';
import '../models/item_model.dart';
import '../widgets/item_editor.dart';

class CreateBagScreen extends StatefulWidget {
  final BagManager bagManager;

  const CreateBagScreen({super.key, required this.bagManager});

  @override
  State<CreateBagScreen> createState() => _CreateBagScreenState();
}

class _CreateBagScreenState extends State<CreateBagScreen> {
  final List<Item> _items = [];
  final _codeController = TextEditingController();
  bool _isCustomCode = false;
  bool _isSaving = false;
  String? _createdCode;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _addItem() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          body: ItemEditor(
            onSave: (item) {
              setState(() {
                _items.add(item);
              });
              Navigator.of(context).pop();
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  void _editItem(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          body: ItemEditor(
            initialItem: _items[index],
            onSave: (item) {
              setState(() {
                _items[index] = item;
              });
              Navigator.of(context).pop();
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _saveBag() async {
    if (_items.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      String? customCode = _isCustomCode ? _codeController.text.trim().toUpperCase() : null;
      String code = await widget.bagManager.createBag(_items, customCode: customCode == null || customCode.isEmpty ? null : customCode);

      setState(() {
        _createdCode = code;
        _isSaving = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating bag: $e')),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _items.clear();
      _createdCode = null;
      _isCustomCode = false;
      _codeController.text = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _createdCode != null ? _buildSuccessScreen() : _buildCreateScreen(),
    );
  }

  Widget _buildSuccessScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Bag Created Successfully!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Your bag code is:'),
        SelectableText(
          _createdCode!,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _reset,
          child: const Text('Create Another Bag'),
        ),
      ],
    );
  }

  Widget _buildCreateScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Custom Code Input
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                title: const Text('Set custom bag code'),
                value: _isCustomCode,
                onChanged: (value) {
                  setState(() {
                    _isCustomCode = value ?? false;
                  });
                },
                contentPadding: const EdgeInsets.all(0),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          ],
        ),

        if (_isCustomCode)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Bag Code',
                hintText: 'e.g., ABC123',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ),

        // Items List Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Items List
        Expanded(
          child: _items.isEmpty
              ? const Center(child: Text('No items added yet'))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        title: Text(_items[index].name),
                        subtitle: _items[index].descriptors.isNotEmpty
                            ? Text(
                                _items[index].descriptors.entries
                                    .map((e) => '${e.key}: ${e.value}')
                                    .join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                              onPressed: () => _removeItem(index),
                            ),
                          ],
                        ),
                        onTap: () => _editItem(index),
                      ),
                    );
                  },
                ),
        ),

        // Save Button
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _items.isEmpty || _isSaving ? null : _saveBag,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: _isSaving
              ? const CircularProgressIndicator()
              : const Text('Create Bag', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}