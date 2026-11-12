import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// 进入应用之前先把数据库里已存的价格源币种读入内存币种目录。
///
/// `AssetCatalog` 的方法是同步的，目录必须在第一次同步前加载完；读取只是两次本地查询，
/// 通常不会被察觉。读取失败（数据库故障，属于程序缺陷）时记录日志并照常进入：
/// 目录退化为只含内置表，已存的币种在下次启动重新加载。
class AssetCatalogGate extends ConsumerStatefulWidget {
  const AssetCatalogGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AssetCatalogGate> createState() => _AssetCatalogGateState();
}

class _AssetCatalogGateState extends ConsumerState<AssetCatalogGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await ref.read(assetCatalogProvider).load();
    } on Object catch (e) {
      ref.read(loggerProvider).error('boot', '币种目录加载失败：${e.runtimeType}');
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? widget.child : const SizedBox.shrink();
}
