import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

// ApiService provider is now defined in providers/api_provider.dart

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static final _univEmailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@(?:.*\.)?kyoto-su\.ac\.jp$');
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    // ステップ2: authProviderを呼び出し、結果を受け取る
    final success = await ref
        .read(authProvider.notifier)
        .login(_emailController.text, _passwordController.text);

    // ステップ3: 成功した場合のみ画面を閉じる
    if (success) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // ステップ4: 失敗した場合はエラー表示をして画面に留まる
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メールアドレスまたはパスワードが違います')));
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ログイン')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '大学メールアドレス',
                  hintText: 'xxx@***.kyoto-su.ac.jp',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) {
                    return '大学メールアドレスを入力してください';
                  }
                  if (!_univEmailRegex.hasMatch(email)) {
                    return '大学メールアドレス(@...kyoto-su.ac.jp)のみ利用できます';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'パスワード',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed:
                        () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) =>
                    value == null || value.isEmpty ? 'パスワードを入力してください' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('ログイン'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
