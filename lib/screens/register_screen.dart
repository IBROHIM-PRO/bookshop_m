import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_snackbar.dart';
import 'reader/reader_home.dart';
import 'parent/parent_dashboard.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRole = 'Reader'; // Reader, Parent

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final error = await authProvider.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _selectedRole,
      _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    );

    if (!mounted) return;

    if (error != null) {
      AppSnackBar.show(
        context,
        message: error,
        type: error.contains('суст') ? SnackBarType.warning : SnackBarType.error,
      );
    } else {
      if (_selectedRole == 'Parent') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ParentDashboardScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ReaderHomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<AuthProvider>(context).isLoading;
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Бақайдгирӣ',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ҳисоби нави худро созед',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: textColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Role Selector Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildRoleCard('Reader', 'Хонанда', Icons.school_outlined, textColor, backgroundColor),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildRoleCard('Parent', 'Волидайн', Icons.people_alt_outlined, textColor, backgroundColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Name Field
                      _buildTextField(_nameController, 'Ном ва Насаб', Icons.person_outline, textColor),
                      const SizedBox(height: 20),
                      // Email Field
                      _buildTextField(_emailController, 'Email', Icons.email_outlined, textColor, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 20),
                      // Phone Field
                      _buildTextField(_phoneController, 'Телефони мобилӣ (Ихтиёрӣ)', Icons.phone_outlined, textColor, keyboardType: TextInputType.phone),
                      const SizedBox(height: 20),
                      // Password Field
                      _buildTextField(_passwordController, 'Парол', Icons.lock_outline, textColor, obscureText: true),
                      const SizedBox(height: 32),
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode ? textColor : const Color(0xFF1E7431),
                            foregroundColor: isDarkMode ? backgroundColor : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? CircularProgressIndicator(color: isDarkMode ? backgroundColor : Colors.white)
                              : const Text(
                                  'Бақайдгирӣ',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Аллакай саҳифа доред? ',
                      style: TextStyle(color: textColor.withOpacity(0.6)),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Ворид шудан',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(String role, String label, IconData icon, Color textColor, Color backgroundColor) {
    final isSelected = _selectedRole == role;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Color activeBg = isDarkMode ? textColor : const Color(0xFF1E7431);
    Color activeFg = isDarkMode ? backgroundColor : Colors.white;
    Color inactiveBg = isDarkMode ? textColor.withOpacity(0.05) : Colors.white;
    Color inactiveBorder = isDarkMode ? textColor.withOpacity(0.1) : const Color(0xFFD1E2D5);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeBg : inactiveBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected || isDarkMode ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? activeFg : (isDarkMode ? textColor.withOpacity(0.6) : const Color(0xFF657367)),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? activeFg : (isDarkMode ? textColor.withOpacity(0.6) : const Color(0xFF657367)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, Color textColor, {TextInputType? keyboardType, bool obscureText = false}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDarkMode ? textColor.withOpacity(0.6) : const Color(0xFF657367)),
        prefixIcon: Icon(icon, color: isDarkMode ? textColor : const Color(0xFF657367)),
        filled: true,
        fillColor: isDarkMode ? textColor.withOpacity(0.05) : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDarkMode ? textColor.withOpacity(0.1) : const Color(0xFFD1E2D5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDarkMode ? textColor : const Color(0xFF1E7431), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          if (label.contains('Ихтиёрӣ')) return null;
          return 'Илтимос, маълумотро ворид кунед';
        }
        if (label == 'Email' && !value.contains('@')) {
          return 'Email-и дурустро ворид кунед';
        }
        if (label == 'Парол' && value.length < 6) {
          return 'Парол бояд на камтар аз 6 аломат бошад';
        }
        return null;
      },
    );
  }
}
