import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/auth_service.dart';
import '../../core/fcm_service.dart';
import '../../core/notifications_service.dart';
import '../../core/theme.dart';
import '../../models/app_notification.dart';

class ComposeNotificationScreen extends StatefulWidget {
  const ComposeNotificationScreen({super.key});

  @override
  State<ComposeNotificationScreen> createState() =>
      _ComposeNotificationScreenState();
}

class _ComposeNotificationScreenState extends State<ComposeNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  String _audience = AppConfig.topicAllMembers;
  AppNotificationKind _kind = AppNotificationKind.announcement;
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final admin = context.read<AuthService>().currentUser;
    if (admin == null) return;

    setState(() => _sending = true);
    try {
      await NotificationsService.save(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        kind: _kind,
        topic: _audience,
        sentBy: admin.uid,
        sentByName: admin.name,
      );
      await FcmService.sendToTopic(
        topic: _audience,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        data: {'kind': kindToString(_kind)},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sent ✓')),
      );
      Navigator.of(context).pop(true);
    } on FcmException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          'Saved but push failed: ${e.message}\n'
          'Check that assets/fcm-service-account.json is in place.',
        )),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t send: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Notification'),
        actions: [
          TextButton(
            onPressed: _sending ? null : _send,
            child: const Text('Send'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _label('Send to'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _audienceChip(
                    'All members',
                    AppConfig.topicAllMembers,
                    Icons.people_alt_rounded,
                  ),
                  const SizedBox(width: 10),
                  _audienceChip(
                    'Admins only',
                    AppConfig.topicAdmins,
                    Icons.shield_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _label('Category'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _kindChip(
                    AppNotificationKind.announcement,
                    'Announcement',
                    Icons.campaign_rounded,
                  ),
                  const SizedBox(width: 8),
                  _kindChip(
                    AppNotificationKind.event,
                    'Event',
                    Icons.calendar_today_rounded,
                  ),
                  const SizedBox(width: 8),
                  _kindChip(
                    AppNotificationKind.task,
                    'Task',
                    Icons.task_alt_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _label('Title'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                maxLength: 80,
                decoration: const InputDecoration(
                  hintText: 'Short, clear headline',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              _label('Message'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bodyCtrl,
                maxLength: 500,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'What do you want members to know?',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Message is required' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: AgaramColors.onPrimary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'Sending…' : 'Send notification'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AgaramColors.onSurface,
        ),
      );

  Widget _audienceChip(String label, String topic, IconData icon) {
    final selected = _audience == topic;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _audience = topic),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? AgaramColors.primaryContainer
                : AgaramColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : AgaramColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AgaramColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kindChip(AppNotificationKind k, String label, IconData icon) {
    final selected = _kind == k;
    return GestureDetector(
      onTap: () => setState(() => _kind = k),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AgaramColors.secondaryContainer
              : AgaramColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? AgaramColors.secondary
                  : AgaramColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AgaramColors.secondary
                    : AgaramColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
