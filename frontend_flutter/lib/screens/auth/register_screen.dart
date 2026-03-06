import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_nameCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty) {
      _show('Veuillez remplir tous les champs');
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      _show('Les mots de passe ne correspondent pas');
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      _show('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().register(
            _nameCtrl.text.trim(),
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
          );
    } catch (_) {
      if (mounted) _show('Erreur lors de la création du compte');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: C.destructive,
      behavior: SnackBarBehavior.floating,
    ));
  }

  InputDecoration _fieldDecoration({required String hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: C.textPlaceholder, fontSize: 14),
      filled: true,
      fillColor: C.surfaceAlt,
      isDense: true,
      isCollapsed: false,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
        borderSide: const BorderSide(color: C.primary, width: 1.5),
      ),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.background,
      body: Center(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: C.primaryLight,
                        borderRadius: BorderRadius.circular(C.radiusXl),
                      ),
                      child: const Icon(Icons.favorite_border_rounded,
                          color: C.primary, size: 32),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Créer un compte',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: C.textPrimary,
                        letterSpacing: -0.4),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rejoignez votre famille',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 14, color: C.textSecondary),
                  ),
                  const SizedBox(height: 28),

                  // Nom
                  const _Label('Nom complet'),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 48,
                    child: TextFormField(
                      controller: _nameCtrl,
                      focusNode: _nameFocus,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context)
                          .requestFocus(_emailFocus),
                      decoration:
                          _fieldDecoration(hint: 'Jean Dupont'),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Email
                  const _Label('Email'),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 48,
                    child: TextFormField(
                      controller: _emailCtrl,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context)
                          .requestFocus(_passwordFocus),
                      decoration:
                          _fieldDecoration(hint: 'vous@example.com'),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Password
                  const _Label('Mot de passe'),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 48,
                    child: TextFormField(
                      controller: _passwordCtrl,
                      focusNode: _passwordFocus,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context)
                          .requestFocus(_confirmFocus),
                      decoration: _fieldDecoration(
                        hint: 'Au moins 6 caractères',
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: C.textTertiary,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Confirm
                  const _Label('Confirmer le mot de passe'),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 48,
                    child: TextFormField(
                      controller: _confirmCtrl,
                      focusNode: _confirmFocus,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleRegister(),
                      decoration: _fieldDecoration(
                          hint: 'Répétez le mot de passe'),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleRegister,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Text("S'inscrire"),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Link
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: const Text.rich(
                      TextSpan(
                        text: 'Déjà un compte ? ',
                        style: TextStyle(
                            fontSize: 14, color: C.textSecondary),
                        children: [
                          TextSpan(
                            text: 'Se connecter',
                            style: TextStyle(
                                color: C.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String label;
  const _Label(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: C.textSecondary,
          letterSpacing: 0.1));
}
