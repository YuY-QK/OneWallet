import 'package:drift/drift.dart';
import 'package:ow_domain/ow_domain.dart';

import '../database/ow_database.dart';
import 'codec.dart';

const _locationOnChain = 'onchain';
const _locationExchange = 'exchange';
const _tokenNative = 'native';
const _tokenContract = 'contract';
const _tokenExchange = 'exchange';

/// 持仓行 → 领域对象。
///
/// 位置与代币按规格第 5 节的列还原；链 id、交易所、子账户名未知或必需列为空时
/// 抛出 [RowDecodeException]。
Holding holdingFromRow(HoldingRow row) {
  final HoldingLocation location;
  switch (row.locationKind) {
    case _locationOnChain:
      location = OnChainLocation(
        chainId: checkChainId(row.chainId),
        addressId: requireValue(row.addressId, 'address_id'),
      );
    case _locationExchange:
      location = ExchangeLocation(
        decodeEnum(
          ExchangeSubAccount.values,
          requireValue(row.exchangeSub, 'exchange_sub'),
          '交易所子账户',
        ),
      );
    default:
      throw RowDecodeException('未知的持仓位置：${row.locationKind}');
  }

  final TokenRef token;
  switch (row.tokenKind) {
    case _tokenNative:
      token = NativeToken(checkChainId(row.tokenChainId));
    case _tokenContract:
      token = ContractToken(
        checkChainId(row.tokenChainId),
        requireValue(row.tokenContract, 'token_contract'),
      );
    case _tokenExchange:
      token = ExchangeToken(
        decodeEnum(
          ExchangeId.values,
          requireValue(row.tokenChainId, 'token_chain_id'),
          '交易所',
        ),
        requireValue(row.tokenSymbol, 'token_symbol'),
      );
    default:
      throw RowDecodeException('未知的代币类型：${row.tokenKind}');
  }

  return Holding(
    accountId: row.accountId,
    location: location,
    token: token,
    assetId: row.assetId,
    displaySymbol: row.displaySymbol,
    amount: decodeDecimal(row.amount),
    updatedAt: row.updatedAt.toUtc(),
  );
}

/// 领域对象 → 持仓行（主键自增，不写入）。
HoldingsCompanion holdingToCompanion(Holding h) {
  final (locationKind, chainId, addressId, exchangeSub) = switch (h.location) {
    OnChainLocation(:final chainId, :final addressId) => (
      _locationOnChain,
      chainId,
      addressId,
      null,
    ),
    ExchangeLocation(:final sub) => (_locationExchange, null, null, sub.name),
  };
  final (
    tokenKind,
    tokenChainId,
    tokenContract,
    tokenSymbol,
  ) = switch (h.token) {
    NativeToken(:final chainId) => (_tokenNative, chainId, null, null),
    ContractToken(:final chainId, :final contract) => (
      _tokenContract,
      chainId,
      contract,
      null,
    ),
    // 规格第 5 节没有给交易所代币留列：交易所 id 存在 token_chain_id 中。
    ExchangeToken(:final exchange, :final symbol) => (
      _tokenExchange,
      exchange.name,
      null,
      symbol,
    ),
  };
  return HoldingsCompanion.insert(
    accountId: h.accountId,
    locationKind: locationKind,
    chainId: Value(chainId),
    addressId: Value(addressId),
    exchangeSub: Value(exchangeSub),
    tokenKind: tokenKind,
    tokenChainId: Value(tokenChainId),
    tokenContract: Value(tokenContract),
    tokenSymbol: Value(tokenSymbol),
    assetId: Value(h.assetId),
    displaySymbol: h.displaySymbol,
    amount: encodeDecimal(h.amount),
    updatedAt: h.updatedAt.toUtc(),
  );
}
