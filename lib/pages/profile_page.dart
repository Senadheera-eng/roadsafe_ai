import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';

// Import necessary dart:math for random image simulation
import 'dart:math';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _profileImageUrl = FirebaseAuth.instance.currentUser?.photoURL;
  }

  // --- Photo Management Logic ---
  String _generateSimulatedImageUrl() {
    final seed = DateTime.now().millisecondsSinceEpoch;
    final size = Random(seed).nextInt(50) + 100; // Random size for variance
    return 'https://placehold.co/${size}x${size}/0066FF/FFFFFF?text=PIC&s=$seed';
  }

  void _pickAndSetProfilePhoto() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Picking and uploading new photo...')),
    );
    final newUrl = _generateSimulatedImageUrl();
    try {
      await FirebaseAuth.instance.currentUser?.updatePhotoURL(newUrl);
      setState(() {
        _profileImageUrl = FirebaseAuth.instance.currentUser?.photoURL;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating photo: ${e.toString()}')),
      );
    }
  }

  void _deleteProfilePhoto() async {
    final confirmed = await _showDeleteConfirmation(context);
    if (confirmed) {
      try {
        await FirebaseAuth.instance.currentUser?.updatePhotoURL(null);
        setState(() {
          _profileImageUrl = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo removed successfully.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing photo: ${e.toString()}')),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Confirm Deletion', style: AppTextStyles.titleLarge),
            content: Text(
              'Are you sure you want to remove your profile photo?',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.primary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Remove',
                    style:
                        AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionTile(
              icon: Icons.camera_alt_rounded,
              title: _profileImageUrl == null
                  ? 'Add Profile Photo'
                  : 'Change Profile Photo',
              onTap: () {
                Navigator.pop(context);
                _pickAndSetProfilePhoto();
              },
            ),
            if (_profileImageUrl != null)
              _buildOptionTile(
                icon: Icons.delete_forever_rounded,
                title: 'Remove Photo',
                color: AppColors.error,
                onTap: () {
                  Navigator.pop(context);
                  _deleteProfilePhoto();
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final itemColor = color ?? AppColors.textPrimary;

    return ListTile(
      leading: Icon(icon, color: itemColor),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: itemColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // --- UI Build Method ---

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? 'Road Safe User';
    final userEmail = user?.email ?? 'anonymous.user@roadsafeguest.com';
    final userId = user?.uid ?? 'N/A';

    // Text colors are set to white/light to contrast with the dark gradient
    const Color textColor = Colors.white;
    const Color secondaryTextColor = Colors.white70;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("User Profile", style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        // ** Gradient Background for attractive UI **
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.oceanGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),

            // Profile Header Card (Uses GlassCard for the aesthetic)
            GlassCard(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  // Avatar with Edit Button
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 3,
                          ),
                        ),
                        child: user?.photoURL != null
                            ? ClipOval(
                                child: Image.network(
                                  user!.photoURL!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(Icons.person_rounded,
                                          color: textColor.withOpacity(0.8),
                                          size: 60),
                                ),
                              )
                            : Icon(
                                Icons.person_rounded,
                                color: textColor.withOpacity(0.8),
                                size: 60,
                              ),
                      ),
                      // Edit Button
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _showImageOptions,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text(
                    userName,
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Connected Driver',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Details Section
            Text(
              'Account Details',
              style: AppTextStyles.titleLarge.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailTile(
              icon: Icons.email_rounded,
              title: 'Email',
              subtitle: userEmail,
            ),
            _buildDetailTile(
              icon: Icons.vpn_key_rounded,
              title: 'User ID (UID)',
              subtitle: userId,
            ),
            _buildDetailTile(
              icon: Icons.join_full_rounded,
              title: 'Member Since',
              subtitle: user?.metadata.creationTime != null
                  ? 'Joined: ${user!.metadata.creationTime!.year}-${user.metadata.creationTime!.month.toString().padLeft(2, '0')}'
                  : 'N/A',
            ),
            const SizedBox(height: 24),

            // Device Info Placeholder
            Text(
              'Device Status',
              style: AppTextStyles.titleLarge.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: ListTile(
                leading: const Icon(Icons.videocam_rounded,
                    color: AppColors.success),
                title: const Text('ESP32 CAM Module',
                    style: TextStyle(color: textColor)),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Online',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.success)),
                ),
                subtitle: Text('Connected via Wi-Fi',
                    style: TextStyle(color: secondaryTextColor)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    // Colors are hardcoded to contrast with the background gradient
    const Color textColor = Colors.white;
    const Color secondaryTextColor = Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          leading: Icon(icon, color: textColor),
          title: Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: AppTextStyles.bodyMedium.copyWith(
              color: secondaryTextColor,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        ),
      ),
    );
  }
}
