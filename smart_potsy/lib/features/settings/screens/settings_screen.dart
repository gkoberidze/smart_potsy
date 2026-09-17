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
  String _language = 'ka';

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _language = prefs.getString('app_language') ?? 'ka';
    });
  }

  Future<void> _saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', language);
    if (!mounted) return;
    setState(() {
      _language = language;
    });
  }

  String _t(String georgian, String english) {
    return _language == 'en' ? english : georgian;
  }

  Future<void> _loadProfileImage() async {
    final authService = context.read<AuthService>();
    final prefs = await SharedPreferences.getInstance();
    final userId = authService.user?.id ?? 0;
    if (!mounted) return;
    setState(() {
      _profileImagePath = prefs.getString('profile_image_$userId');
    });
  }

  Future<void> _saveProfileImage(String path) async {
    final authService = context.read<AuthService>();
    final prefs = await SharedPreferences.getInstance();
    final userId = authService.user?.id ?? 0;
    await prefs.setString('profile_image_$userId', path);
    if (!mounted) return;
    setState(() {
      _profileImagePath = path;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image != null) {
      await _saveProfileImage(image.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t('ფოტო წარმატებით შეიცვალა', 'Photo updated successfully'),
            ),
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
                  title: Text(_t('პაროლის შეცვლა', 'Change password')),
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
                              labelText: _t(
                                'მიმდინარე პაროლი',
                                'Current password',
                              ),
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
                                return _t(
                                  'შეიყვანეთ მიმდინარე პაროლი',
                                  'Please enter your current password',
                                );
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: newPasswordController,
                            obscureText: obscureNew,
                            decoration: InputDecoration(
                              labelText: _t('ახალი პაროლი', 'New password'),
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
                                return _t(
                                  'შეიყვანეთ ახალი პაროლი',
                                  'Please enter a new password',
                                );
                              }
                              if (value.length < 8) {
                                return _t(
                                  'მინიმუმ 8 სიმბოლო',
                                  'At least 8 characters',
                                );
                              }
                              if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                return _t(
                                  'მინიმუმ ერთი დიდი ასო',
                                  'At least one uppercase letter',
                                );
                              }
                              if (!RegExp(r'[a-z]').hasMatch(value)) {
                                return _t(
                                  'მინიმუმ ერთი პატარა ასო',
                                  'At least one lowercase letter',
                                );
                              }
                              if (!RegExp(r'[0-9]').hasMatch(value)) {
                                return _t(
                                  'მინიმუმ ერთი ციფრი',
                                  'At least one number',
                                );
                              }
                              if (!RegExp(
                                r'[!@#$%^&*(),.?\":{}|<>]',
                              ).hasMatch(value)) {
                                return _t(
                                  'მინიმუმ ერთი სპეც. სიმბოლო',
                                  'At least one special character',
                                );
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: confirmPasswordController,
                            obscureText: obscureConfirm,
                            decoration: InputDecoration(
                              labelText: _t(
                                'გაიმეორეთ ახალი პაროლი',
                                'Confirm new password',
                              ),
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
                                return _t(
                                  'პაროლები არ ემთხვევა',
                                  'Passwords do not match',
                                );
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
                      child: Text(_t('გაუქმება', 'Cancel')),
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
                      child: Text(_t('შეცვლა', 'Update')),
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
            SnackBar(
              content: Text(
                _t(
                  'პაროლი წარმატებით შეიცვალა',
                  'Password changed successfully',
                ),
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.error ??
                    _t('პაროლის შეცვლა ვერ მოხერხდა', 'Password change failed'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('შეცდომა: ', 'Error: ') + e.toString()),
            backgroundColor: Colors.red,
          ),
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
        title: Text(_t('პარამეტრები', 'Settings')),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: _saveLanguage,
            itemBuilder:
                (context) => const [
                  PopupMenuItem(value: 'ka', child: Text('ქართული')),
                  PopupMenuItem(value: 'en', child: Text('English')),
                ],
          ),
        ],
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
                            Text(
                              _t('პროფილის ფოტო', 'Profile photo'),
                              style: const TextStyle(
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
                              label: Text(_t('ფოტოს შეცვლა', 'Change photo')),
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
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _t('უსაფრთხოება', 'Security'),
                              style: const TextStyle(
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
                            title: Text(
                              _t('პაროლის შეცვლა', 'Change password'),
                            ),
                            subtitle: Text(
                              _t(
                                'შეცვალეთ თქვენი ანგარიშის პაროლი',
                                'Update your account password',
                              ),
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
                            title: Text(_t('ელ-ფოსტა', 'Email')),
                            subtitle: Text(
                              user?.email ??
                                  _t('არ არის მითითებული', 'Not provided'),
                            ),
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
