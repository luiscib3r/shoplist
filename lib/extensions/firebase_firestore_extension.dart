import 'package:cloud_firestore/cloud_firestore.dart';

extension FirebaseFirestoreX on FirebaseFirestore {
  CollectionReference items(String userId) =>
      collection('users').doc(userId).collection('items');
}
