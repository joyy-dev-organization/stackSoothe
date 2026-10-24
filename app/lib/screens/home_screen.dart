import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/diagnosis_result.dart';
import '../services/demo_diagnosis_service.dart';
import '../services/diagnosis_client.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _errorController = TextEditingController(
    text: '''lib/screens/profile_screen.dart:42:20: Error: Don't use 'BuildContext's across async gaps.
    Navigator.of(context).pop();
                   ^^^^^^^

The widget may have been removed from the tree before the async operation completes.''',
  );
  final TextEditingController _codeController = TextEditingController(
    text: '''Future<void> saveProfile() async {
  await repository.saveProfile();
  Navigator.of(context).pop();
}''',
  );

  bool _useLocalAi = false;
  bool _isDiagnosing = false;
  DiagnosisResult? _result;
  String? _errorMessage;
  String _serviceUrl = 'http://127.0.0.1:11435';
  String _serviceToken = '';
  String _model = 'qwen2.5-coder:3b';
  String _activeNav = 'Diagnose';

  @override
  void dispose() {
    _errorController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _runDiagnosis() async {
    if (_errorController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Paste an error log before running a diagnosis.');
      return;
    }

    setState(() {
      _isDiagnosing = true;
      _errorMessage = null;
    });

    try {
      final DiagnosisResult result;
      if (_useLocalAi) {
        result = await DiagnosisClient(
          baseUrl: _serviceUrl,
          token: _serviceToken,
          model: _model,
        ).diagnose(
          errorLog: _errorController.text,
          sourceCode: _codeController.text,
        );
      } else {
        result = await DemoDiagnosisService().diagnose(
          errorLog: _errorController.text,
          sourceCode: _codeController.text,
        );
      }

      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _cleanException(error);
        _result = null;
      });
    } finally {
      if (mounted) setState(() => _isDiagnosing = false);
    }
  }

  String _cleanException(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  void _loadExample(String key) {
    final examples = <String, ({String log, String code})>{
      'context': (
        log: '''lib/screens/profile_screen.dart:42:20: Error: Don't use 'BuildContext's across async gaps.
    Navigator.of(context).pop();
                   ^^^^^^^

The widget may have been removed from the tree before the async operation completes.''',
        code: '''Future<void> saveProfile() async {
  await repository.saveProfile();
  Navigator.of(context).pop();
}''',
      ),
      'null': (
        log: '''Null check operator used on a null value
#0      ProfileHeader.build (package:demo/widgets/profile_header.dart:28:31)
#1      StatelessElement.build (package:flutter/src/widgets/framework.dart:...)''',
        code: '''Widget build(BuildContext context) {
  final displayName = user!.displayName;
  return Text(displayName);
}''',
      ),
      'overflow': (
        log: '''A RenderFlex overflowed by 36 pixels on the right.
The relevant error-causing widget was:
  Row Row:file:///lib/screens/dashboard.dart:84:16''',
        code: '''Row(
  children: [
    const Icon(Icons.account_circle),
    Text(user.displayName),
    Text(user.email),
  ],
)''',
      ),
      'firebase': (
        log: '''FirebaseException ([core/not-initialized] Firebase has not been correctly initialized. Ensure Firebase.initializeApp is completed.)
PlatformException: CONFIGURATION_NOT_FOUND''',
        code: '''void main() {
  runApp(const MyApp());
}''',
      ),
    };
    final example = examples[key];
    if (example == null) return;
    setState(() {
      _errorController.text = example.log;
      _codeController.text = example.code;
      _result = null;
      _errorMessage = null;
    });
  }

  void _clearInputs() {
    setState(() {
      _errorController.clear();
      _codeController.clear();
      _result = null;
      _errorMessage = null;
    });
  }

  Future<void> _copyResult() async {
    final result = _result;
    if (result == null) return;
    await Clipboard.setData(ClipboardData(text: result.toPlainText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Diagnosis copied to clipboard'),
        backgroundColor: AppColors.surfaceRaised,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openSettings() async {
    final serviceUrlController = TextEditingController(text: _serviceUrl);
    final tokenController = TextEditingController(text: _serviceToken);
    final modelController = TextEditingController(text: _model);
    String? connectionMessage;
    bool testing = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          title: const Text('Local diagnosis service settings'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'StackSoothe routes prompts to your local loopback Node.js service (127.0.0.1) which connects to local Ollama.',
                  style: TextStyle(color: AppColors.muted, height: 1.5),
                ),
                const SizedBox(height: 20),
                const Text('SERVICE URL (LOOPBACK)', style: _eyebrowStyle),
                const SizedBox(height: 8),
                TextField(
                  controller: serviceUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'http://127.0.0.1:11435',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('BEARER TOKEN (OPTIONAL)', style: _eyebrowStyle),
                const SizedBox(height: 8),
                TextField(
                  controller: tokenController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Configured in .stacksoothe-token',
                    prefixIcon: Icon(Icons.key_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('MODEL TAG', style: _eyebrowStyle),
                const SizedBox(height: 8),
                TextField(
                  controller: modelController,
                  decoration: const InputDecoration(
                    hintText: 'qwen2.5-coder:3b',
                    prefixIcon: Icon(Icons.memory_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                if (connectionMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.input,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      connectionMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: connectionMessage!.startsWith('Connected')
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: testing
                        ? null
                        : () async {
                            if (serviceUrlController.text.trim().isEmpty ||
                                modelController.text.trim().isEmpty) {
                              setDialogState(() => connectionMessage =
                                  'Enter both a service URL and a model tag first.');
                              return;
                            }
                            setDialogState(() {
                              testing = true;
                              connectionMessage = null;
                            });
                            try {
                              final status = await DiagnosisClient(
                                baseUrl: serviceUrlController.text,
                                token: tokenController.text.trim(),
                                model: modelController.text.trim(),
                              ).testConnection();
                              if (!dialogContext.mounted) return;
                              setDialogState(() => connectionMessage = status);
                            } catch (error) {
                              if (!dialogContext.mounted) return;
                              setDialogState(() => connectionMessage =
                                  _cleanException(error));
                            } finally {
                              if (dialogContext.mounted) {
                                setDialogState(() => testing = false);
                              }
                            }
                          },
                    icon: testing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cable_rounded, size: 16),
                    label: Text(testing ? 'Testing connection…' : 'Test connection'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (serviceUrlController.text.trim().isEmpty ||
                    modelController.text.trim().isEmpty) {
                  setDialogState(() => connectionMessage =
                      'Enter both a service URL and a model tag before saving.');
                  return;
                }
                setState(() {
                  _serviceUrl = serviceUrlController.text.trim();
                  _serviceToken = tokenController.text.trim();
                  _model = modelController.text.trim();
                });
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save settings'),
            ),
          ],
        ),
      ),
    );

    serviceUrlController.dispose();
    tokenController.dispose();
    modelController.dispose();
  }

  void _showHowItWorks() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('How StackSoothe works'),
        content: const SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExplainerRow(
                number: '01',
                title: 'Bring the error',
                body: 'Paste the complete log and any relevant Dart code.',
              ),
              SizedBox(height: 18),
              _ExplainerRow(
                number: '02',
                title: 'Diagnose locally',
                body: 'Use demo rules to explore the UI, or connect Ollama for actual local model inference.',
              ),
              SizedBox(height: 18),
              _ExplainerRow(
                number: '03',
                title: 'Verify the fix',
                body: 'Use the suggested steps as guidance, then run your own analyzer or tests. StackSoothe never executes code.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showSidebar = constraints.maxWidth >= 980;
          return Row(
            children: [
              if (showSidebar) _buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(showSidebar),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, contentConstraints) => SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: contentConstraints.maxWidth < 700 ? 18 : 32,
                            vertical: 28,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1160),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildPageHeading(),
                                  const SizedBox(height: 24),
                                  _buildModeCard(),
                                  const SizedBox(height: 20),
                                  _buildInputArea(),
                                  const SizedBox(height: 14),
                                  _buildExamples(),
                                  const SizedBox(height: 22),
                                  _buildActionRow(),
                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 16),
                                    _buildErrorBanner(_errorMessage!),
                                  ],
                                  const SizedBox(height: 30),
                                  if (_isDiagnosing) _buildLoadingState(),
                                  if (!_isDiagnosing && _result != null)
                                    _buildResult(_result!),
                                  if (!_isDiagnosing && _result == null && _errorMessage == null)
                                    _buildEmptyResults(),
                                  const SizedBox(height: 24),
                                  _buildFooterNote(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 224,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(21, 25, 16, 32),
            child: _buildBrand(compact: false),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 16, 10),
            child: Text('WORKSPACE', style: _eyebrowStyle),
          ),
          _sidebarItem(
            icon: Icons.bug_report_outlined,
            label: 'Diagnose',
            selected: _activeNav == 'Diagnose',
            onTap: () => setState(() => _activeNav = 'Diagnose'),
          ),
          _sidebarItem(
            icon: Icons.route_outlined,
            label: 'How it works',
            selected: false,
            onTap: _showHowItWorks,
          ),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 17, color: AppColors.success),
                    SizedBox(width: 7),
                    Text('LOCAL-FIRST', style: TextStyle(fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: AppColors.success)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Your code stays on your machine when you use a local model.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.5),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(21, 0, 16, 18),
            child: Text('STACKSOOTHE  ·  v0.1.0', style: TextStyle(color: AppColors.subtle, fontSize: 10, letterSpacing: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildBrand({required bool compact}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accent, Color(0xFF6D5DE7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.terminal_rounded, color: Color(0xFF110D26), size: 22),
        ),
        if (!compact) ...[
          const SizedBox(width: 10),
          const Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('StackSoothe', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.5), overflow: TextOverflow.ellipsis),
                SizedBox(height: 2),
                Text('DEBUG WITH LESS FRICTION', style: TextStyle(fontSize: 8, letterSpacing: 1.05, color: AppColors.muted, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _sidebarItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? const Color(0x1F9A8CFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: selected ? const Color(0x559A8CFF) : Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: selected ? AppColors.accent : AppColors.muted),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? AppColors.text : AppColors.muted,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool showSidebar) {
    return Container(
      height: 76,
      padding: EdgeInsets.symmetric(horizontal: showSidebar ? 30 : 18),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (!showSidebar) ...[
            _buildBrand(compact: true),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.subtle),
            const SizedBox(width: 3),
          ],
          if (showSidebar) ...[
            const Icon(Icons.grid_view_rounded, size: 16, color: AppColors.muted),
            const SizedBox(width: 10),
            const Text('Workspace', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(width: 9),
            const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.subtle),
            const SizedBox(width: 5),
          ],
          const Text('Diagnose', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          _statusPill(
            icon: _useLocalAi ? Icons.memory_rounded : Icons.science_outlined,
            label: _useLocalAi ? 'LOCAL MODEL' : 'SAMPLE MODE',
            color: _useLocalAi ? AppColors.cyan : AppColors.accent,
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Local model settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded, size: 19),
            style: IconButton.styleFrom(
              foregroundColor: AppColors.muted,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('FLUTTER / DEBUGGING WORKSPACE', style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Let’s untangle that error.',
          style: TextStyle(fontSize: 31, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: -1.1),
        ),
        const SizedBox(height: 10),
        const Text(
          'Less staring at stack traces. More time building things that work.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildModeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final options = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _modeChip(
                selected: !_useLocalAi,
                icon: Icons.science_outlined,
                label: 'Demo mode',
                onTap: () => setState(() => _useLocalAi = false),
              ),
              _modeChip(
                selected: _useLocalAi,
                icon: Icons.memory_rounded,
                label: 'Local AI',
                onTap: () => setState(() => _useLocalAi = true),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DIAGNOSIS ENGINE', style: _eyebrowStyle),
                const SizedBox(height: 10),
                options,
                const SizedBox(height: 10),
                Text(
                  _useLocalAi
                      ? 'Local service · $_model · Prompts are routed to loopback service.'
                      : 'Instant sample diagnoses · No model setup required.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11, height: 1.5),
                ),
              ],
            );
          }
          return Row(
            children: [
              const Icon(Icons.tune_rounded, size: 19, color: AppColors.muted),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DIAGNOSIS ENGINE', style: _eyebrowStyle),
                    SizedBox(height: 5),
                    Text('Choose how StackSoothe analyzes your input.', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              options,
            ],
          );
        },
      ),
    );
  }

  Widget _modeChip({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0x269A8CFF) : AppColors.input,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: selected ? AppColors.accent : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? AppColors.accent : AppColors.muted),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? AppColors.text : AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final logCard = _inputCard(
          icon: Icons.terminal_rounded,
          title: 'ERROR LOG',
          badge: 'REQUIRED',
          child: _errorControllerField(),
          helper: 'Paste the complete error or analyzer output.',
        );
        final codeCard = _inputCard(
          icon: Icons.code_rounded,
          title: 'SOURCE CONTEXT',
          badge: 'OPTIONAL',
          child: _codeControllerField(),
          helper: 'Add the relevant widget or function for better context.',
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: logCard),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: codeCard),
            ],
          );
        }
        return Column(
          children: [logCard, const SizedBox(height: 14), codeCard],
        );
      },
    );
  }

  Widget _inputCard({
    required IconData icon,
    required String title,
    required String badge,
    required Widget child,
    required String helper,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 10, letterSpacing: 1.05, fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(badge, style: const TextStyle(fontSize: 8, color: AppColors.muted, letterSpacing: 0.6, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.subtle),
              const SizedBox(width: 6),
              Expanded(child: Text(helper, style: const TextStyle(color: AppColors.subtle, fontSize: 10, height: 1.35))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorControllerField() {
    return SizedBox(
      height: 190,
      child: TextField(
        controller: _errorController,
        expands: true,
        minLines: null,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, height: 1.55, color: Color(0xFFD5DDED)),
        decoration: const InputDecoration(
          hintText: 'Paste your Flutter error here…',
          contentPadding: EdgeInsets.all(13),
          filled: true,
          fillColor: AppColors.input,
        ),
      ),
    );
  }

  Widget _codeControllerField() {
    return SizedBox(
      height: 190,
      child: TextField(
        controller: _codeController,
        expands: true,
        minLines: null,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, height: 1.55, color: Color(0xFFB6C6DD)),
        decoration: const InputDecoration(
          hintText: 'Paste the relevant Dart code…',
          contentPadding: EdgeInsets.all(13),
          filled: true,
          fillColor: AppColors.input,
        ),
      ),
    );
  }

  Widget _buildExamples() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 7,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 2),
          child: Text('TRY AN EXAMPLE', style: TextStyle(color: AppColors.subtle, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
        ),
        _exampleChip('BuildContext async gap', 'context'),
        _exampleChip('Null check operator', 'null'),
        _exampleChip('RenderFlex overflow', 'overflow'),
        _exampleChip('Firebase setup', 'firebase'),
      ],
    );
  }

  Widget _exampleChip(String label, String key) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _loadExample(key),
      avatar: const Icon(Icons.bolt_rounded, size: 13, color: AppColors.accent),
      visualDensity: VisualDensity.compact,
      side: const BorderSide(color: AppColors.border),
      backgroundColor: AppColors.surface,
    );
  }

  Widget _buildActionRow() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 14,
      runSpacing: 12,
      children: [
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.success),
            SizedBox(width: 7),
            Text('No cloud API · No code execution', style: TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: _clearInputs,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Clear'),
            ),
            const SizedBox(width: 9),
            FilledButton.icon(
              onPressed: _isDiagnosing ? null : _runDiagnosis,
              icon: _isDiagnosing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF100D22)))
                  : const Icon(Icons.auto_awesome_rounded, size: 17),
              label: Text(_isDiagnosing ? 'Analyzing…' : 'Diagnose error'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0x22FF777F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x66FF777F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Color(0xFFFFC9CB), fontSize: 12, height: 1.45))),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent)),
          const SizedBox(height: 14),
          Text(_useLocalAi ? 'Asking $_model to inspect the error…' : 'Inspecting the error pattern…', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          const Text('Looking for a likely cause and practical next steps.', style: TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 18),
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(99)),
            child: LinearProgressIndicator(minHeight: 3, backgroundColor: AppColors.border, color: AppColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResults() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 23),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(color: const Color(0x229A8CFF), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.query_stats_rounded, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your diagnosis will appear here', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                SizedBox(height: 5),
                Text('Run the preloaded example, or paste an error from your own Flutter project.', style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.45)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_downward_rounded, color: AppColors.subtle, size: 18),
        ],
      ),
    );
  }

  Widget _buildResult(DiagnosisResult result) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: const Color(0x229A8CFF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DIAGNOSIS REPORT', style: TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.15)),
                      const SizedBox(height: 4),
                      Text(result.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.3)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _severityBadge(result.severity),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Copy diagnosis',
                  onPressed: _copyResult,
                  icon: const Icon(Icons.content_copy_rounded, size: 17),
                  style: IconButton.styleFrom(foregroundColor: AppColors.muted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.input,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeading(icon: Icons.subject_rounded, title: 'IN PLAIN ENGLISH'),
                      const SizedBox(height: 10),
                      Text(result.summary, style: const TextStyle(color: Color(0xFFD0DAE8), fontSize: 12, height: 1.65)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const _SectionHeading(icon: Icons.manage_search_rounded, title: 'LIKELY CAUSE'),
                const SizedBox(height: 9),
                Text(result.likelyCause, style: const TextStyle(color: Color(0xFFD0DAE8), fontSize: 12, height: 1.65)),
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Icon(Icons.insights_rounded, size: 14, color: AppColors.cyan),
                    const SizedBox(width: 6),
                    Text('Confidence: ${result.confidence}', style: const TextStyle(color: AppColors.cyan, fontSize: 10, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(result.isDemo ? 'RULE-BASED EXAMPLE' : 'MODEL: ${result.modelName.toUpperCase()}', style: const TextStyle(color: AppColors.subtle, fontSize: 9, letterSpacing: 0.6, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 22),
                const _SectionHeading(icon: Icons.route_rounded, title: 'SUGGESTED DEBUGGING STEPS'),
                const SizedBox(height: 12),
                ...List.generate(result.steps.length, (index) => _numberedStep(index + 1, result.steps[index])),
                const SizedBox(height: 14),
                const _SectionHeading(icon: Icons.fact_check_outlined, title: 'VERIFY THE FIX'),
                const SizedBox(height: 11),
                ...result.verification.map(_verificationItem),
                if (result.codeExample.trim().isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(child: _SectionHeading(icon: Icons.code_rounded, title: 'EXAMPLE APPROACH')),
                      IconButton(
                        tooltip: 'Copy example',
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: result.codeExample));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Code example copied'), behavior: SnackBarBehavior.floating),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1017),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SelectableText(
                      result.codeExample,
                      style: const TextStyle(fontFamily: 'Consolas', color: Color(0xFFBEE9D8), fontSize: 11, height: 1.6),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0x22FFC477),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x44FFC477)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: AppColors.warning, size: 16),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Treat this as a debugging lead, not proof. Review the suggested change and run your own analyzer or tests before accepting a fix.',
                          style: TextStyle(color: Color(0xFFE7D5B7), fontSize: 10, height: 1.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _severityBadge(String severity) {
    final normalized = severity.toLowerCase();
    final Color color;
    switch (normalized) {
      case 'high':
        color = AppColors.danger;
        break;
      case 'low':
        color = AppColors.success;
        break;
      default:
        color = AppColors.warning;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        normalized.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Widget _numberedStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x229A8CFF),
              border: Border.all(color: const Color(0x559A8CFF)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$number', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 10)),
          ),
          const SizedBox(width: 11),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: Text(text, style: const TextStyle(color: Color(0xFFD0DAE8), fontSize: 12, height: 1.55)))),
        ],
      ),
    );
  }

  Widget _verificationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_outline_rounded, size: 15, color: AppColors.success),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFD0DAE8), fontSize: 11, height: 1.55))),
        ],
      ),
    );
  }

  Widget _buildFooterNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.subtle),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'StackSoothe is an early prototype. Demo mode uses built-in rules; Local AI mode requires Ollama and a downloaded model. Your diagnosis is guidance, not a guarantee.',
            style: TextStyle(color: AppColors.subtle, fontSize: 10, height: 1.55),
          ),
        ),
        const SizedBox(width: 15),
        TextButton.icon(
          onPressed: _showHowItWorks,
          icon: const Icon(Icons.help_outline_rounded, size: 14),
          label: const Text('How it works', style: TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  Widget _statusPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.65)),
        ],
      ),
    );
  }

  static const TextStyle _eyebrowStyle = TextStyle(
    color: AppColors.muted,
    fontSize: 9,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.05,
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
      ],
    );
  }
}

class _ExplainerRow extends StatelessWidget {
  const _ExplainerRow({required this.number, required this.title, required this.body});

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0x229A8CFF), borderRadius: BorderRadius.circular(9)),
          child: Text(number, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 10)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(body, style: const TextStyle(color: AppColors.muted, fontSize: 11, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
