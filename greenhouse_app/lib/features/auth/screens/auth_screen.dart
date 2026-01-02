import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import 'forgot_password_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoginTab = true; // false = register tab

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    final remember = prefs.getBool('remember_me') ?? false;

    if (remember && savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = true;
        _isLoginTab = true;
      });
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailController.text.trim());
      await prefs.setString('saved_password', _passwordController.text);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchTab(bool isLogin) {
    setState(() {
      _isLoginTab = isLogin;
      _formKey.currentState?.reset();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      bool success;

      if (_isLoginTab) {
        // Login
        success = await authService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (success) {
          await _saveCredentials();
        }
      } else {
        // Register - backend expects email and password only
        success = await authService.register(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }

      if (success && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('რეგისტრაცია წარმატებით დასრულდა!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Switch to login tab after registration
        if (!_isLoginTab) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() => _isLoginTab = true);
            }
          });
        } else {
          // Login successful - go to dashboard
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
            }
          });
        }
      } else if (mounted) {
        // Show error
        final authService = context.read<AuthService>();
        final error = authService.error ?? 'წარუმატებელი';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('შეცდომა: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    // TODO: Implement Google OAuth
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google-ით შესვლა მალე დაემატება')),
    );
  }

  Future<void> _handleFacebookLogin() async {
    // TODO: Implement Facebook OAuth
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Facebook-ით შესვლა მალე დაემატება')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 30),

                // Logo
                _buildLogo(),

                const SizedBox(height: 30),

                // Tab Switcher
                _buildTabSwitcher(),

                const SizedBox(height: 24),

                // Form Fields
                _buildFormFields(),

                const SizedBox(height: 20),

                // Submit Button
                _buildSubmitButton(),

                const SizedBox(height: 16),

                // Forgot Password (only for login)
                if (_isLoginTab) _buildForgotPassword(),

                if (_isLoginTab) const SizedBox(height: 20),

                // Divider with "ან"
                _buildDivider(),

                const SizedBox(height: 20),

                // Social Login Buttons
                _buildSocialButtons(),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 3),
        color: Colors.white,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback icon if logo not found
            return Icon(Icons.eco, size: 50, color: AppColors.primary);
          },
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Row(
        children: [
          // Login Tab
          Expanded(
            child: GestureDetector(
              onTap: () => _switchTab(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _isLoginTab ? AppColors.primary : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(28),
                  ),
                ),
                child: Text(
                  'შესვლა',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isLoginTab ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          // Register Tab
          Expanded(
            child: GestureDetector(
              onTap: () => _switchTab(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: !_isLoginTab ? AppColors.primary : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(28),
                  ),
                ),
                child: Text(
                  'რეგისტრაცია',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_isLoginTab ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        // Name field (only for registration)
        if (!_isLoginTab) ...[
          _buildTextField(
            controller: _nameController,
            hint: 'სახელი',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'გთხოვთ შეიყვანოთ სახელი';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
        ],

        // Email/Phone field
        _buildTextField(
          controller: _emailController,
          hint: 'ელ ფოსტა ან ტელეფონის ნომერი',
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'გთხოვთ შეიყვანოთ ელ ფოსტა';
            }
            if (!value.contains('@') && !RegExp(r'^\d+$').hasMatch(value)) {
              return 'არასწორი ფორმატი';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Password field
        _buildTextField(
          controller: _passwordController,
          hint: 'პაროლი',
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textHint,
            ),
            onPressed:
                () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'გთხოვთ შეიყვანოთ პაროლი';
            }
            if (value.length < 6) {
              return 'პაროლი უნდა იყოს მინიმუმ 6 სიმბოლო';
            }
            return null;
          },
        ),

        // Confirm password field (only for registration)
        if (!_isLoginTab) ...[
          const SizedBox(height: 16),
          _buildTextField(
            controller: _confirmPasswordController,
            hint: 'გაიმეორე პაროლი',
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: AppColors.textHint,
              ),
              onPressed:
                  () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'გთხოვთ გაიმეოროთ პაროლი';
              }
              if (value != _passwordController.text) {
                return 'პაროლები არ ემთხვევა';
              }
              return null;
            },
          ),
        ],

        // Remember me checkbox (only for login)
        if (_isLoginTab) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged:
                      (value) => setState(() => _rememberMe = value ?? false),
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Text(
                  'დამახსოვრება',
                  style: TextStyle(color: AppColors.primary, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textHint, fontSize: 15),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final isLoading = authService.state == AuthState.loading || _isLoading;

        return SizedBox(
          width: 200,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child:
                isLoading
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Text(
                      _isLoginTab ? 'შესვლა' : 'რეგისტრაცია',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        );
      },
    );
  }

  Widget _buildForgotPassword() {
    return TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
        );
      },
      child: Text(
        'დაგავიწყდა პაროლი?',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.textHint, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'ან',
            style: TextStyle(color: AppColors.textHint, fontSize: 14),
          ),
        ),
        Expanded(child: Divider(color: AppColors.textHint, thickness: 1)),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      children: [
        // Google Button
        Expanded(
          child: _buildSocialButton(
            onTap: _handleGoogleLogin,
            icon: 'assets/images/google_icon.png',
            fallbackIcon: Icons.g_mobiledata,
            fallbackColor: Colors.red,
          ),
        ),
        const SizedBox(width: 16),
        // Facebook Button
        Expanded(
          child: _buildSocialButton(
            onTap: _handleFacebookLogin,
            icon: 'assets/images/facebook_icon.png',
            fallbackIcon: Icons.facebook,
            fallbackColor: const Color(0xFF1877F2),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required VoidCallback onTap,
    required String icon,
    required IconData fallbackIcon,
    required Color fallbackColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Center(
          child: Image.asset(
            icon,
            width: 28,
            height: 28,
            errorBuilder: (context, error, stackTrace) {
              return Icon(fallbackIcon, size: 32, color: fallbackColor);
            },
          ),
        ),
      ),
    );
  }
}
