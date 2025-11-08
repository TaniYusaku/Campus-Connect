import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:frontend/shared/profile_constants.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedFaculty = '未設定';
  String? _selectedGradeStr = '未設定';
  String? _selectedGender = '未設定';
  bool _isLoading = false;
  String? _errorMessage;

  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register(AuthNotifier authNotifier) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    // Validate dropdowns
    if (_selectedFaculty == null || _selectedFaculty == '未設定') {
      setState(() {
        _isLoading = false;
        _errorMessage = '学部を選択してください';
      });
      return;
    }
    if (_selectedGradeStr == null || _selectedGradeStr == '未設定') {
      setState(() {
        _isLoading = false;
        _errorMessage = '学年を選択してください';
      });
      return;
    }
    if (_selectedGender == null || _selectedGender == '未設定') {
      setState(() {
        _isLoading = false;
        _errorMessage = '性別を選択してください';
      });
      return;
    }
    int gradeInt;
    if (_selectedGradeStr == 'M1')
      gradeInt = 5;
    else if (_selectedGradeStr == 'M2')
      gradeInt = 6;
    else
      gradeInt = int.tryParse(_selectedGradeStr!) ?? 1;
    final result = await _apiService.register(
      userName: _userNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      faculty: _selectedFaculty!,
      grade: gradeInt,
      gender: _selectedGender,
    );
    setState(() {
      _isLoading = false;
    });
    if (result.success) {
      // 登録成功 → 即ログインしてホームへ
      final loggedIn = await authNotifier.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (loggedIn) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text('登録してログインしました。ホームに切り替えます...'),
          ),
        );
        // ホーム側（_HomeGate）でオンボーディングを一度だけ挟むため、ルートを初期状態に戻す
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('登録は成功しましたが、ログインに失敗しました')));
      }
    } else {
      setState(() {
        _errorMessage = result.message ?? '登録に失敗しました';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ユーザー登録')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _userNameController,
                decoration: const InputDecoration(labelText: 'ニックネーム'),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? '入力してください' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'メールアドレス'),
                keyboardType: TextInputType.emailAddress,
                validator:
                    (value) =>
                        value == null || value.isEmpty ? '入力してください' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'パスワード'),
                obscureText: true,
                validator:
                    (value) =>
                        value == null || value.length < 6
                            ? '6文字以上で入力してください'
                            : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedFaculty,
                items:
                    kFacultyOptions
                        .map(
                          (f) => DropdownMenuItem<String>(
                            value: f,
                            child: Text(f),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _selectedFaculty = v),
                validator: (v) => (v == null || v == '未設定') ? '学部は必須です' : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(labelText: '学部 (必須)'),
              ),
              DropdownButtonFormField<String>(
                value: _selectedGradeStr,
                items:
                    kGradeOptions
                        .map(
                          (g) => DropdownMenuItem<String>(
                            value: g,
                            child: Text(g),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _selectedGradeStr = v),
                validator: (v) => (v == null || v == '未設定') ? '学年は必須です' : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(labelText: '学年 (必須)'),
              ),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                items:
                    kGenderOptions
                        .map(
                          (g) => DropdownMenuItem<String>(
                            value: g,
                            child: Text(g),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _selectedGender = v),
                validator: (v) => (v == null || v == '未設定') ? '性別は必須です' : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(labelText: '性別 (必須)'),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Consumer(
                  builder: (context, ref, _) {
                    final authNotifier = ref.read(authProvider.notifier);
                    return ElevatedButton(
                      onPressed: () => _register(authNotifier),
                      child: const Text('登録する'),
                    );
                  },
                ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                child: const Text('すでにアカウントをお持ちですか？ ログイン'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
