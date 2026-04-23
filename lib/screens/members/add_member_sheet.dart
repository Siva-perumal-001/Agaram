import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/members_service.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';

class AddMemberSheet extends StatefulWidget {
  const AddMemberSheet({super.key});

  @override
  State<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  String _role = 'member';
  String? _position = AppPosition.member;
  bool _obscure = true;
  bool _saving = false;
  MemberCreationResult? _result;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _fillSuggested() {
    setState(() {
      _password.text = MembersService.suggestPassword();
      _obscure = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final result = await MembersService.createMember(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        role: _role,
        position: _position,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t create account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: _result != null ? _successView(_result!) : _formView(),
      ),
    );
  }

  Widget _formView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add Member',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AgaramColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Register a new enthusiast to the scholarly circle.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AgaramColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _label('Full name'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'E.g. Elango Adigal'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 14),
          _label('Email address'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'member@agaram.edu'),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Email is required';
              if (!value.contains('@') || !value.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _label('Phone number (optional)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: '+91 00000 00000'),
          ),
          const SizedBox(height: 14),
          _label('Password (required)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: 'Type a password they can use to sign in',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AgaramColors.onSurfaceVariant,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'At least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Min. 6 characters',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AgaramColors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _fillSuggested,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Text(
                    'Suggest strong password',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AgaramColors.secondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Share this with them via WhatsApp/SMS after creating the account.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AgaramColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _label('Position'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _position,
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
              ...AppPosition.all.map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text(AppPosition.label(p)),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _position = v),
            decoration: const InputDecoration(
              hintText: 'Pick a position',
            ),
          ),
          const SizedBox(height: 18),
          _label('Initial role'),
          const SizedBox(height: 8),
          Row(
            children: [
              _roleChip('Member', 'member'),
              const SizedBox(width: 10),
              _roleChip('Admin', 'admin'),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: AgaramColors.onPrimary,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('Create account'),
          ),
        ],
      ),
    );
  }

  Widget _successView(MemberCreationResult r) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            height: 84,
            width: 84,
            decoration: const BoxDecoration(
              color: AgaramColors.successContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              size: 40,
              color: AgaramColors.success,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            'Account Created',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AgaramColors.successDark,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Account successfully created for ${_name.text.trim()}. '
          'Share the password with them to let them sign in.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AgaramColors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AgaramColors.successContainer,
            borderRadius: BorderRadius.circular(14),
            border: const Border(
              left: BorderSide(color: AgaramColors.success, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Temporary Credentials',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AgaramColors.successDark,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      r.password,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AgaramColors.primary,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: AgaramColors.success,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: r.password));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password copied')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AgaramColors.success,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AgaramColors.onSurfaceVariant,
        ),
      );

  Widget _roleChip(String label, String value) {
    final selected = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AgaramColors.secondaryContainer
              : AgaramColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_rounded,
                size: 14,
                color: AgaramColors.secondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
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
