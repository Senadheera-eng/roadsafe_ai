import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class ContactService {
  // Road Safe AI Contact Details
  static const String supportEmail = 'roadsafeai.official@gmail.com';
  static const String emergencyPhone = '+94703246233';
  static const String emergencyPhoneFormatted = '+94 70 324 6233';

  /// Send Email to Support
  static Future<bool> sendEmail({
    String? subject,
    String? body,
  }) async {
    final String emailSubject = subject ?? 'Support Request - Road Safe AI';
    final String emailBody = body ?? '';

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: _encodeQueryParameters({
        'subject': emailSubject,
        'body': emailBody,
      }),
    );

    try {
      final canLaunch = await canLaunchUrl(emailUri);

      if (canLaunch) {
        await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication,
        );
        return true;
      } else {
        print('❌ No email app found');
        return false;
      }
    } catch (e) {
      print('❌ Error launching email: $e');
      return false;
    }
  }

  /// Make Phone Call
  static Future<bool> makePhoneCall() async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: emergencyPhone,
    );

    try {
      final canLaunch = await canLaunchUrl(phoneUri);

      if (canLaunch) {
        await launchUrl(
          phoneUri,
          mode: LaunchMode.externalApplication,
        );
        return true;
      } else {
        print('❌ Cannot make phone calls on this device');
        return false;
      }
    } catch (e) {
      print('❌ Error making phone call: $e');
      return false;
    }
  }

  /// Open Dialer (Safer - doesn't auto-call)
  static Future<bool> openDialer() async {
    final Uri dialUri = Uri(
      scheme: 'tel',
      path: emergencyPhone,
    );

    try {
      final canLaunch = await canLaunchUrl(dialUri);

      if (canLaunch) {
        await launchUrl(dialUri);
        return true;
      } else {
        print('❌ Cannot open dialer');
        return false;
      }
    } catch (e) {
      print('❌ Error opening dialer: $e');
      return false;
    }
  }

  /// Copy to Clipboard (Fallback)
  static void copyToClipboard(BuildContext context, String text, String label) {
    // You can use Clipboard.setData if you import 'package:flutter/services.dart'
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Helper: Encode query parameters for URI
  static String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
