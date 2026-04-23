import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/event_service.dart';
import '../../core/theme.dart';
import '../../models/event.dart';

class AddTaskScreen extends StatefulWidget {
  final AgaramEvent event;
  const AddTaskScreen({super.key, required this.event});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _dueDate;
  String? _memberUid;
  String? _memberName;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? widget.event.date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickMember() async {
    final selected = await showModalBottomSheet<_MemberChoice>(
      context: context,
      backgroundColor: AgaramColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _MemberPicker(),
    );
    if (selected != null) {
      setState(() {
        _memberUid = selected.uid;
        _memberName = selected.name;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_memberUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a member to assign this task to.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await EventService.addTask(
        eventId: widget.event.id,
        eventTitle: widget.event.title,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        assignedTo: _memberUid!,
        assignedToName: _memberName ?? '',
        dueDate: _dueDate,
      );
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
        title: const Text('Add Task'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Text(
                'Event: ${widget.event.title}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AgaramColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _label('Task title'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Write a verse on monsoon',
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
                  hintText: 'What does the member need to do?',
                ),
              ),
              const SizedBox(height: 20),
              _label('Due date'),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDue,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: AgaramColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _dueDate == null
                            ? 'Pick a due date'
                            : DateFormat('MMM d, yyyy').format(_dueDate!),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AgaramColors.onSurface,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: AgaramColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _label('Assigned to'),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickMember,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: AgaramColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        color: AgaramColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _memberName ?? 'Pick a member',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _memberName == null
                                ? AgaramColors.onSurfaceVariant
                                : AgaramColors.onSurface,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AgaramColors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),
              FilledButton(
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
                    : const Text('Add Task'),
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
}

class _MemberChoice {
  final String uid;
  final String name;
  const _MemberChoice(this.uid, this.name);
}

class _MemberPicker extends StatelessWidget {
  const _MemberPicker();

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance.collection('users').snapshots();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                Text(
                  'Pick a member',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AgaramColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No members yet'));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final name = (d['name'] as String?) ?? 'Member';
                    final email = (d['email'] as String?) ?? '';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AgaramColors.primaryContainer,
                        child: Text(
                          name.isEmpty ? 'A' : name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text(email),
                      onTap: () => Navigator.of(context).pop(
                        _MemberChoice(docs[i].id, name),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
