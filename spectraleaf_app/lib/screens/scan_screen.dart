import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../services/inference_service.dart';
import '../models/scan_result.dart';
import 'result_screen.dart';

class ScanScreen extends StatefulWidget {
  final bool isSpectrometerMode;

  const ScanScreen({
    super.key,
    required this.isSpectrometerMode,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with TickerProviderStateMixin {
  final _picker = ImagePicker();
  final _inferenceService = InferenceService();

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  bool _isProcessing = false;

  String _statusText =
      'Select a leaf image to begin diagnosis';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Pre-load the appropriate model.
    if (widget.isSpectrometerMode) {
      _inferenceService.loadMultitask();
    } else {
      _inferenceService.loadM2();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _inferenceService.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // IMAGE PICKING
  // ------------------------------------------------------------

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (xFile == null) return;

      final bytes = await xFile.readAsBytes();

      if (!mounted) return;

      setState(() {
        _selectedImage = xFile;
        _selectedImageBytes = bytes;
        _statusText =
            'Image selected. Tap "Run Diagnosis" to analyse.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _statusText =
            'Unable to select image: ${e.toString()}';
      });
    }
  }

  // ------------------------------------------------------------
  // RUN DIAGNOSIS
  // ------------------------------------------------------------

  Future<void> _runDiagnosis() async {
    if (_selectedImage == null ||
        _selectedImageBytes == null) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusText = 'Running AI inference...';
    });

    try {
      final bytes = _selectedImageBytes!;

      final rawImage = img.decodeImage(bytes);

      if (rawImage == null) {
        throw Exception(
          'Could not decode image.',
        );
      }

      // --------------------------------------------------------
      // STEP 1: VALIDATE LEAF IMAGE
      // --------------------------------------------------------

      if (!mounted) return;

      setState(() {
        _statusText = 'Verifying crop leaf...';
      });

      final validationMsg =
          _inferenceService.validateLeafImage(rawImage);

      if (validationMsg.isNotEmpty) {
        throw Exception(validationMsg);
      }

      // --------------------------------------------------------
      // STEP 2: RUN MODEL
      // --------------------------------------------------------

      if (!mounted) return;

      setState(() {
        _statusText = 'Running AI inference...';
      });

      ScanResult result;

      if (widget.isSpectrometerMode) {
        // Extract 672-dimensional spectral vector.
        final spectralVector =
            _extractSpectralProfile(rawImage);

        result =
            await _inferenceService.runSpectrometerInference(
          rawImage,
          spectralVector,
        );
      } else {
        result =
            await _inferenceService.runStandardInference(
          rawImage,
        );
      }

      // --------------------------------------------------------
      // STEP 3: OPEN RESULT SCREEN
      // --------------------------------------------------------

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: result,
            imageBytes: bytes,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _statusText =
            e.toString().replaceAll(
                  'Exception: ',
                  '',
                );

        _isProcessing = false;
      });
    }
  }

  // ------------------------------------------------------------
  // SPECTRAL PROFILE EXTRACTION
  // ------------------------------------------------------------

  /// Extracts a 672-dimensional vector:
  ///
  /// R channel = 224 values
  /// G channel = 224 values
  /// B channel = 224 values
  ///
  /// Total = 672 values.
  ///
  /// The image is resized to 224x224 and the center horizontal
  /// strip is averaged vertically.
  List<double> _extractSpectralProfile(
    img.Image image,
  ) {
    // Resize image to 224 x 224.
    final resized = img.copyResize(
      image,
      width: 224,
      height: 224,
    );

    final List<double> rChannel =
        List<double>.filled(224, 0.0);

    final List<double> gChannel =
        List<double>.filled(224, 0.0);

    final List<double> bChannel =
        List<double>.filled(224, 0.0);

    // Center horizontal strip.
    const int stripTop = 100;
    const int stripBottom = 125;

    const int numRows =
        stripBottom - stripTop;

    // Average RGB values vertically.
    for (int x = 0; x < 224; x++) {
      double sumR = 0.0;
      double sumG = 0.0;
      double sumB = 0.0;

      for (int y = stripTop;
          y < stripBottom;
          y++) {
        final pixel = resized.getPixel(x, y);

        sumR += pixel.r / 255.0;
        sumG += pixel.g / 255.0;
        sumB += pixel.b / 255.0;
      }

      rChannel[x] =
          sumR / numRows;

      gChannel[x] =
          sumG / numRows;

      bChannel[x] =
          sumB / numRows;
    }

    // R + G + B = 224 + 224 + 224 = 672
    return [
      ...rChannel,
      ...gChannel,
      ...bChannel,
    ];
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF0D1117),

      appBar: AppBar(
        backgroundColor:
            const Color(0xFF0D1117),
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () =>
              Navigator.pop(context),
        ),

        title: Text(
          widget.isSpectrometerMode
              ? 'Spectrometer Mode'
              : 'Standard Scan',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),

        actions: [
          Container(
            margin:
                const EdgeInsets.only(right: 16),
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: widget.isSpectrometerMode
                  ? const Color(0xFF6366F1)
                      .withValues(alpha: 0.15)
                  : const Color(0xFF10B981)
                      .withValues(alpha: 0.15),
              borderRadius:
                  BorderRadius.circular(8),
            ),
            child: Text(
              widget.isSpectrometerMode
                  ? 'Multitask'
                  : 'M2',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: widget.isSpectrometerMode
                    ? const Color(0xFF818CF8)
                    : const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(20),

          child: Column(
            children: [
              // ------------------------------------------------
              // IMAGE AREA
              // ------------------------------------------------

              if (_selectedImageBytes != null)
                Expanded(
                  child: _buildImagePreview(),
                )
              else ...[
                const Spacer(),

                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: _buildEmptyState(),
                ),

                const Spacer(),
              ],

              const SizedBox(height: 20),

              // ------------------------------------------------
              // STATUS
              // ------------------------------------------------

              AnimatedSwitcher(
                duration:
                    const Duration(
                  milliseconds: 300,
                ),
                child: Text(
                  _statusText,
                  key:
                      ValueKey(_statusText),
                  textAlign:
                      TextAlign.center,
                  style:
                      GoogleFonts.outfit(
                    fontSize: 13,
                    color:
                        const Color(0xFF6B7280),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------
              // BUTTONS
              // ------------------------------------------------

              if (!_isProcessing) ...[
                Row(
                  children: [
                    Expanded(
                      child:
                          _buildActionButton(
                        icon: Icons
                            .photo_library_rounded,
                        label: 'Gallery',
                        onTap: () =>
                            _pickImage(
                          ImageSource.gallery,
                        ),
                        isPrimary: false,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child:
                          _buildActionButton(
                        icon: Icons
                            .camera_alt_rounded,
                        label: 'Camera',
                        onTap: () =>
                            _pickImage(
                          ImageSource.camera,
                        ),
                        isPrimary: false,
                      ),
                    ),
                  ],
                ),

                if (_selectedImageBytes !=
                    null) ...[
                  const SizedBox(height: 12),

                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        _buildActionButton(
                      icon: Icons
                          .biotech_rounded,
                      label:
                          'Run Diagnosis',
                      onTap:
                          _runDiagnosis,
                      isPrimary: true,
                    ),
                  ),
                ],
              ] else
                _buildLoadingIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY STATE
  // ------------------------------------------------------------

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color:
            const Color(0xFF1A2332),

        borderRadius:
            BorderRadius.circular(24),

        border: Border.all(
          color:
              const Color(0xFF10B981)
                  .withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),

      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [
          ScaleTransition(
            scale: _pulseAnim,

            child: Container(
              width: 80,
              height: 80,

              padding:
                  const EdgeInsets.all(16),

              decoration:
                  BoxDecoration(
                color:
                    const Color(0xFF10B981)
                        .withValues(
                  alpha: 0.1,
                ),
                shape: BoxShape.circle,
              ),

              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'No Image Selected',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight:
                  FontWeight.w600,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Take a close-up photo of the leaf\n'
            'or select one from your gallery',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color:
                  const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // IMAGE PREVIEW
  // ------------------------------------------------------------

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius:
              BorderRadius.circular(24),

          child: _selectedImageBytes != null
              ? Image.memory(
                  _selectedImageBytes!,
                  width:
                      double.infinity,
                  fit: BoxFit.cover,
                )
              : Container(
                  width:
                      double.infinity,
                  color:
                      const Color(0xFF1A2332),
                ),
        ),

        Positioned(
          top: 12,
          right: 12,

          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedImage = null;
                _selectedImageBytes =
                    null;

                _statusText =
                    'Select a leaf image to begin diagnosis';
              });
            },

            child: Container(
              width: 36,
              height: 36,

              decoration:
                  BoxDecoration(
                color:
                    Colors.black.withValues(
                  alpha: 0.6,
                ),
                shape: BoxShape.circle,
              ),

              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // ACTION BUTTON
  // ------------------------------------------------------------

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        padding:
            const EdgeInsets.symmetric(
          vertical: 16,
        ),

        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [
                    Color(0xFF10B981),
                    Color(0xFF059669),
                  ],
                )
              : null,

          color: isPrimary
              ? null
              : const Color(0xFF1A2332),

          borderRadius:
              BorderRadius.circular(16),

          border: Border.all(
            color: isPrimary
                ? Colors.transparent
                : const Color(0xFF1F2D3D),
          ),

          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color:
                        const Color(
                      0xFF10B981,
                    ).withValues(
                      alpha: 0.25,
                    ),
                    blurRadius: 16,
                    offset:
                        const Offset(0, 4),
                  ),
                ]
              : null,
        ),

        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),

            const SizedBox(width: 8),

            Text(
              label,
              style:
                  GoogleFonts.outfit(
                fontSize: 15,
                fontWeight:
                    FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // LOADING INDICATOR
  // ------------------------------------------------------------

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        const CircularProgressIndicator(
          valueColor:
              AlwaysStoppedAnimation(
            Color(0xFF10B981),
          ),
          strokeWidth: 2.5,
        ),

        const SizedBox(height: 16),

        Text(
          'Analysing leaf tissue...',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color:
                const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }
}