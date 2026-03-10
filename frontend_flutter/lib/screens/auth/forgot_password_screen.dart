import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _api = ApiClient();
  final _emailCtrl = TextEditingController();
  final List<TextEditingController> _codeCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocus = List.generate(6, (_) => FocusNode());
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  int _step = 1;
  bool _loading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    for (final c in _codeCtrl) c.dispose();
    for (final f in _codeFocus) f.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  String get _code => _codeCtrl.map((c) => c.text).join();

  void _show(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? C.destructive : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) { _show('Entrez votre email'); return; }
    setState(() => _loading = true);
    try {
      await _api.dio.post('/auth/forgot-password', data: {'email': email});
      if (mounted) setState(() { _step = 2; _loading = false; });
    } catch (_) {
      if (mounted) {
        _show('Erreur lors de l\'envoi du code');
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final code = _code;
    if (code.length < 6) { _show('Entrez le code à 6 chiffres'); return; }
    if (_newPassCtrl.text.length < 6) {
      _show('Le mot de passe doit contenir au moins 6 caractères'); return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      _show('Les mots de passe ne correspondent pas'); return;
    }
    setState(() => _loading = true);
    try {
      await _api.dio.post('/auth/reset-password', data: {
        'email': _emailCtrl.text.trim(),
        'code': code,
        'new_password': _newPassCtrl.text,
      });
      if (mounted) {
        _show('Mot de passe réinitialisé !', error: false);
        context.go('/login');
      }
    } catch (e) {
      String msg = 'Code invalide ou expiré';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map && data['detail'] != null) msg = data['detail'];
      } catch (_) {}
      if (mounted) {
        _show(msg);
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _step == 2
              ? setState(() { _step = 1; _loading = false; })
              : context.pop(),
        ),
        title: Text(_step == 1 ? 'Mot de passe oublié' : 'Nouveau mot de passe'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.1, 0), end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: _step == 1
                  ? _Step1(
                      key: const ValueKey(1),
                      emailCtrl: _emailCtrl,
                      loading: _loading,
                      onSend: _sendCode,
                    )
                  : _Step2(
                      key: const ValueKey(2),
                      email: _emailCtrl.text.trim(),
                      codeCtrl: _codeCtrl,
                      codeFocus: _codeFocus,
                      newPassCtrl: _newPassCtrl,
                      confirmPassCtrl: _confirmPassCtrl,
                      obscureNew: _obscureNew,
                      obscureConfirm: _obscureConfirm,
                      toggleNew: () => setState(() => _obscureNew = !_obscureNew),
                      toggleConfirm: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      loading: _loading,
                      onReset: _resetPassword,
                      onResend: () {
                        for (final c in _codeCtrl) c.clear();
                        setState(() => _step = 1);
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Step 1: email ────────────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final TextEditingController emailCtrl;
  final bool loading;
  final VoidCallback onSend;
  const _Step1({super.key, required this.emailCtrl, required this.loading, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: C.primaryLight,
              borderRadius: BorderRadius.circular(C.radius2xl),
            ),
            child: const Icon(Icons.lock_reset_outlined, color: C.primary, size: 36),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Mot de passe oublié ?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                color: C.textPrimary, letterSpacing: -0.3)),
        const SizedBox(height: 8),
        const Text(
          'Entrez votre email et nous vous enverrons un code de vérification à 6 chiffres.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: C.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 32),
        const Text('Email',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSend(),
          decoration: const InputDecoration(
            hintText: 'vous@example.com',
            prefixIcon: Icon(Icons.email_outlined, size: 18, color: C.textSecondary),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: loading ? null : onSend,
            child: loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Envoyer le code'),
          ),
        ),
      ],
    );
  }
}

// ─── Step 2: code + new password ─────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  final String email;
  final List<TextEditingController> codeCtrl;
  final List<FocusNode> codeFocus;
  final TextEditingController newPassCtrl;
  final TextEditingController confirmPassCtrl;
  final bool obscureNew, obscureConfirm, loading;
  final VoidCallback toggleNew, toggleConfirm, onReset, onResend;
  const _Step2({
    super.key, required this.email, required this.codeCtrl, required this.codeFocus,
    required this.newPassCtrl, required this.confirmPassCtrl,
    required this.obscureNew, required this.obscureConfirm,
    required this.toggleNew, required this.toggleConfirm,
    required this.loading, required this.onReset, required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: C.blueLight,
              borderRadius: BorderRadius.circular(C.radius2xl),
            ),
            child: const Icon(Icons.mark_email_read_outlined, color: C.blue, size: 36),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Vérification du code',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.textPrimary)),
        const SizedBox(height: 6),
        Text('Code envoyé à\n$email',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: C.textSecondary, height: 1.5)),
        const SizedBox(height: 28),

        const Text('Code à 6 chiffres',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSecondary)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _CodeBox(
            controller: codeCtrl[i],
            focusNode: codeFocus[i],
            onChanged: (val) {
              if (val.isNotEmpty && i < 5) {
                FocusScope.of(context).requestFocus(codeFocus[i + 1]);
              } else if (val.isEmpty && i > 0) {
                FocusScope.of(context).requestFocus(codeFocus[i - 1]);
              }
            },
          )),
        ),
        const SizedBox(height: 20),

        const Text('Nouveau mot de passe',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: newPassCtrl,
          obscureText: obscureNew,
          decoration: InputDecoration(
            hintText: 'Au moins 6 caractères',
            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: C.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18, color: C.textTertiary),
              onPressed: toggleNew,
            ),
          ),
        ),
        const SizedBox(height: 12),

        const Text('Confirmer le mot de passe',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: confirmPassCtrl,
          obscureText: obscureConfirm,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onReset(),
          decoration: InputDecoration(
            hintText: 'Répétez le mot de passe',
            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: C.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18, color: C.textTertiary),
              onPressed: toggleConfirm,
            ),
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: loading ? null : onReset,
            child: loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Réinitialiser le mot de passe'),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: loading ? null : onResend,
          child: const Text('Renvoyer le code', style: TextStyle(color: C.textSecondary)),
        ),
      ],
    );
  }
}

// ─── Code digit box ───────────────────────────────────────────────────────────

class _CodeBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  const _CodeBox({required this.controller, required this.focusNode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: C.textPrimary),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: C.surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(C.radiusBase),
            borderSide: const BorderSide(color: C.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(C.radiusBase),
            borderSide: const BorderSide(color: C.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(C.radiusBase),
            borderSide: const BorderSide(color: C.primary, width: 2),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
