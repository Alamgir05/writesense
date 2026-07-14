import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/session.dart';
import '../services/image_processing_service.dart';
import '../services/storage_service.dart';
import '../services/session_repository.dart';
import '../providers/history_provider.dart';
import '../features/fluency_score.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/styled_progress_indicator.dart';
import 'results_screen.dart';

Route _createFadeSlideRoute(Widget screen) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => screen,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.05, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;

      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      final offsetAnimation = animation.drive(tween);
      final fadeAnimation = animation.drive(Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve)));

      return SlideTransition(
        position: offsetAnimation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: child,
        ),
      );
    },
  );
}

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  Uint8List? _selectedImageBytes;
  bool _isProcessing = false;
  String _statusMessage = '';
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _analyzeAndUpload() async {
    if (_selectedImageBytes == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Analyzing ink strokes...';
    });

    try {
      final bytes = _selectedImageBytes!;

      // 2. Perform offline analysis
      setState(() {
        _statusMessage = 'Adaptive thresholding & stroke tracing...';
      });
      final analysisService = ImageProcessingService();
      final result = await analysisService.analyzeImage(bytes);

      // 3. Upload to Firebase Storage
      setState(() {
        _statusMessage = 'Uploading handwriting image...';
      });
      final sessionId = const Uuid().v4();
      final storageService = StorageService();
      final imageUrl = await storageService.uploadImage(_selectedImageBytes!, sessionId);

      // 4. Create and save Session
      setState(() {
        _statusMessage = 'Persisting session to Firestore...';
      });
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final session = Session(
        id: sessionId,
        userId: uid,
        timestamp: DateTime.now(),
        source: SessionSource.image,
        features: result.features,
        irregularityIndex: result.staticHandwritingScore,
        classification: result.isLowConfidence ? 'Unreliable' : classify(result.staticHandwritingScore),
        strokes: const [],
        imageUrl: imageUrl,
        isLowConfidence: result.isLowConfidence,
        confidenceMessage: result.confidenceMessage,
      );

      // Save to local SQLite (as backup)
      final sessionRepo = SessionRepository();
      debugPrint('UploadScreen: Saving to local SQLite repository...');
      await sessionRepo.insertSession(session);
      debugPrint('UploadScreen: Local SQLite save successful.');

      // Save to Firestore with timeout and verbose error logging
      debugPrint('UploadScreen: Saving session to Firestore... Document ID: ${session.id}');
      debugPrint('UploadScreen: Firestore document map contents: ${session.toFirestoreMap()}');
      try {
        await ref
            .read(firestoreServiceProvider)
            .saveSession(session)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                debugPrint('UploadScreen: Firestore save timed out after 15 seconds!');
                throw TimeoutException('Firestore write timed out');
              },
            );
        debugPrint('UploadScreen: Firestore save completed successfully.');
      } catch (err, stack) {
        debugPrint('UploadScreen: Exception caught during Firestore saveSession: $err');
        debugPrint('UploadScreen: Stacktrace: $stack');
        rethrow;
      }

      if (mounted) {
        // Navigate to Results screen
        Navigator.pushReplacement(
          context,
          _createFadeSlideRoute(ResultsScreen(session: session)),
        );
      }
    } catch (e, stackTrace) {
      if (DEBUG_STORAGE) {
        print('UploadScreen: Exception during _analyzeAndUpload: $e');
        print(stackTrace);
      }
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        String message = 'Error analyzing image: $e';
        if (e is FirebaseException) {
          if (e.code == 'object-not-found') {
            message = 'Failed to retrieve the uploaded image URL. Please retry.';
          } else if (e.code == 'unauthorized') {
            message = 'Permission denied. Please ensure you are logged in.';
          } else if (e.code == 'upload-failed') {
            message = 'Image upload failed. Please check your network and try again.';
          } else {
            message = 'Firebase error: ${e.message}';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _analyzeAndUpload(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Custom custom back header ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _isProcessing ? null : () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A3C5E).withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A3C5E), size: 16),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Upload Image',
                        style: GoogleFonts.fraunces(
                          color: const Color(0xFF1A1A18),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          // ── Image preview card / placeholder ───────────────
                          GestureDetector(
                            onTap: _isProcessing ? null : () => _showPickOptions(),
                            child: Container(
                              width: double.infinity,
                              height: 320,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E2DE),
                                  width: 1,
                                ),
                              ),
                              child: _selectedImageBytes == null
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.cloud_upload_outlined,
                                          size: 64,
                                          color: Color(0xFF1A3C5E),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Tap to upload handwriting photo',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF1A1A18),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Supports Camera or Gallery',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF8C8C8A),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        _selectedImageBytes!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ── Select buttons ───────────────────────────────
                          if (_selectedImageBytes == null) ...[
                            PressableScale(
                              onTap: () => _pickImage(ImageSource.camera),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A3C5E),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.camera_alt_outlined, color: Colors.white),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Take Photo',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            PressableScale(
                              onTap: () => _pickImage(ImageSource.gallery),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF1A3C5E), width: 1),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.photo_library_outlined, color: Color(0xFF1A3C5E)),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Choose from Gallery',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF1A3C5E),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: PressableScale(
                                    onTap: _isProcessing ? null : () => _showPickOptions(),
                                    child: Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E2DE)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.refresh_rounded, color: Color(0xFF1A1A18)),
                                          const SizedBox(width: 8),
                                          Text('Change', style: GoogleFonts.inter(color: const Color(0xFF1A1A18), fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: PressableScale(
                                    onTap: _isProcessing ? null : _analyzeAndUpload,
                                    child: Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A3C5E),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.analytics_outlined, color: Colors.white),
                                          const SizedBox(width: 8),
                                          Text('Analyze Ink', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Loading overlay ───────────────────────────────────────────
              if (_isProcessing)
                Container(
                  color: Colors.white.withValues(alpha: 0.95),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const StyledProgressIndicator(),
                        const SizedBox(height: 24),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF1A1A18),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please keep the app open',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8C8C8A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E2DE),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1A3C5E)),
              title: Text('Take Photo', style: GoogleFonts.inter(color: const Color(0xFF1A1A18))),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF1A3C5E)),
              title: Text('Choose from Gallery', style: GoogleFonts.inter(color: const Color(0xFF1A1A18))),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
