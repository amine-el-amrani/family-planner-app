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
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_nameCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty) {
      _showError('Veuillez remplir tous les champs');
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      _showError('Les mots de passe ne correspondent pas');
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      _showError('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().register(
        _nameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
    } catch (e) {
      if (mounted) _showError('Erreur lors de la création du compte');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: C.destructive,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: C.primaryLight,
                    borderRadius: BorderRadius.circular(C.radiusXl),
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    color: C.primary,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Créer un compte',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: C.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Rejoignez votre famille',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: C.textSecondary),
              ),
              const SizedBox(height: 32),
              const _FieldLabel(label: 'Nom complet'),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Jean Dupont'),
              ),
              const SizedBox(height: 16),
              const _FieldLabel(label: 'Email'),
              const SizedBox(height: 6),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'vous@example.com'),
              ),
              const SizedBox(height: 16),
              const _FieldLabel(label: 'Mot de passe'),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Au moins 6 caractères',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: C.textTertiary,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _FieldLabel(label: 'Confirmer le mot de passe'),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleRegister(),
                decoration: const InputDecoration(
                  hintText: 'Répétez le mot de passe',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _handleRegister,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("S'inscrire"),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: const Text.rich(
                  TextSpan(
                    text: 'Déjà un compte ? ',
                    style: TextStyle(fontSize: 14, color: C.textSecondary),
                    children: [
                      TextSpan(
                        text: 'Se connecter',
                        style: TextStyle(
                          color: C.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: C.textSecondary,
        letterSpacing: 0.1,
      ),
    );
  }
}
