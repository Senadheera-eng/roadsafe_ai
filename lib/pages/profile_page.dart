import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';

// 1. Convert to StatefulWidget to handle local image state
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Placeholder for the profile image URL (simulate Firebase PhotoURL)
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    // Simulate fetching the initial profile image URL from Firebase
    _profileImageUrl = FirebaseAuth.instance.currentUser?.photoURL;
  }

  // Placeholder for image picking and uploading logic
  void _pickAndSetProfilePhoto() async {
    // In a real app, this would use package:image_picker and Firebase Storage.
    // For now, we simulate success and update the UI state locally.

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Simulating photo selection...')),
    );

    // Simulate successful upload and getting a new URL
    setState(() {
      _profileImageUrl = 'https://placehold.co/100x100/94A3B8/FFFFFF?text=P';
    });

    // In a real app, you would then update the Firebase User profile:
    // await FirebaseAuth.instance.currentUser?.updatePhotoURL(newUrl);
  }

  // Placeholder for photo deletion logic
  void _deleteProfilePhoto() async {
    // In a real app, this would delete the file from Firebase Storage
    // and remove the URL from the Firebase User profile.

    final confirmed = await _showDeleteConfirmation(context);
    if (confirmed) {
      setState(() {
        _profileImageUrl = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile photo removed.')),
      );
      // await FirebaseAuth.instance.currentUser?.updatePhotoURL(null);
    }
  }

  // NEW: Logout Confirmation Dialog (adapted for photo deletion)
  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Confirm Deletion',
              style: AppTextStyles.titleLarge
                  .copyWith(color: AppColors.textPrimary),
            ),
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
            // Option 1: Add/Change Photo
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
            // Option 2: Delete Photo (only if one exists)
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? 'Road Safe User';
    final userEmail = user?.email ?? 'anonymous.user@roadsafeguest.com';
    final userId = user?.uid ?? 'N/A';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("User Profile"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.fromARGB(255, 165, 207, 243), Color(0xFF00f2fe)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),

            // Profile Header Card
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
                          // Display simulated profile photo or fallback icon
                          image: _profileImageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(_profileImageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _profileImageUrl == null
                            ? const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 60,
                              )
                            : null,
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
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Connected Driver',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withOpacity(0.8),
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
                color: Colors.white,
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
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: ListTile(
                leading: const Icon(Icons.videocam_rounded,
                    color: AppColors.success),
                title: const Text('ESP32 CAM Module',
                    style: TextStyle(color: Colors.white)),
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
                subtitle: const Text('Connected via Wi-Fi',
                    style: TextStyle(color: Colors.white70)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          leading: Icon(icon, color: Colors.white),
          title: Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        ),
      ),
    );
  }
}
