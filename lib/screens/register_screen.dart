import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
  final _facultyController = TextEditingController();
  final _gradeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _facultyController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final success = await _apiService.register(
      userName: _userNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      faculty: _facultyController.text.trim(),
      grade: int.tryParse(_gradeController.text.trim()) ?? 1,
    );
    setState(() {
      _isLoading = false;
    });
    if (success) {
      // TODO: ホーム画面やログイン画面への遷移処理を追加
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登録に成功しました')),
      );
    } else {
      setState(() {
        _errorMessage = '登録に失敗しました。メールアドレスの重複やネットワークエラーの可能性があります。';
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
                validator: (value) => value == null || value.isEmpty ? '入力してください' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'メールアドレス'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value == null || value.isEmpty ? '入力してください' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'パスワード'),
                obscureText: true,
                validator: (value) => value == null || value.length < 6 ? '6文字以上で入力してください' : null,
              ),
              TextFormField(
                controller: _facultyController,
                decoration: const InputDecoration(labelText: '学部'),
                validator: (value) => value == null || value.isEmpty ? '入力してください' : null,
              ),
              TextFormField(
                controller: _gradeController,
                decoration: const InputDecoration(labelText: '学年'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final num = int.tryParse(value ?? '');
                  if (num == null || num < 1) return '正しい学年を入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: _register,
                  child: const Text('登録する'),
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