import 'package:flutter/material.dart';
import '../services/shop.dart';
import '../theme.dart';

class ProfileEditScreen extends StatefulWidget {
  final Shop shop;
  const ProfileEditScreen({super.key, required this.shop});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final _name = TextEditingController(
    text: widget.shop.user?['name'] ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.shop.user?['phone'] ?? '',
  );
  late final _address = TextEditingController(
    text: widget.shop.user?['address'] ?? '',
  );
  String? _message;
  bool _ok = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final error = await widget.shop.updateProfile(
      _name.text.trim(),
      _phone.text.trim(),
      _address.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ok = error == null;
      _message = error ?? 'Profile saved.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 14),
            TextField(
              enabled: false,
              controller: TextEditingController(
                text: widget.shop.user?['email'] ?? '',
              ),
              decoration: const InputDecoration(
                labelText: 'Email (cannot be changed)',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _address,
              maxLines: 3,
              autofillHints: const [AutofillHints.fullStreetAddress],
              decoration: const InputDecoration(
                // Optional. Saves typing at checkout if the customer
                // chooses delivery; a collected order never reads it.
                labelText: 'Address (optional)',
                hintText: 'Street, city, postcode, state',
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _ok
                      ? const Color(0xFFE3F8E8)
                      : const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(
                    fontSize: 13,
                    color: _ok ? AppTheme.green : AppTheme.red,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
