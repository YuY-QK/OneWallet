import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../l10n/app_localizations.dart';
import '../theme/ow_theme.dart';
import '../widgets/empty_state.dart';
import 'app_bootstrap.dart';
import 'asset_catalog_gate.dart';
import 'providers.dart';

/// 启动流程的宿主：先跑 [bootstrap]，成功后进入应用，失败显示错误页。
///
/// 启动流程用参数传入，测试中换成假的安全存储与内存数据库。
class BootstrapHost extends StatefulWidget {
  const BootstrapHost({super.key, required this.bootstrap});

  final Future<BootstrapResult> Function() bootstrap;

  @override
  State<BootstrapHost> createState() => _BootstrapHostState();
}

class _BootstrapHostState extends State<BootstrapHost> {
  late Future<BootstrapResult> _future = widget.bootstrap();
  BootstrapSuccess? _opened;

  @override
  void dispose() {
    // 已打开的数据库随宿主一起关闭（后台 isolate 随之结束）。
    final opened = _opened;
    if (opened != null) unawaited(opened.database.close());
    super.dispose();
  }

  void _retry() {
    setState(() {
      _future = widget.bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BootstrapResult>(
      future: _future,
      builder: (context, snapshot) {
        final result = snapshot.data;
        switch (result) {
          case BootstrapSuccess():
            _opened = result;
            return ProviderScope(
              // 键换了才会重建整棵 Provider 树；重试成功后需要用新的数据库。
              key: ObjectKey(result),
              overrides: [
                databaseProvider.overrideWithValue(result.database),
                secretStoreProvider.overrideWithValue(result.secrets),
              ],
              child: const AssetCatalogGate(child: OneWalletApp()),
            );
          case BootstrapFailure(:final kind):
            return _BootstrapShell(
              child: _BootstrapErrorPage(kind: kind, onRetry: _retry),
            );
          case null:
            return const _BootstrapShell(child: _BootstrapLoading());
        }
      },
    );
  }
}

/// 启动阶段还没有路由与设置，只用系统亮暗模式。
class _BootstrapShell extends StatelessWidget {
  const _BootstrapShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: buildOwTheme(Brightness.light),
      darkTheme: buildOwTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }
}

class _BootstrapLoading extends StatelessWidget {
  const _BootstrapLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        semanticsLabel: AppLocalizations.of(context)!.bootstrapLoading,
      ),
    );
  }
}

class _BootstrapErrorPage extends StatelessWidget {
  const _BootstrapErrorPage({required this.kind, required this.onRetry});

  final BootstrapFailureKind kind;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyState(
      icon: Icons.error_outline,
      title: l10n.bootstrapErrorTitle,
      body: switch (kind) {
        BootstrapFailureKind.secureStorageFailed =>
          l10n.bootstrapErrorSecureStorage,
        BootstrapFailureKind.databaseKeyMissing =>
          l10n.bootstrapErrorKeyMissing,
        BootstrapFailureKind.databaseOpenFailed =>
          l10n.bootstrapErrorOpenFailed,
      },
      actionLabel: l10n.bootstrapRetry,
      onAction: onRetry,
    );
  }
}
