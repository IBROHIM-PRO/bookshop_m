import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;

  String _getFullImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${ApiService.baseUrl}$url';
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Future<void> _pickAndUploadAvatar() async {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result == null || result.files.single.path == null) return;

      final pickedFile = result.files.single;

      if (pickedFile.size > 1 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ҳаҷми расм набояд аз 1 МБ зиёд бошад!'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      setState(() {
        _isUploading = true;
      });

      final response = await ApiService.uploadAvatar(pickedFile.path!, pickedFile.name);
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final imageUrl = resData['imageUrl'] as String;

        if (mounted) {
          await Provider.of<AuthProvider>(context, listen: false).updateCurrentUserImageUrl(imageUrl);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Расми профил бомуваффақият боргузорӣ шуд!'),
              backgroundColor: isDarkMode ? Colors.white : Colors.black,
            ),
          );
        }
      } else {
        final resData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resData['message'] ?? 'Хатогӣ дар боргузории расм'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Хатогии пайвастшавӣ бо сервер'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    if (user == null) return const SizedBox.shrink();

    final hasImage = user.imageUrl != null && user.imageUrl!.isNotEmpty;

    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final theme = Theme.of(context);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : const Color(0xFFEBF3ED);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 36),
              decoration: BoxDecoration(
                color: isDarkMode ? theme.appBarTheme.backgroundColor : Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
                boxShadow: isDarkMode ? [] : [
                  BoxShadow(
                    color: const Color(0xFF228B22).withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border(
                  bottom: BorderSide(
                    color: isDarkMode ? Colors.white10 : const Color(0xFF1E7431).withOpacity(0.15),
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: textColor.withOpacity(0.1),
                          border: Border.all(
                            color: isDarkMode ? Colors.white24 : const Color(0xFF1E7431).withOpacity(0.25),
                            width: 3,
                          ),
                        ),
                        child: _isUploading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: textColor,
                                ),
                              )
                            : ClipOval(
                                child: hasImage
                                    ? CachedNetworkImage(
                                        imageUrl: _getFullImageUrl(user.imageUrl),
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Center(
                                          child: CircularProgressIndicator(color: textColor, strokeWidth: 2),
                                        ),
                                        errorWidget: (context, url, error) => Center(
                                          child: Text(
                                            _getInitials(user.name),
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          _getInitials(user.name),
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploading ? null : _pickAndUploadAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: textColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: isDarkMode ? Colors.black : Colors.white, width: 2),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: isDarkMode ? Colors.black : Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: textColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      _roleLabel(user.role),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                _buildSectionTitle('Маълумоти шахсӣ', textColor),
                const SizedBox(height: 12),
                _buildInfoCard(Icons.email_outlined, 'Email', user.email, textColor),
                if (user.phone != null && user.phone!.isNotEmpty)
                  _buildInfoCard(Icons.phone_outlined, 'Телефон', user.phone!, textColor),
                _buildInfoCard(Icons.badge_outlined, 'Нақш', _roleLabel(user.role), textColor),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: TextButton.icon(
              onPressed: () async {
                await Provider.of<AuthProvider>(context, listen: false).logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout, color: Color(0xFFD32F2F)),
              label: const Text(
                'Хуруҷ',
                style: TextStyle(
                  color: Color(0xFFD32F2F),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'Reader':
        return 'Хонанда';
      case 'Parent':
        return 'Волидайн';
      case 'Admin':
        return 'Администратор';
      default:
        return role;
    }
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        color: textColor.withOpacity(0.5),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value, Color textColor) {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? textColor.withOpacity(0.1) : const Color(0xFF1E7431).withOpacity(0.15),
        ),
        boxShadow: isDarkMode ? [] : [
          BoxShadow(
            color: const Color(0xFF228B22).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFEBF3ED),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isDarkMode ? textColor : const Color(0xFF1E7431),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDarkMode ? textColor.withOpacity(0.4) : const Color(0xFF657367),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: isDarkMode ? textColor : const Color(0xFF1A1F1C),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
