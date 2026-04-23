import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/auth_service.dart';
import '../../core/cloudinary_service.dart';
import '../../core/event_service.dart';
import '../../core/theme.dart';
import '../../core/theme_service.dart';
import '../../models/event.dart';
import '../../widgets/banner_upload_field.dart';

class EventFormScreen extends StatefulWidget {
  final AgaramEvent? existing;
  const EventFormScreen({super.key, this.existing});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();

  DateTime _date = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _time = const TimeOfDay(hour: 16, minute: 0);

  File? _bannerFile;
  String? _bannerUrl;
  bool _uploadingBanner = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _descCtrl.text = e.description;
      _venueCtrl.text = e.venue;
      _date = e.date;
      _time = TimeOfDay(hour: e.date.hour, minute: e.date.minute);
      _bannerUrl = e.bannerUrl;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _venueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final user = context.read<AuthService>().currentUser!;
    setState(() => _saving = true);
    try {
      String? finalBannerUrl = _bannerUrl;
      if (_bannerFile != null) {
        setState(() => _uploadingBanner = true);
        finalBannerUrl = await CloudinaryService.uploadEventBanner(_bannerFile!);
        _uploadingBanner = false;
      }

      final combined = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );
      final themeId = MonthlyThemeService.currentYearMonth(combined);

      if (_isEdit) {
        await EventService.updateEvent(widget.existing!.id, {
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'venue': _venueCtrl.text.trim(),
          'date': Timestamp.fromDate(combined),
          'bannerUrl': finalBannerUrl,
          'monthlyTheme': themeId,
        });
      } else {
        await EventService.createEvent({
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'venue': _venueCtrl.text.trim(),
          'date': Timestamp.fromDate(combined),
          'createdBy': user.uid,
          'status': 'upcoming',
          'tasksCount': 0,
          'bannerUrl': finalBannerUrl,
          'monthlyTheme': themeId,
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Event' : 'Create Event'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              BannerUploadField(
                localFile: _bannerFile,
                remoteUrl: _bannerUrl,
                uploading: _uploadingBanner,
                onPicked: (f) => setState(() => _bannerFile = f),
                onClear: () => setState(() {
                  _bannerFile = null;
                  _bannerUrl = null;
                }),
              ),
              const SizedBox(height: 24),
              _label('Event Title'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Sangam Poetry Workshop',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 20),
              _label('Description'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'What’s this event about?',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Date'),
                        const SizedBox(height: 8),
                        _picker(
                          icon: Icons.calendar_today_rounded,
                          value: DateFormat('MMM d, yyyy').format(_date),
                          onTap: _pickDate,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Time'),
                        const SizedBox(height: 8),
                        _picker(
                          icon: Icons.access_time_rounded,
                          value: _time.format(context),
                          onTap: _pickTime,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _label('Venue'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _venueCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Main Auditorium, South Wing',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Venue is required' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: AgaramColors.onPrimary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(_isEdit ? 'Save Changes' : 'Create Event'),
              ),
              const SizedBox(height: 12),
              Text(
                'Add tasks to this event after creating it from the event detail screen.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AgaramColors.onSurfaceVariant,
                ),
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

  Widget _picker({
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: AgaramColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AgaramColors.onSurface,
              ),
            ),
            const Spacer(),
            Icon(icon, color: AgaramColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
