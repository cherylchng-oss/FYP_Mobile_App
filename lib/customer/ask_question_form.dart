import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../api.dart' as api;
import '../services/session.dart';

class FAQCategory {
  final String id;
  final String label;

  const FAQCategory({
    required this.id,
    required this.label,
  });
}

class AskQuestionForm extends StatefulWidget {
  final String role;
  final List<FAQCategory> categories;
  final String theme;

  const AskQuestionForm({
    super.key,
    required this.role,
    required this.categories,
    this.theme = 'customer',
  });

  @override
  State<AskQuestionForm> createState() => _AskQuestionFormState();
}

class _AskQuestionFormState extends State<AskQuestionForm> {
  final _formKey = GlobalKey<FormState>();

  String name = '';
  String email = '';
  String selectedCategory = '';
  String question = '';
  String? fileName;
  File? selectedFile;
  String errorMessage = '';

  bool isSubmitting = false;
  bool isSubmitted = false;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final questionController = TextEditingController();

  static const primary = Color(0xFF6B3F1A);
  static const primaryLight = Color(0xFF8B5E3C);
  static const accent = Color(0xFFBF8040);
  static const accentLight = Color(0xFFE8B97A);
  static const cream = Color(0xFFFAF6F0);
  static const surface = Color(0xFFF5EDE0);
  static const border = Color(0xFFE8D9C5);
  static const textPrimary = Color(0xFF2C1A0E);
  static const textSecond = Color(0xFF6B4C30);
  static const textMuted = Color(0xFFA07850);
  static const success = Color(0xFF3D7A5C);
  static const danger = Color(0xFFB83232);

  @override
  void initState() {
    super.initState();
    selectedCategory =
        widget.categories.isNotEmpty ? widget.categories[0].id : '';
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    questionController.dispose();
    super.dispose();
  }

  Future<void> handleFileChange() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final fileSize = await file.length();

    if (fileSize > 5 * 1024 * 1024) {
      setState(() {
        errorMessage = 'File must not exceed 5MB.';
      });
      return;
    }

    setState(() {
      selectedFile = file;
      fileName = result.files.single.name;
      errorMessage = '';
    });
  }

  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSubmitting = true;
      errorMessage = '';
    });

    try {
      final userid = await Session.getUserId();

      await api.submitSupportQuestion(
        role: widget.role.toLowerCase(),
        name: name.trim(),
        email: email.trim(),
        category: selectedCategory.isNotEmpty ? selectedCategory : 'others',
        question: question.trim(),
        userid: userid,
        attachment: selectedFile,
      );

      setState(() {
        isSubmitting = false;
        isSubmitted = true;

        nameController.clear();
        emailController.clear();
        questionController.clear();
        fileName = null;
        selectedFile = null;
      });
    } catch (error) {
      setState(() {
        isSubmitting = false;
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isSubmitted) {
      return _successState();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 20),

            if (errorMessage.isNotEmpty) _errorBox(),

            _textField('Name', nameController),
            _textField('Email', emailController,
                keyboardType: TextInputType.emailAddress),

            const SizedBox(height: 16),

            _dropdown(),

            const SizedBox(height: 16),

            _questionField(),

            const SizedBox(height: 16),

            _fileUpload(),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : handleSubmit,
                icon: Icon(
                  isSubmitting ? Icons.hourglass_top_rounded : Icons.send_rounded,
                  size: 18,
                ),
                label: Text(
                  isSubmitting ? 'Sending...' : 'Submit Question',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: border,
                  disabledForegroundColor: textMuted,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primary, primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              color: accentLight,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ask a Question',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Our team will respond within 24 hours.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.76),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBECEC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFB8B8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: danger,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    final icon = label == 'Name'
        ? Icons.person_outline_rounded
        : Icons.email_outlined;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        cursorColor: accent,
        style: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: textMuted,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Icon(icon, color: accent, size: 20),
          filled: true,
          fillColor: cream,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: accent, width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: danger, width: 1.8),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }

          if (label == 'Email' && !value.contains('@')) {
            return 'Enter a valid email';
          }

          return null;
        },
        onChanged: (value) {
          setState(() {
            if (label == 'Name') name = value;
            if (label == 'Email') email = value;
          });
        },
      ),
    );
  }

  Widget _dropdown() {
    return DropdownButtonFormField(
      value: selectedCategory,
      dropdownColor: Colors.white,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: textMuted),
      style: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: 'Category',
        labelStyle: const TextStyle(
          color: textMuted,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: const Icon(Icons.category_outlined, color: accent, size: 20),
        filled: true,
        fillColor: cream,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.8),
        ),
      ),
      items: [
        ...widget.categories.map(
          (c) => DropdownMenuItem(value: c.id, child: Text(c.label)),
        ),
        const DropdownMenuItem(value: 'others', child: Text('Others')),
      ],
      onChanged: (v) => setState(() => selectedCategory = v.toString()),
    );
  }

  Widget _questionField() {
    return TextFormField(
      controller: questionController,
      maxLines: 4,
      maxLength: 500,
      cursorColor: accent,
      style: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      decoration: InputDecoration(
        labelText: 'Your Question',
        alignLabelWithHint: true,
        labelStyle: const TextStyle(
          color: textMuted,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 70),
          child: Icon(Icons.help_outline_rounded, color: accent, size: 20),
        ),
        filled: true,
        fillColor: cream,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        counterStyle: const TextStyle(color: textMuted, fontSize: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger, width: 1.8),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Question is required';
        }
        return null;
      },
      onChanged: (value) {
        setState(() {
          question = value;
        });
      },
    );
  }

  Widget _fileUpload() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.attach_file_rounded, color: accent, size: 18),
              SizedBox(width: 8),
              Text(
                'Attachment',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Optional. Upload JPG, PNG, or PDF file up to 5MB.',
            style: TextStyle(
              color: textMuted,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: handleFileChange,
                icon: const Icon(Icons.upload_file_rounded, size: 17),
                label: const Text(
                  'Upload File',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: const BorderSide(color: accent),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (fileName != null)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: border),
                    ),
                    child: Text(
                      fileName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textSecond,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _successState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF7F2),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border.all(color: const Color(0xFFB2DDD0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: success, size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question submitted successfully!',
                  style: TextStyle(
                    color: success,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Our team will review your question and respond as soon as possible.',
                  style: TextStyle(
                    color: success,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}