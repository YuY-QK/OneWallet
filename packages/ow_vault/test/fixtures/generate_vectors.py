import json
from bip_utils import *
M={"abandon":("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",""),
   "legal_pp":("legal winner thank year wave sausage worth useful legal winner thank yellow","TREZOR"),
   "zoo24":("zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo vote","")}
T={"evmStandard":"m/44'/60'/0'/0/{i}","evmLedgerLive":"m/44'/60'/{i}'/0/0","btcNativeSegwit":"m/84'/0'/0'/0/{i}","btcTaproot":"m/86'/0'/0'/0/{i}",
   "btcNestedSegwit":"m/49'/0'/0'/0/{i}","btcLegacy":"m/44'/0'/0'/0/{i}","solanaStandard":"m/44'/501'/{i}'/0'","solanaLegacy":"m/44'/501'/{i}'","tronStandard":"m/44'/195'/0'/0/{i}"}
def addr(seed,s,i):
    p=T[s].replace("{i}",str(i))
    if s.startswith("solana"):
        k=Bip32Slip10Ed25519.FromSeed(seed).DerivePath(p); return SolAddrEncoder.EncodeKey(k.PublicKey().KeyObject())
    k=Bip32Slip10Secp256k1.FromSeed(seed).DerivePath(p).PublicKey().KeyObject()
    if s.startswith("evm"): return EthAddrEncoder.EncodeKey(k)
    if s=="tronStandard": return TrxAddrEncoder.EncodeKey(k)
    if s=="btcNativeSegwit": return P2WPKHAddrEncoder.EncodeKey(k,hrp="bc")
    if s=="btcTaproot": return P2TRAddrEncoder.EncodeKey(k,hrp="bc")
    if s=="btcNestedSegwit": return P2SHAddrEncoder.EncodeKey(k,net_ver=b"\x05")
    if s=="btcLegacy": return P2PKHAddrEncoder.EncodeKey(k,net_ver=b"\x00")
out=[]
for name,(m,pp) in M.items():
    seed=Bip39SeedGenerator(m).Generate(pp)
    out.append({"name":name,"mnemonic":m,"passphrase":pp,"addresses":{s:[addr(seed,s,i) for i in range(5)] for s in T}})
json.dump({"generator":"python bip_utils "+__import__("importlib.metadata").metadata.version("bip_utils"),"cases":out},open(__import__("os").path.join(__import__("os").path.dirname(__file__),"derivation_vectors.json"),"w"),indent=1)
print(out[0]["addresses"]["evmStandard"][0], out[0]["addresses"]["solanaLegacy"][0])
