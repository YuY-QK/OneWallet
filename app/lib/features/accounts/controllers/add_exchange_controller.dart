import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ow_domain/ow_domain.dart';

import '../../../bootstrap/providers.dart';
import 'add_exchange_state.dart';

/// 交易所的默认账户名称。
String defaultExchangeAccountName(ExchangeId exchange) => switch (exchange) {
  ExchangeId.binance => 'Binance 主账户',
  ExchangeId.okx => 'OKX 主账户',
  ExchangeId.bybit => 'Bybit 主账户',
  ExchangeId.bitget => 'Bitget 主账户',
};

/// P06 页面控制器 Provider。参数是 `accountId`：为 null 表示添加新交易所账户，
/// 非 null 表示更换已有交易所账户的 API Key。
final addExchangeControllerProvider = NotifierProvider.autoDispose
    .family<AddExchangeController, AddExchangeState, String?>(
      AddExchangeController.new,
    );

/// P06 交易所接入与凭据保存的业务控制器。
///
/// **安全红线**：
/// - 控制器内部**不得保留**任何明文 API Key、Secret、Passphrase。
/// - 敏感字符串由界面输入框在点击操作时作为参数临时传入，并立即封装为 [Sensitive]。
class AddExchangeController extends Notifier<AddExchangeState> {
  AddExchangeController(this.accountId);

  final String? accountId;

  @override
  AddExchangeState build() {
    if (accountId != null) {
      Future.microtask(_loadExisting);
      return AddExchangeState(
        accountId: accountId,
        selectedExchange: ExchangeId.binance,
      );
    }
    return AddExchangeState(
      selectedExchange: ExchangeId.binance,
      name: defaultExchangeAccountName(ExchangeId.binance),
    );
  }

  Future<void> _loadExisting() async {
    final account = await ref.read(accountRepositoryProvider).byId(accountId!);
    if (!ref.mounted) return;
    if (account != null &&
        account.type == AccountType.exchange &&
        account.exchange != null) {
      state = state.copyWith(
        existing: account,
        existingLoaded: true,
        selectedExchange: account.exchange!,
        name: account.name,
      );
    } else {
      state = state.copyWith(existing: null, existingLoaded: true);
    }
  }

  /// 切换选中的交易所（更换模式下不可切换）。
  void selectExchange(ExchangeId exchange) {
    if (state.isReplaceMode || state.isBusy) return;
    if (exchange == state.selectedExchange) return;
    final newName = state.isUserCustomizedName
        ? state.name
        : defaultExchangeAccountName(exchange);
    state = state.copyWith(
      selectedExchange: exchange,
      name: newName,
      status: AddExchangeStatus.initial,
      clearFailure: true,
      permission: null,
    );
  }

  /// 设置账户名称（仅新建模式有效）。
  void setName(String value) {
    if (state.isReplaceMode) return;
    state = state.copyWith(
      name: value,
      isUserCustomizedName: true,
      clearFailure: true,
    );
  }

  /// 用户关闭或取消权限警告弹窗（返回修改）。
  void dismissWarning() {
    state = state.copyWith(status: AddExchangeStatus.initial, permission: null);
  }

  /// 本地输入校验。
  bool validateInputs({
    required String apiKey,
    required String apiSecret,
    String? passphrase,
  }) {
    var valid = state.nameValid;
    if (apiKey.trim().isEmpty) valid = false;
    if (apiSecret.trim().isEmpty) valid = false;
    if (state.needsPassphrase &&
        (passphrase == null || passphrase.trim().isEmpty)) {
      valid = false;
    }
    if (!valid) {
      state = state.copyWith(showErrors: true);
    }
    return valid;
  }

