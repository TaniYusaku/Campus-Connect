import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/api_provider.dart';
import 'package:frontend/providers/profile_provider.dart';
import 'package:frontend/providers/public_profile_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:frontend/shared/profile_constants.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _bioCtl = TextEditingController();
  final _xCtl = TextEditingController();
  final _igCtl = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  bool _uploading = false;

  // Options moved to shared/profile_constants.dart

  // State for dropdowns
  String? _selectedFaculty;
  String? _selectedGradeStr; // '未設定','1'..,'M1','M2'
  String? _selectedGender;
  String? _selectedBioTemplate;

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      final api = ref.read(apiServiceProvider);
      // Read original bytes
      final origBytes = await picked.readAsBytes();
      // Decode and re-encode as JPEG with quality 85 to avoid PNG compression warning and reduce size
      final decoded = img.decodeImage(origBytes);
      if (decoded == null) throw Exception('画像のデコードに失敗しました');
      final encodedJpg = img.encodeJpg(decoded, quality: 85);
      const contentType = 'image/jpeg';
      final info = await api.requestProfilePhotoUploadUrl(
        contentType: contentType,
      );
      if (info == null) throw Exception('Failed to get upload url');
      final putResp = await http.put(
        Uri.parse(info.uploadUrl),
        headers: {
          'Content-Type': contentType,
          'Content-Length': encodedJpg.length.toString(),
        },
        body: encodedJpg,
      );
      if (putResp.statusCode >= 200 && putResp.statusCode < 300) {
        final updated = await api.confirmProfilePhoto(
          objectPath: info.objectPath,
        );
        if (updated != null) {
          _initialized = false; // reload fields from server value
          ref.invalidate(profileProvider);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('プロフィール写真を更新しました')));
          }
        } else {
          throw Exception('Failed to confirm upload');
        }
      } else {
        final bodyText = putResp.body.isNotEmpty ? putResp.body : '(no body)';
        throw Exception(
          'Upload failed: ${putResp.statusCode} ${putResp.reasonPhrase} | $bodyText',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('アップロードに失敗しました: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _bioCtl.dispose();
    _xCtl.dispose();
    _igCtl.dispose();
    super.dispose();
  }

  void _initFields(User u) {
    if (_initialized) return;
    _nameCtl.text = u.username;
    _selectedFaculty =
        (u.faculty != null && kFacultyOptions.contains(u.faculty))
            ? u.faculty
            : '未設定';
    if (u.grade != null) {
      if (u.grade! >= 1 && u.grade! <= 4) {
        _selectedGradeStr = u.grade!.toString();
      } else if (u.grade == 5) {
        _selectedGradeStr = 'M1';
      } else if (u.grade == 6) {
        _selectedGradeStr = 'M2';
      } else {
        _selectedGradeStr = '未設定';
      }
    } else {
      _selectedGradeStr = '未設定';
    }
    _bioCtl.text = u.bio ?? '';
    _xCtl.text = u.snsLinks?['x'] ?? '';
    _igCtl.text = u.snsLinks?['instagram'] ?? '';
    _selectedGender =
        (u.gender != null && kGenderOptions.contains(u.gender))
            ? u.gender
            : '未設定';
    _initialized = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = ref.read(apiServiceProvider);
    final sns = <String, String>{};
    final xHandle = _xCtl.text.trim();
    final igHandle = _igCtl.text.trim();
    if (xHandle.isNotEmpty) sns['x'] = xHandle;
    if (igHandle.isNotEmpty) sns['instagram'] = igHandle;
    int? gradeInt;
    if (_selectedGradeStr != null && _selectedGradeStr != '未設定') {
      if (_selectedGradeStr == 'M1')
        gradeInt = 5;
      else if (_selectedGradeStr == 'M2')
        gradeInt = 6;
      else
        gradeInt = int.tryParse(_selectedGradeStr!);
    }
    final gender =
        (_selectedGender == null || _selectedGender == '未設定')
            ? null
            : _selectedGender;
    final updated = await api.updateMe(
      userName: _nameCtl.text.trim(),
      faculty: _selectedFaculty == '未設定' ? null : _selectedFaculty,
      grade: gradeInt,
      bio: _bioCtl.text.trim(),
      snsLinks: sns,
      gender:
          gender,
    );
    setState(() => _saving = false);
    if (!mounted) return;
    if (updated != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('プロフィールを更新しました')));
      ref.invalidate(profileProvider);
      ref.invalidate(publicProfileProvider('me'));
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('更新に失敗しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィールを編集'),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 200),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('読み込みエラー: $e'),
            ),
          ],
        ),
        data: (user) {
          if (user == null) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 200),
                Center(child: Text('ユーザー情報が取得できませんでした')),
              ],
            );
          }
          _initFields(user);
          // Pull-to-refresh to reload latest profile
          return RefreshIndicator(
            onRefresh: () async {
              _initialized = false;
              ref.invalidate(profileProvider);
              await ref.read(profileProvider.future);
            },
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundImage:
                                    (user.profilePhotoUrl != null &&
                                            user.profilePhotoUrl!.isNotEmpty)
                                        ? NetworkImage(user.profilePhotoUrl!)
                                        : null,
                                child:
                                    (user.profilePhotoUrl == null ||
                                            user.profilePhotoUrl!.isEmpty)
                                        ? const Icon(Icons.person, size: 36)
                                        : null,
                              ),
                              IconButton(
                                onPressed:
                                    _uploading ? null : _pickAndUploadPhoto,
                                icon: const Icon(Icons.camera_alt, size: 20),
                                tooltip: '写真を変更',
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _nameCtl,
                              decoration: const InputDecoration(
                                labelText: 'ニックネーム',
                              ),
                              validator:
                                  (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? '必須です'
                                          : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedFaculty ?? '未設定',
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
                        validator: (v) {
                          if (v == null || v == '未設定') return '学部は必須です';
                          return null;
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(labelText: '学部 (必須)'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedGradeStr ?? '未設定',
                        items:
                            kGradeOptions
                                .map(
                                  (s) => DropdownMenuItem<String>(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => _selectedGradeStr = v),
                        validator:
                            (v) => (v == null || v == '未設定') ? '学年は必須です' : null,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(labelText: '学年 (必須)'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedGender ?? '未設定',
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
                        validator:
                            (v) =>
                                (v == null || v.isEmpty || v == '未設定')
                                    ? '性別は必須です'
                                    : null,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(labelText: '性別 (必須)'),
                      ),
                      DropdownButtonFormField<String>(
                        value: _selectedBioTemplate,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('テンプレートを選択しない'),
                          ),
                          ...kBioTemplates.map(
                            (s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(s),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedBioTemplate = v);
                          if (v != null) {
                            _bioCtl.text = v;
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: '自己紹介テンプレート',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bioCtl,
                        decoration: const InputDecoration(labelText: '自己紹介'),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      const Text('SNS(任意)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _xCtl,
                        decoration: const InputDecoration(
                          labelText: 'X (旧Twitter) ID',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _igCtl,
                        decoration: const InputDecoration(
                          labelText: 'Instagram ID',
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('保存'),
                          onPressed: _saving ? null : _save,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_saving || _uploading)
                Container(
                  color: Colors.black45,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    ),
  );
  }
}
