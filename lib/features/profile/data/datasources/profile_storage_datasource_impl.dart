import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import 'profile_storage_datasource.dart';

class ProfileStorageDataSourceImpl implements ProfileStorageDataSource {
  ProfileStorageDataSourceImpl(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<String> uploadUserAvatarJpeg(String userId, Uint8List bytes) async {
    final ref = _storage.ref().child('avatars').child(userId).child('avatar.jpg');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }
}
