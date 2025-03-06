// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bag_data.dart';
import '../models/item_model.dart';

class FirebaseService {
  // Singleton pattern
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Auth methods
  bool get isSignedIn => _auth.currentUser != null;
  String? get userEmail => _auth.currentUser?.email;
  String? get userId => _auth.currentUser?.uid;
  
  // Sign in/create account methods
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }
  
  Future<UserCredential> createAccount(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }
  
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // Sync methods
  Future<void> syncBags(BagManager bagManager) async {
    if (!isSignedIn) throw Exception('Not signed in');
    
    // First upload local bags
    await uploadBags(bagManager);
    
    // Then download from cloud
    final cloudBags = await downloadBags();
    
    // Update local database
    await bagManager.replaceAllBags(cloudBags);
  }
  
  Future<void> uploadBags(BagManager bagManager) async {
    if (!isSignedIn) return;
    
    final batch = _firestore.batch();
    final userBagsRef = _firestore.collection('users').doc(userId).collection('bags');
    
    // Delete existing cloud bags
    final existingBags = await userBagsRef.get();
    for (final doc in existingBags.docs) {
      batch.delete(doc.reference);
    }
    
    // Upload current bags
    for (final entry in bagManager.bags.entries) {
      final bagCode = entry.key;
      final items = entry.value;
      
      batch.set(userBagsRef.doc(bagCode), {
        'code': bagCode,
        'updated': FieldValue.serverTimestamp(),
        'items': items.map((item) => _itemToJson(item)).toList(),
      });
    }
    
    await batch.commit();
  }
  
  Future<Map<String, List<Item>>> downloadBags() async {
    if (!isSignedIn) return {};
    
    final userBagsRef = _firestore.collection('users').doc(userId).collection('bags');
    final snapshot = await userBagsRef.get();
    
    final Map<String, List<Item>> bags = {};
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final bagCode = data['code'] as String;
      final itemsList = data['items'] as List<dynamic>;
      
      bags[bagCode] = itemsList
          .map((itemData) => _itemFromJson(itemData as Map<String, dynamic>))
          .toList();
    }
    
    return bags;
  }
  
  // Helper methods for Item serialization since the class doesn't have toJson/fromJson
  Map<String, dynamic> _itemToJson(Item item) {
    return {
      'name': item.name,
      'descriptors': item.descriptors,
      'image': item.image,
    };
  }
  
  Item _itemFromJson(Map<String, dynamic> json) {
    return Item(
      name: json['name'] as String,
      descriptors: Map<String, String>.from(json['descriptors'] ?? {}),
      image: json['image'] as String?,
    );
  }
}