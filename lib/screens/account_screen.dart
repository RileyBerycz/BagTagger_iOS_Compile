// lib/screens/account_screen.dart
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/bag_data.dart';

class AccountScreen extends StatefulWidget {
  final BagManager bagManager;
  
  const AccountScreen({super.key, required this.bagManager});
  
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _firebaseService = FirebaseService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _firebaseService.isSignedIn ? _buildSignedInUI() : _buildSignInUI(),
      ),
    );
  }
  
  Widget _buildSignInUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Sign in to sync your bags across devices', 
            style: TextStyle(fontSize: 18)),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        if (_errorMessage != null)
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 10),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _signIn,
                  child: const Text('Sign In'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _createAccount,
                  child: const Text('Create Account'),
                ),
              ),
            ],
          ),
      ],
    );
  }
  
  Widget _buildSignedInUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Signed in as: ${_firebaseService.userEmail}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _syncBags,
                          icon: const Icon(Icons.sync),
                          label: const Text('Sync Bags'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _firebaseService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _createAccount() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _firebaseService.createAccount(
        _emailController.text.trim(),
        _passwordController.text,
      );
      setState(() {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _firebaseService.signOut();
      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _syncBags() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _firebaseService.syncBags(widget.bagManager);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bags synchronized successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}