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
  static const accent = Color(0xFFBF8040);
  static const surface = Color(0xFFF5EDE0);
  static const border = Color(0xFFE8D9C5);
  static const textPrimary = Color(0xFF2C1A0E);
  static const textMuted = Color(0xFFA07850);

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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.08),
            blurRadius: 16,
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

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isSubmitting ? 'Sending...' : 'Submit Question',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "Ask a Question",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 6),
        Text(
          "Our team will respond within 24 hours.",
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _errorBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(errorMessage, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
      decoration: InputDecoration(
        labelText: 'Your Question',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
    return Row(
      children: [
        OutlinedButton(
          onPressed: handleFileChange,
          child: const Text('Upload File'),
        ),
        const SizedBox(width: 12),
        if (fileName != null) Expanded(child: Text(fileName!)),
      ],
    );
  }

  Widget _successState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: const Text(
        '✅ Question submitted successfully!',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}