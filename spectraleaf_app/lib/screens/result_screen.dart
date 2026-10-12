import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/scan_result.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final ScanResult result;
  final Uint8List imageBytes;

  const ResultScreen({
    super.key,
    required this.result,
    required this.imageBytes,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _primaryColor {
    if (widget.result.deficiencyClass == 'healthy') {
      return const Color(0xFF10B981);
    }

    if (widget.result.confidence > 80) {
      return const Color(0xFFEF4444);
    }

    return const Color(0xFFF59E0B);
  }

  String _formatClassName(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value[0].toUpperCase() +
        value.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: Text(
          'Diagnosis Result',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              widget.result.mode == 'spectrometer'
                  ? 'Spectrometer'
                  : 'Standard',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),

      body: FadeTransition(
        opacity: _fadeAnim,

        child: SlideTransition(
          position: _slideAnim,

          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              30,
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageCard(),

                const SizedBox(height: 20),

                _buildDiagnosisCard(),

                const SizedBox(height: 16),

                _buildSpadCard(),

                const SizedBox(height: 16),

                _buildProbabilityCard(),

                const SizedBox(height: 20),

                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),

      child: Image.memory(
        widget.imageBytes,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildDiagnosisCard() {
    final String diagnosis =
        _formatClassName(widget.result.deficiencyClass);

    final bool healthy =
        widget.result.deficiencyClass == 'healthy';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(20),

        border: Border.all(
          color: _primaryColor.withValues(alpha: 0.25),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,

                decoration: BoxDecoration(
                  color: _primaryColor
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),

                child: Icon(
                  healthy
                      ? Icons.check_circle_rounded
                      : Icons.warning_rounded,
                  color: _primaryColor,
                  size: 26,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Diagnosis',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      diagnosis,
                      style: GoogleFonts.outfit(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            'Confidence',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF9CA3AF),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),

                  child: LinearProgressIndicator(
                    value:
                        (widget.result.confidence / 100)
                            .clamp(0.0, 1.0),

                    minHeight: 9,

                    backgroundColor:
                        const Color(0xFF293445),

                    valueColor:
                        AlwaysStoppedAnimation<Color>(
                      _primaryColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Text(
                '${widget.result.confidence.toStringAsFixed(1)}%',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpadCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,

            decoration: BoxDecoration(
              color: const Color(0xFF6366F1)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.eco_rounded,
              color: Color(0xFF818CF8),
              size: 25,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  'SPAD Value',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  widget.result.spadValue
                      .toStringAsFixed(1),

                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),

            decoration: BoxDecoration(
              color: _spadStatusColor()
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),

            child: Text(
              widget.result.spadStatus,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _spadStatusColor(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _spadStatusColor() {
    final status =
        widget.result.spadStatus.toLowerCase();

    if (status.contains('healthy') ||
        status.contains('normal') ||
        status.contains('good')) {
      return const Color(0xFF10B981);
    }

    if (status.contains('low') ||
        status.contains('deficien')) {
      return const Color(0xFFEF4444);
    }

    return const Color(0xFFF59E0B);
  }

  Widget _buildProbabilityCard() {
    final probabilities =
        widget.result.allProbabilities.entries.toList();

    probabilities.sort(
      (a, b) => b.value.compareTo(a.value),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            'Class Probabilities',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 18),

          ...probabilities.map(
            (entry) => _buildProbabilityRow(
              entry.key,
              entry.value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProbabilityRow(
    String name,
    double value,
  ) {
    final isPrimary =
        name == widget.result.deficiencyClass;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),

      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatClassName(name),

                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: isPrimary
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isPrimary
                        ? Colors.white
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ),

              Text(
                '${value.toStringAsFixed(1)}%',

                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isPrimary
                      ? _primaryColor
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),

            child: LinearProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              minHeight: 6,

              backgroundColor:
                  const Color(0xFF293445),

              valueColor:
                  AlwaysStoppedAnimation<Color>(
                isPrimary
                    ? _primaryColor
                    : const Color(0xFF4B5563),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _exportPdfReport,

          child: Container(
            width: double.infinity,

            padding: const EdgeInsets.symmetric(
              vertical: 16,
            ),

            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF10B981),
                  Color(0xFF059669),
                ],
              ),

              borderRadius: BorderRadius.circular(16),

              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981)
                      .withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),

            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,

              children: [
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: 20,
                ),

                const SizedBox(width: 8),

                Text(
                  'Export PDF Report',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        GestureDetector(
          onTap: () {
            Navigator.pushAndRemoveUntil(
              context,

              MaterialPageRoute(
                builder: (_) => const HomeScreen(),
              ),

              (route) => false,
            );
          },

          child: Container(
            width: double.infinity,

            padding: const EdgeInsets.symmetric(
              vertical: 16,
            ),

            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(16),

              border: Border.all(
                color: const Color(0xFF1F2D3D),
              ),
            ),

            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,

              children: [
                const Icon(
                  Icons.home_rounded,
                  color: Colors.white,
                  size: 20,
                ),

                const SizedBox(width: 8),

                Text(
                  'Back to Home',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportPdfReport() async {
    try {
      final pdf = pw.Document();

      final image = pw.MemoryImage(
        widget.imageBytes,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,

          margin: const pw.EdgeInsets.all(32),

          build: (context) {
            return pw.Column(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.start,

              children: [
                pw.Text(
                  'SpectraLeaf Diagnosis Report',

                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 8),

                pw.Text(
                  'Generated: '
                  '${widget.result.timestamp}',
                ),

                pw.SizedBox(height: 20),

                pw.ClipRRect(
                  horizontalRadius: 12,
                  verticalRadius: 12,

                  child: pw.Image(
                    image,
                    height: 180,
                    width: double.infinity,
                    fit: pw.BoxFit.cover,
                  ),
                ),

                pw.SizedBox(height: 24),

                pw.Text(
                  'Diagnosis',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 6),

                pw.Text(
                  _formatClassName(
                    widget.result.deficiencyClass,
                  ),

                  style: const pw.TextStyle(
                    fontSize: 20,
                  ),
                ),

                pw.SizedBox(height: 16),

                pw.Text(
                  'Confidence: '
                  '${widget.result.confidence.toStringAsFixed(2)}%',
                ),

                pw.SizedBox(height: 8),

                pw.Text(
                  'SPAD Value: '
                  '${widget.result.spadValue.toStringAsFixed(2)}',
                ),

                pw.SizedBox(height: 8),

                pw.Text(
                  'SPAD Status: '
                  '${widget.result.spadStatus}',
                ),

                pw.SizedBox(height: 8),

                pw.Text(
                  'Mode: '
                  '${widget.result.mode}',
                ),

                pw.SizedBox(height: 24),

                pw.Text(
                  'Class Probabilities',

                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 10),

                ...widget.result.allProbabilities.entries
                    .map(
                  (entry) => pw.Padding(
                    padding: const pw.EdgeInsets.only(
                      bottom: 6,
                    ),

                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            _formatClassName(
                              entry.key,
                            ),
                          ),
                        ),

                        pw.Text(
                          '${entry.value.toStringAsFixed(2)}%',
                        ),
                      ],
                    ),
                  ),
                ),

                pw.Spacer(),

                pw.Divider(),

                pw.SizedBox(height: 8),

                pw.Text(
                  'SpectraLeaf - Leaf Nutrient Analysis',
                  style: const pw.TextStyle(
                    fontSize: 10,
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async {
          return pdf.save();
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not export PDF: $e',
          ),
        ),
      );
    }
  }
}