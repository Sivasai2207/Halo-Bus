import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class PhotoService {
  final ImagePicker _picker = ImagePicker();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  /// Picks an image from the camera.
  Future<XFile?> pickFromCamera() => _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
      );

  /// Picks an image from the gallery.
  Future<XFile?> pickFromGallery() => _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

  /// Detects the primary face in the image and returns cropped + padded bytes.
  /// Falls back to the original image bytes if no face is detected.
  Future<Uint8List> detectFaceAndCrop(String filePath, Uint8List originalBytes) async {
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        debugPrint('[PhotoService] No face detected, using full image.');
        return _resizeBytes(originalBytes);
      }

      // Use the largest detected face (closest to camera)
      final Face primaryFace = faces.reduce(
        (a, b) => (a.boundingBox.width * a.boundingBox.height) >
                (b.boundingBox.width * b.boundingBox.height)
            ? a
            : b,
      );

      final img.Image? decoded = img.decodeImage(originalBytes);
      if (decoded == null) return _resizeBytes(originalBytes);

      final rect = primaryFace.boundingBox;

      // Add generous padding around the face (40% on all sides) so the crop
      // looks natural — not too tight.
      final double padX = rect.width * 0.4;
      final double padY = rect.height * 0.4;

      final int x = (rect.left - padX).clamp(0, decoded.width.toDouble()).toInt();
      final int y = (rect.top - padY).clamp(0, decoded.height.toDouble()).toInt();
      final int w = (rect.width + padX * 2)
          .clamp(1, (decoded.width - x).toDouble())
          .toInt();
      final int h = (rect.height + padY * 2)
          .clamp(1, (decoded.height - y).toDouble())
          .toInt();

      final img.Image cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);

      // Resize to a square 400x400 for consistent storage size
      final img.Image resized = img.copyResizeCropSquare(cropped, size: 400);

      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (e) {
      debugPrint('[PhotoService] Face crop error: $e — falling back to resize');
      return _resizeBytes(originalBytes);
    }
  }

  /// Resize original image to max 800px (no face crop) as a fallback.
  Uint8List _resizeBytes(Uint8List bytes) {
    try {
      final img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      final img.Image resized = img.copyResize(decoded, width: 800);
      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (_) {
      return bytes;
    }
  }

  /// Converts image bytes to a Base64-encoded Data URI.
  String encodeToBase64(Uint8List bytes) {
    final String base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  void dispose() {
    _faceDetector.close();
  }
}
