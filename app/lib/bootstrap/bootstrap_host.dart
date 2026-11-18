import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_application/ow_application.dart';

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
  const BootstrapHost({
    super.key,
    required this.bootstrap,
    this.wipeAllData,
    this.onWipeAndRestart,
  });

  final Future<BootstrapResult> Function() bootstrap;
  final WipeAllData? wipeAllData;
  final Future<void> Function()? onWipeAndRestart;

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

  Future<void> _wipeAndRestart() async {
    final opened = _opened;
    final closer = opened?.database;
    if (opened != null) {
      _opened = null;
    }
    final wipeAll = widget.wipeAllData;
    if (wipeAll != null) {
      await wipeAll(closer: closer);
    } else {
      final onWipe = widget.onWipeAndRestart;
      if (onWipe != null) {
        if (closer != null) unawaited(closer.close());
        await onWipe();
      }
    }
    _retry();
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
                wipeAndRestartProvider.overrideWithValue(_wipeAndRestart),
              ],
              child: const AssetCatalogGate(child: OneWalletApp()),
            );
          case BootstrapFailure(:final kind):
            return _BootstrapShell(
              child: _BootstrapErrorPage(
                kind: kind,
                onRetry: _retry,
                onWipeAndRestart:
                    (widget.wipeAllData != null ||
                        widget.onWipeAndRestart != null)
                    ? _wipeAndRestart
                    : null,
              ),
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
  const _BootstrapErrorPage({
    required this.kind,
    required this.onRetry,
    this.onWipeAndRestart,
  });

  final BootstrapFailureKind kind;
  final VoidCallback onRetry;
  final Future<void> Function()? onWipeAndRestart;

  Future<void> _confirmWipe(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.bootstrapWipeConfirmTitle),
        content: Text(l10n.bootstrapWipeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.bootstrapWipeConfirmAction,
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && onWipeAndRestart != null) {
      await onWipeAndRestart!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showWipe =
        onWipeAndRestart != null &&
        (kind == BootstrapFailureKind.databaseKeyMissing ||
            kind == BootstrapFailureKind.databaseOpenFailed);

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
      secondaryActionLabel: showWipe ? l10n.bootstrapWipeAndRestart : null,
      onSecondaryAction: showWipe ? () => _confirmWipe(context) : null,
    );
  }
}
