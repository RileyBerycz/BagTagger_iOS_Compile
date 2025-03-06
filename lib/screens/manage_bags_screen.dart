import 'package:flutter/material.dart';
import '../models/bag_data.dart';
import 'bag_detail_screen.dart';

class ManageBagsScreen extends StatefulWidget {
  final BagManager bagManager;
  
  const ManageBagsScreen({super.key, required this.bagManager});
  
  @override
  State<ManageBagsScreen> createState() => _ManageBagsScreenState();
}

class _ManageBagsScreenState extends State<ManageBagsScreen> {
  bool _isLoading = false;
  
  Future<void> _deleteBag(String code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bag'),
        content: Text('Are you sure you want to delete bag $code?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      
      try {
        await widget.bagManager.deleteBag(code);
        setState(() {});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting bag: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final bags = widget.bagManager.bags;
    
    return Scaffold(
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : bags.isEmpty
          ? const Center(child: Text('No bags created yet'))
          : ListView.builder(
              itemCount: bags.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final code = bags.keys.elementAt(index);
                final items = bags[code]!;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('Bag: $code'),
                    subtitle: Text('${items.length} items'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility),
                          tooltip: 'View Details',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BagDetailScreen(
                                  bagManager: widget.bagManager,
                                  bagCode: code,
                                ),
                              ),
                            ).then((_) => setState(() {}));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Delete Bag',
                          onPressed: () => _deleteBag(code),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BagDetailScreen(
                            bagManager: widget.bagManager,
                            bagCode: code,
                          ),
                        ),
                      ).then((_) => setState(() {}));
                    },
                  ),
                );
              },
            ),
    );
  }
}