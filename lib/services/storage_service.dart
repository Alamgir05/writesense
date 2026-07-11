import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

/// Uploads handwriting images to Firebase Storage.
/// Path: users/{uid}/images/{sessionId}.jpg
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// Upload [imageFile] and return the public download URL.
  Future<String> uploadImage(File imageFile, String sessionId) async {
    final ext = p.extension(imageFile.path).isNotEmpty
        ? p.extension(imageFile.path)
        : '.jpg';
    final ref = _storage
        .ref()
        .child('users')
        .child(_uid)
        .child('images')
        .child('$sessionId$ext');

    final task = await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
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
