import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/geo/country_options.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Edit profile — identity fields the traveller can change.
///
/// Backend persistence for personal fields is not available yet, so changes
/// are applied to the in-memory session and cached locally; they are not
/// synced to the server.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _avatarCtrl = TextEditingController();
  final _firstCtrl = TextEditingController();
  final _middleCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  DateTime? _dob;
  String? _nationality;
  String? _title;

  Uint8List? _avatarBytes;
  final _picker = ImagePicker();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    if (user != null) {
      _avatarCtrl.text = user.avatarUrl ?? '';
      _phoneCtrl.text = user.phoneNumber ?? '';
      _title = user.title;
      final parts = (user.displayName ?? '').trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty && parts.first.isNotEmpty) _firstCtrl.text = parts.first;
      if (parts.length >= 3) {
        _middleCtrl.text = parts.sublist(1, parts.length - 1).join(' ');
        _lastCtrl.text = parts.last;
      } else if (parts.length == 2) {
        _lastCtrl.text = parts[1];
      }
    }
    _restoreExtended();
  }

  Future<void> _restoreExtended() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    final cache = ref.read(offlineCacheProvider);
    final data = await cache.read('profile:extended:${user.id}');
    if (data == null || !mounted) return;
    setState(() {
      if (data['dob'] is String) {
        _dob = DateTime.tryParse(data['dob'] as String);
      }
      _nationality = data['nationality']?.toString();
      if (data['first'] is String) _firstCtrl.text = data['first'] as String;
      if (data['middle'] is String) _middleCtrl.text = data['middle'] as String;
      if (data['last'] is String) _lastCtrl.text = data['last'] as String;
      if (data['avatar'] is String) _avatarCtrl.text = data['avatar'] as String;
      if (data['phone'] is String) _phoneCtrl.text = data['phone'] as String;
      if (data['title'] is String) _title = data['title'] as String;
    });
  }

  @override
  void dispose() {
    _avatarCtrl.dispose();
    _firstCtrl.dispose();
    _middleCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final mime = picked.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
    setState(() {
      _avatarBytes = bytes;
      _avatarCtrl.text = dataUri;
    });
  }

  Future<void> _save() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final displayName = <String>[
        _firstCtrl.text.trim(),
        _middleCtrl.text.trim(),
        _lastCtrl.text.trim(),
      ].where((s) => s.isNotEmpty).join(' ');
      final updated = user.copyWith(
        displayName: displayName.isEmpty ? null : displayName,
        clearDisplayName: displayName.isEmpty,
        title: _title,
        clearTitle: _title == null,
        firstName: _firstCtrl.text.trim().isEmpty ? null : _firstCtrl.text.trim(),
        clearFirstName: _firstCtrl.text.trim().isEmpty,
        middleName: _middleCtrl.text.trim().isEmpty ? null : _middleCtrl.text.trim(),
        clearMiddleName: _middleCtrl.text.trim().isEmpty,
        lastName: _lastCtrl.text.trim().isEmpty ? null : _lastCtrl.text.trim(),
        clearLastName: _lastCtrl.text.trim().isEmpty,
        dateOfBirth: _dob,
        clearDateOfBirth: _dob == null,
        nationality: _nationality,
        clearNationality: _nationality == null,
        avatarUrl: _avatarCtrl.text.trim().isEmpty ? null : _avatarCtrl.text.trim(),
        clearAvatarUrl: _avatarCtrl.text.trim().isEmpty,
        phoneNumber: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        clearPhoneNumber: _phoneCtrl.text.trim().isEmpty,
      );
      await ref.read(offlineCacheProvider).write(
            'profile:extended:${user.id}',
            <String, dynamic>{
              'title': _title,
              'first': _firstCtrl.text.trim(),
              'middle': _middleCtrl.text.trim(),
              'last': _lastCtrl.text.trim(),
              'dob': _dob?.toIso8601String(),
              'nationality': _nationality,
              'avatar': _avatarCtrl.text.trim(),
              'phone': _phoneCtrl.text.trim(),
            },
          );
      ref.read(authControllerProvider.notifier).updateProfile(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.profileSaved)),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.tokigoColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            AppPageHeader(subtitle: l10n.editProfileSubtitle),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: <Widget>[
                    Center(
                      child: Pressable(
                        onTap: _pickAvatar,
                        child: Stack(
                          children: <Widget>[
                            CircleAvatar(
                              radius: 48,
                              backgroundImage: _avatarBytes != null
                                  ? MemoryImage(_avatarBytes!)
                                  : (_avatarCtrl.text.startsWith('data:')
                                      ? MemoryImage(base64Decode(
                                          _avatarCtrl.text.split(',').last))
                                      : (_avatarCtrl.text.startsWith('http')
                                          ? NetworkImage(_avatarCtrl.text)
                                          : null)),
                              child: _avatarBytes == null &&
                                      !_avatarCtrl.text.startsWith('http') &&
                                      !_avatarCtrl.text.startsWith('data:')
                                  ? const Icon(Icons.person, size: 48)
                                  : null,
                            ),
                            if (_avatarBytes != null ||
                                _avatarCtrl.text.startsWith('data:'))
                              PositionedDirectional(
                                bottom: 0,
                                start: 0,
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor:
                                      context.tokigoColors.successStrong,
                                  child: const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        SizedBox(
                          width: 100,
                          child: _dropdown<String>(
                            label: 'Title',
                            value: _title,
                            items: const <String>['Mr', 'Mrs', 'Ms', 'Dr'],
                            labels: const <String, String>{
                              'Mr': 'Mr',
                              'Mrs': 'Mrs',
                              'Ms': 'Ms',
                              'Dr': 'Dr',
                            },
                            onChanged: (v) => setState(() => _title = v),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: _field(l10n.firstName, _firstCtrl)),
                      ],
                    ),
                    _field(l10n.middleName, _middleCtrl),
                    _field(l10n.lastName, _lastCtrl),
                    _dateField(context, l10n.dateOfBirth),
                    _dropdown<String>(
                      label: l10n.nationality,
                      value: _nationality,
                      items: manualCountryOptions.map((c) => c.code).toList(),
                      labels: <String, String>{
                        for (final c in manualCountryOptions) c.code: c.localizedName(Localizations.localeOf(context)),
                      },
                      onChanged: (v) => setState(() => _nationality = v),
                    ),
                    _readOnlyField(l10n.email, ref.read(authControllerProvider).user?.email ?? ''),
                    _field(l10n.phoneNumber, _phoneCtrl, keyboard: TextInputType.phone),
                    const SizedBox(height: AppSpacing.lg),
                    Pressable.wrap(
                      enabled: !_saving,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.save),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType keyboard = TextInputType.text, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label.isEmpty ? null : label, hintText: hint),
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _dateField(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Pressable.wrap(
        child: InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _dob ?? DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _dob = picked);
          },
          child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Text(
            _dob == null
                ? ''
                : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
          ),
        ),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required Map<T, String> labels,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((e) => DropdownMenuItem<T>(value: e, child: Text(labels[e] ?? e.toString())))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
