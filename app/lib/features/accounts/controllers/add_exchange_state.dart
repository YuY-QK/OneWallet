import 'package:ow_application/ow_application.dart';
import 'package:ow_domain/ow_domain.dart';

/// P06 页面状态阶段。
enum AddExchangeStatus {
  /// 初始等待用户输入
  initial,

  /// 正在向交易所验证凭据与权限
  verifying,

  /// 验证成功但检测到权限超出只读（提示用户）
  permissionWarning,

  /// 正在将凭据与账户保存到系统存储
  saving,

  /// 保存成功
  success,

  /// 验证或保存失败
  failed,
}

/// P06 交易所添加 / 更换凭据页面的状态。
///
/// **安全红线**：本状态对象**绝对严禁**包含任何 API Key、Secret、Passphrase
/// 或任何敏感字节。输入内容仅在点击保存时从临时输入框读取，保存后立即清空。
final class AddExchangeState {
  const AddExchangeState({
    this.accountId,
    this.existing,
    this.existingLoaded = false,
    this.selectedExchange = ExchangeId.binance,
    this.name = '',
    this.isUserCustomizedName = false,
    this.status = AddExchangeStatus.initial,
    this.permission,
    this.failure,
    this.showErrors = false,
  });

  /// 若为更换 Key 模式，则为待更换凭据的账户 id；为 null 时表示新建账户。
  final String? accountId;

  /// 更换模式下从数据库读出的现有账户。
  final Account? existing;

  /// 现有账户是否已加载完成。
  final bool existingLoaded;

  /// 当前选中的交易所。
  final ExchangeId selectedExchange;

  /// 账户名称（仅新建模式可编辑）。
  final String name;

  /// 用户是否曾手动修改过账户名称。
  final bool isUserCustomizedName;

  /// 当前所处的页面流程状态。
  final AddExchangeStatus status;

  /// 验证时检测到的权限（用于权限警告弹窗展示）。
  final KeyPermission? permission;

  /// 失败原因（若有）。
  final Failure? failure;

  /// 是否展示输入框校验错误提示。
  final bool showErrors;

  /// 是否为更换 Key 模式。
  bool get isReplaceMode => accountId != null;

  /// 是否找不到指定的现有账户。
  bool get accountMissing =>
      isReplaceMode && existingLoaded && existing == null;

  /// 账户名是否有效。更换模式下名称只读，恒为 true。
  bool get nameValid =>
      isReplaceMode ||
      (name.trim().isNotEmpty &&
          name.trim().runes.length <= maxAccountNameLength);

  /// 选中的交易所是否已在本应用接入（Bitget 暂未接入）。
  bool get isSupported => selectedExchange != ExchangeId.bitget;

  /// 选中的交易所是否需要 Passphrase。
  bool get needsPassphrase =>
      selectedExchange == ExchangeId.okx ||
      selectedExchange == ExchangeId.bitget;

  /// 是否正在进行异步处理。
  bool get isBusy =>
      status == AddExchangeStatus.verifying ||
      status == AddExchangeStatus.saving;

  AddExchangeState copyWith({
    String? accountId,
    Account? existing,
    bool? existingLoaded,
    ExchangeId? selectedExchange,
    String? name,
    bool? isUserCustomizedName,
    AddExchangeStatus? status,
    KeyPermission? permission,
    Failure? failure,
    bool clearFailure = false,
    bool? showErrors,
  }) {
    return AddExchangeState(
      accountId: accountId ?? this.accountId,
      existing: existing ?? this.existing,
      existingLoaded: existingLoaded ?? this.existingLoaded,
      selectedExchange: selectedExchange ?? this.selectedExchange,
      name: name ?? this.name,
      isUserCustomizedName: isUserCustomizedName ?? this.isUserCustomizedName,
      status: status ?? this.status,
      permission: permission ?? this.permission,
      failure: clearFailure ? null : (failure ?? this.failure),
      showErrors: showErrors ?? this.showErrors,
    );
  }
}
