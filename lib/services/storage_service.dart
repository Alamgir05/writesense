import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../firebase_options.dart';

// ignore: constant_identifier_names
const bool DEBUG_STORAGE = true;

/// Uploads handwriting images to Firebase Storage.
/// Path: users/{uid}/images/{sessionId}.jpg
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'gs://${DefaultFirebaseOptions.currentPlatform.storageBucket}',
  );

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// Upload [imageBytes] and return the public download URL.
  Future<String> uploadImage(Uint8List imageBytes, String sessionId) async {
    final path = 'users/$_uid/images/$sessionId.jpg';
    final ref = _storage.ref().child(path);

    // Print path for diagnostics
    if (DEBUG_STORAGE) {
      print('StorageService: Starting upload to path: $path');
    }

    final uploadTask = ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    
    final snapshot = await uploadTask;
    if (snapshot.state == TaskState.success) {
      if (DEBUG_STORAGE) {
        print('StorageService: Upload successful, state: ${snapshot.state}. Fetching download URL...');
      }
      
      // Retry fetching download URL up to 4 times with a 1-second delay
      // to handle server-side replication lag or transient issues.
      int retryCount = 0;
      while (true) {
        try {
          final url = await snapshot.ref.getDownloadURL();
          if (DEBUG_STORAGE) {
            print('StorageService: Successfully retrieved download URL: $url');
          }
          return url;
        } catch (e) {
          retryCount++;
          if (DEBUG_STORAGE) {
            print('StorageService: getDownloadURL attempt $retryCount failed: $e');
          }
          if (retryCount >= 4) {
            if (DEBUG_STORAGE) {
              print('StorageService: Max retries reached for getDownloadURL. Rethrowing.');
            }
            rethrow;
          }
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    } else {
      if (DEBUG_STORAGE) {
        print('StorageService: Upload failed with state: ${snapshot.state}');
      }
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'upload-failed',
        message: 'Upload completed with state: ${snapshot.state}',
      );
    }
  }

  /// Delete an image from Storage (used when deleting a session)
  Future<void> deleteImage(String sessionId) async {
    try {
      await _storage
          .ref()
          .child('users')
          .child(_uid)
          .child('images')
          .child('$sessionId.jpg')
          .delete();
    } catch (_) {
      // Ignore — file may not exist (tablet sessions have no image)
    }
  }
}