  /// 点击「测试并保存」：校验格式、验证只读权限。
  ///
  /// - 若验证失败：将状态置为 [AddExchangeStatus.failed]，返回 null；
  /// - 若检测到权限超出只读：将状态置为 [AddExchangeStatus.permissionWarning]，返回 null（由界面弹出提示）；
  /// - 若权限正常或无需警告：直接保存并触发后台同步，成功返回账户 id。
  Future<String?> testAndSave({
    required String apiKey,
    required String apiSecret,
    String? passphrase,
  }) async {
    if (state.isBusy || state.accountMissing) return null;
    if (!state.isSupported) {
      state = state.copyWith(
        status: AddExchangeStatus.failed,
        failure: const UnsupportedFailure.notIntegrated(),
      );
      return null;
    }

    if (!validateInputs(
      apiKey: apiKey,
      apiSecret: apiSecret,
      passphrase: passphrase,
    )) {
      return null;
    }

    state = state.copyWith(
      status: AddExchangeStatus.verifying,
      clearFailure: true,
    );

    final creds = _buildCredentials(
      apiKey: apiKey,
      apiSecret: apiSecret,
      passphrase: passphrase,
    );

    final verifyRes = await ref
        .read(addExchangeAccountProvider)
        .verify(exchange: state.selectedExchange, credentials: creds);

    if (!ref.mounted) return null;

    switch (verifyRes) {
      case Err(:final failure):
        state = state.copyWith(
          status: AddExchangeStatus.failed,
          failure: failure,
        );
        return null;
      case Ok(:final value):
        if (value.permission == KeyPermission.canTrade ||
            value.permission == KeyPermission.canWithdraw) {
          state = state.copyWith(
            status: AddExchangeStatus.permissionWarning,
            permission: value.permission,
          );
          return null;
        }
        return _performSave(creds);
    }
  }

  /// 用户在权限警告弹窗中点击「仍然保存」。
  Future<String?> confirmSave({
    required String apiKey,
    required String apiSecret,
    String? passphrase,
  }) async {
    if (state.isBusy || state.accountMissing || !state.isSupported) return null;
    final creds = _buildCredentials(
      apiKey: apiKey,
      apiSecret: apiSecret,
      passphrase: passphrase,
    );
    return _performSave(creds);
  }

  ExchangeCredentials _buildCredentials({
    required String apiKey,
    required String apiSecret,
    String? passphrase,
  }) {
    return ExchangeCredentials(
      apiKey: Sensitive.fromString(apiKey.trim()),
      apiSecret: Sensitive.fromString(apiSecret.trim()),
      passphrase: (passphrase != null && passphrase.trim().isNotEmpty)
          ? Sensitive.fromString(passphrase.trim())
          : null,
    );
  }

  Future<String?> _performSave(ExchangeCredentials creds) async {
    state = state.copyWith(
      status: AddExchangeStatus.saving,
      clearFailure: true,
    );

    if (state.isReplaceMode) {
      final res = await ref.read(replaceExchangeCredentialsProvider)(
        accountId: state.accountId!,
        credentials: creds,
        verifyCredentials: false,
      );
      if (!ref.mounted) return null;
      switch (res) {
        case Err(:final failure):
          state = state.copyWith(
            status: AddExchangeStatus.failed,
            failure: failure,
          );
          return null;
        case Ok():
          final id = state.accountId!;
          unawaited(ref.read(syncAccountProvider)(id));
          state = state.copyWith(status: AddExchangeStatus.success);
          return id;
      }
    } else {
      final res = await ref.read(addExchangeAccountProvider)(
        name: state.name,
        exchange: state.selectedExchange,
        credentials: creds,
        verifyCredentials: false,
      );
      if (!ref.mounted) return null;
      switch (res) {
        case Err(:final failure):
          state = state.copyWith(
            status: AddExchangeStatus.failed,
            failure: failure,
          );
          return null;
        case Ok(:final value):
          final id = value.id;
          unawaited(ref.read(syncAccountProvider)(id));
          state = state.copyWith(status: AddExchangeStatus.success);
          return id;
      }
    }
  }
}
