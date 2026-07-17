import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:covaone_sdk/src/model/storage_model.dart';

class AppStorage {
  final storage = new FlutterSecureStorage();

  AndroidOptions _getAndroidOptions() => const AndroidOptions(
    encryptedSharedPreferences: true,
  );

  // To save a key to flutter secure storage
  Future<String> saveKey({required String key, required String value}) async {
    // TODO: Write AES encryption for values here
    await storage.write(key: key, value: value, aOptions: _getAndroidOptions());
    return value;
  }

  // To save multiple values
  Future<void> saveMany({List<StorageModel>? list}) async {
    // TODO: Write AES encryption for all saved items here
    list?.forEach((element) async => await storage.write(key: element.key, value: element.value, aOptions: _getAndroidOptions()));
    return;
  }

  // To retrieve data from storage
  Future<String?> get({required String key}) async {
    var value = await storage.read(key: key, aOptions: _getAndroidOptions());
    return value;
  }

  // To check if a key exist
  Future<bool> doesExists({required String key}) async {
    bool exist = await storage.containsKey(key: key, aOptions: _getAndroidOptions());
    return exist;
  }

  Future<void> clear() async {
    await storage.deleteAll(aOptions: _getAndroidOptions());
    return;
  }

  Future<void> delete({required String key}) async {
    await storage.delete(key: key, aOptions: _getAndroidOptions());
  }
}