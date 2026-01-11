import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _profileImagePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final authService = context.read<AuthService>();
    final userId = authService.user?.id ?? 0;
    setState(() {
      _profileImagePath = prefs.getString('profile_image_$userId');
    });
  }

  Future<void> _saveProfileImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final authService = context.read<AuthService>();
    final userId = authService.user?.id ?? 0;
    await prefs.setString('profile_image_$userId', path);
    setState(() {
      _profileImagePath = path;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image != null) {
      await _saveProfileImage(image.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ფოტო წარმატებით შეიცვალა'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('პაროლის შეცვლა'),
                  content: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: currentPasswordController,
                            obscureText: obscureCurrent,
                            decoration: InputDecoration(
                              labelText: 'მიმდინარე პაროლი',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureCurrent
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed:
                                    () => setDialogState(
                                      () => obscureCurrent = !obscureCurrent,
                                    ),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'შეიყვანეთ მიმდინარე პაროლი';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: newPasswordController,
                            obscureText: obscureNew,
                            decoration: InputDecoration(
                              labelText: 'ახალი პაროლი',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureNew
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed:
                                    () => setDialogState(
                                      () => obscureNew = !obscureNew,
                                    ),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'შეიყვანეთ ახალი პაროლი';
                              }
                              if (value.length < 8) {
                                return 'მინიმუმ 8 სიმბოლო';
                              }
                              if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                return 'მინიმუმ ერთი დიდი ასო';
                              }
                              if (!RegExp(r'[a-z]').hasMatch(value)) {
                                return 'მინიმუმ ერთი პატარა ასო';
                              }
                              if (!RegExp(r'[0-9]').hasMatch(value)) {
                                return 'მინიმუმ ერთი ციფრი';
                              }
                              if (!RegExp(
                                r'[!@#$%^&*(),.?\":{}|<>]',
                              ).hasMatch(value)) {
                                return 'მინიმუმ ერთი სპეც. სიმბოლო';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: confirmPasswordController,
                            obscureText: obscureConfirm,
                            decoration: InputDecoration(
                              labelText: 'გაიმეორეთ ახალი პაროლი',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureConfirm
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed:
                                    () => setDialogState(
                                      () => obscureConfirm = !obscureConfirm,
                                    ),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value != newPasswordController.text) {
                                return 'პაროლები არ ემთხვევა';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('გაუქმება'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(context);
                          await _changePassword(
                            currentPasswordController.text,
                            newPasswordController.text,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('შეცვლა'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    setState(() => _isLoading = true);

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.post(ApiConstants.changePassword, {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

      if (mounted) {
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('პაროლი წარმატებით შეიცვალა'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'პაროლის შეცვლა ვერ მოხერხდა'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('შეცდომა: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.user;
    final userInitial =
        (user?.email != null && user!.email.isNotEmpty
                ? user.email.substring(0, 1)
                : 'U')
            .toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('პარამეტრები'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Profile Section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text(
                              'პროფილის ფოტო',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 60,
                                    backgroundColor: const Color(0xFF2E7D32),
                                    backgroundImage:
                                        _profileImagePath != null
                                            ? (kIsWeb
                                                ? NetworkImage(
                                                  _profileImagePath!,
                                                )
                                                : FileImage(
                                                      File(_profileImagePath!),
                                                    )
                                                    as ImageProvider)
                                            : null,
                                    child:
                                        _profileImagePath == null
                                            ? Text(
                                              userInitial,
                                              style: const TextStyle(
                                                fontSize: 48,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            )
                                            : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4CAF50),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              user?.email ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.edit),
                              label: const Text('ფოტოს შეცვლა'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Security Section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'უსაფრთხოება',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE8F5E9),
                              child: Icon(Icons.lock, color: Color(0xFF2E7D32)),
                            ),
                            title: const Text('პაროლის შეცვლა'),
                            subtitle: const Text(
                              'შეცვალეთ თქვენი ანგარიშის პაროლი',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _showChangePasswordDialog,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE8F5E9),
                              child: Icon(
                                Icons.email,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            title: const Text('ელ-ფოსტა'),
                            subtitle: Text(user?.email ?? 'არ არის მითითებული'),
                            enabled: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
