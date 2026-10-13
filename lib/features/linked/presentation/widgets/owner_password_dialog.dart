// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../../core/breakpoints.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/armx_button.dart';
import '../../../../core/widgets/armx_text_field.dart';

/// Asks for the password of the account that linked a device.
///
/// ## Why this is a second step, after the confirmation dialog
///
/// The dialog answers *"do you want to do this?"*. This answers *"are you allowed to?"*.
/// Folding them into one control produces a single button that both confirms and
/// authenticates, which is how people learn to type a password without reading what it is
/// for.
///
/// The password is returned to the caller and used once. It is never stored, never logged,
/// and never sent anywhere except the one unlink request it was collected for.
class OwnerPasswordDialog extends StatefulWidget {
  /// Creates the dialog.
  const OwnerPasswordDialog({
    required this.deviceName,
    this.ownerEmail,
    super.key,
  });

  /// Device being unlinked, named in the dialog.
  final String deviceName;

  /// The account that linked it, when known.
  final String? ownerEmail;

  /// Shows the dialog; resolves to the typed password or `null` when cancelled.
  static Future<String?> show(
    BuildContext context, {
    required String deviceName,
    String? ownerEmail,
  }) =>
      showDialog<String>(
        context: context,
        builder: (BuildContext context) => OwnerPasswordDialog(
          deviceName: deviceName,
          ownerEmail: ownerEmail,
        ),
      );

  @override
  State<OwnerPasswordDialog> createState() => _OwnerPasswordDialogState();
}

class _OwnerPasswordDialogState extends State<OwnerPasswordDialog> {
  final TextEditingController _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _password.text;
    if (value.isEmpty) {
      setState(() => _error = context.l10n.validatorRequired);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.linkedUnlinkOwnerPassword),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.l10n.linkedUnlinkOwnerPasswordHelp,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Insets.lg),
            if (widget.ownerEmail != null) ...<Widget>[
              Text(
                widget.ownerEmail!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: Insets.sm),
            ],
            ArmxTextField(
              label: context.l10n.linkedUnlinkOwnerPassword,
              controller: _password,
              obscureText: true,
              autofocus: true,
              errorText: _error,
              required: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              widget.deviceName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        ArmxButton(
          label: context.l10n.commonCancel,
          variant: ArmxButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ArmxButton(
          label: context.l10n.linkedUnlink,
          variant: ArmxButtonVariant.destructive,
          onPressed: _submit,
        ),
      ],
    );
  }
}
