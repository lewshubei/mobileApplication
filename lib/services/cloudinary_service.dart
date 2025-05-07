import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

Future<String?> uploadToCloudinary(FilePickerResult? filePickerResult) async {
  if (filePickerResult == null || filePickerResult.files.isEmpty) {
    print('No file selected');
    return null;
  }

  File file = File(filePickerResult.files.first.path!);

  String cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  String uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  // Create a MultipartRequest to upload the file
  var uri = Uri.parse(
    'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
  );
  var request = http.MultipartRequest('POST', uri);

  // Read the file content as bytes
  var fileBytes = await file.readAsBytes();
  var multipartFile = http.MultipartFile.fromBytes(
    'file',
    fileBytes,
    filename: file.path.split("/").last,
  );

  // Add the file part to the request
  request.files.add(multipartFile);
  request.fields['upload_preset'] = uploadPreset;

  // Send the request and await for the response
  var response = await request.send();

  // Get the response as text
  var responseBody = await response.stream.bytesToString();
  var jsonResponse = jsonDecode(responseBody);

  // Print the response
  print(responseBody);

  if (response.statusCode == 200) {
    print('File uploaded successfully!');
    return jsonResponse['secure_url'];
  } else {
    print('File upload failed: ${response.statusCode}');
    return null;
  }
}
