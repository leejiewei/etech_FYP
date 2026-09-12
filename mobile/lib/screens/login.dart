import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/shop.dart';
import '../theme.dart';

/// Sign in, or create an account. One screen with a toggle, since the two
/// forms are nearly identical.
class LoginScreen extends StatefulWidget {
  final Shop shop;
  final bool startOnRegister;
  const LoginScreen({
    super.key,
    required this.shop,
    this.startOnRegister = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late bool _registering = widget.startOnRegister;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  // Set when a sign-up succeeded but the address still has to be
  // confirmed by email. A success, so it is not shown as an error.
  String? _notice;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _notice = null;
      _busy = true;
    });

    String? error;
    if (_registering) {
      if (_password.text != _confirm.text) {
        setState(() {
          _error = 'Passwords do not match.';
          _busy = false;
        });
        return;
      }
      final result = await widget.shop.register(
        _name.text.trim(),
        _email.text.trim(),
        _password.text,
      );

      if (!mounted) return;

      // Made, but the address needs confirming before there is a session.
      // A success shown in the red box would read as a failed sign-up, so
      // it gets its own notice and the screen stays put rather than
      // popping back signed out.
      if (result.ok && result.message != null) {
        setState(() {
          _notice = result.message;
          _error = null;
          _busy = false;
        });
        return;
      }

      error = result.ok ? null : result.message;
    } else {
      error = await widget.shop.login(_email.text.trim(), _password.text);
    }

    if (!mounted) return;
    if (error == null) {
      // The sign-in worked, so the fields held a real account. This is
      // what makes Android and iOS offer to save or update the password;
      // without it the group is abandoned when the screen pops and the
      // offer never appears. Only on success -- offering to save a
      // password that was just rejected would be worse than useless.
      TextInput.finishAutofillContext();
      Navigator.pop(context);
    } else {
      setState(() {
        _error = error;
        _busy = false;
      });
    }
  }

  /// Asks for the reset mail, using whatever is already in the email box.
  ///
  /// The reply is shown in the green notice rather than the red one, and it
  /// is the same reply whether or not the address has an account -- see
  /// Shop.requestPasswordReset for why. The only red answer here is a
  /// malformed address, which says nothing about who is registered.
  Future<void> _resetPassword() async {
    setState(() {
      _error = null;
      _notice = null;
      _busy = true;
    });

    final result = await widget.shop.requestPasswordReset(_email.text);

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.ok) {
        _notice = result.message;
      } else {
        _error = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_registering ? 'Create Account' : 'Sign In')),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const SizedBox(height: 10),
            const Center(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'e',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.ink,
                      ),
                    ),
                    TextSpan(
                      text: 'Tech',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            if (_registering)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
              ),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              // username as well as email: the account identifier here is
              // the address, and username is the hint a password manager
              // pairs with a password to store one credential.
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: true,
              // newPassword while registering, so the manager offers to
              // generate one and does not try to fill an existing password
              // into what is a new account.
              autofillHints: [
                _registering
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (_registering) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _confirm,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
              ),
            ],
            if (_notice != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _notice!,
                  style: const TextStyle(color: Color(0xFF1E8E3E), fontSize: 13),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.red, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_registering ? 'Create account' : 'Sign in'),
              ),
            ),
            if (!_registering)
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _resetPassword,
                  child: const Text('Forgot your password?'),
                ),
              ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _registering = !_registering;
                  _error = null;
                  _notice = null;
                }),
                child: Text(
                  _registering
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account',
                ),
              ),
            ),
            if (_registering)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'This is a student project — please do not use a password you '
                  'use anywhere else.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
