//
//  eth.swift
//  eleet-eth
//
//  Created by руслан on 24.06.2018.
//  Copyright © 2018 руслан. All rights reserved.
//

import Foundation
import EthereumKit


public class EthereumWallet {
    private static var lockQueue = DispatchQueue(label: "EthereumWallet.LockQueue")
    
    let wallet: Wallet;
    let network: Network;
    let geth: Geth;
    private var walletAddress: String? = nil;
    private let mnemonic: [String];
    
    public static func fromDump(dump: String) -> EthereumWallet {
        let key = KeyStoreUtils.parseDump(dump: dump);
        return self.fromPrivateKey(privateKey: key.privateKey, network: key.network, mnemonic: key.mnemonic)
    }
    
    // Инициализация с помощью незашифрованного приватного ключа
    public static func fromPrivateKey(privateKey: String, network: Network, mnemonic: [String] = []) -> EthereumWallet {
        return EthereumWallet(privateKey: privateKey, network: network, mnemonic: mnemonic);
    }
    
    // Создание нового кошелька
    public static func newWallet(network: Network) -> EthereumWallet {
        let words = Mnemonic.create();
        return try! EthereumWallet.fromMnemonic(words: words, network: network);
    }
    
    
    // Инициализация с помощью мнемоники
    public static func fromMnemonic(words: [String], network: Network) throws -> EthereumWallet {
        let seed = try Mnemonic.createSeed(mnemonic: words);
        return EthereumWallet(seed: seed, network: network, mnemonic: words);
    }
    
    
    convenience init(privateKey: String, network: Network, mnemonic: [String] = []) {
        let wallet = Wallet(network: network, privateKey: privateKey, debugPrints: false);
        self.init(wallet: wallet, mnemonic: mnemonic, network: network);
    }
    
    convenience init(seed: Data, network: Network, mnemonic: [String]) {
        let wallet = try! Wallet(seed: seed, network: network, debugPrints: false);
        
        self.init(wallet: wallet, mnemonic: mnemonic, network: network);
    }
    

    init(wallet: Wallet, mnemonic: [String] = [], network: Network) {
        self.wallet = wallet;
        self.network = network;
        self.mnemonic = mnemonic;
        
        switch network {
        case .ropsten:
            geth = Geth(configuration: Configuration(
                network: .ropsten,
                nodeEndpoint: "https://ropsten.infura.io/dWNQZeUnLI78WlxX45Cs",
                etherscanAPIKey: "IQRY7URW5PDAEDF9PGX2BKYQW5IIBVN4GI",
                debugPrints: true
            ))
        default:
            geth = Geth(configuration: Configuration(
                network: .mainnet,
                nodeEndpoint: "https://mainnet.infura.io/dWNQZeUnLI78WlxX45Cs",
                etherscanAPIKey: "IQRY7URW5PDAEDF9PGX2BKYQW5IIBVN4GI",
                debugPrints: false
            ))
        }
    }
    
    
    // Перевод токенов
    /**
     contractAddress - адрес контракта
     decimal - количество цифр после запятой (как правило 18, но может отличаться)
     //contractAddress и decimals будет отдавать eleet-сервер
     
     to - адрес получателя токенов
     amount - количество токенов в виде строки, например 1000, 22000 и т.д. (может превышать размеры uint)
     gasPrice - стоимость gas которую отправитель готов заплатить, на данном этапе будем его предварительно получать через метод getGasPrice()
     
     
     returns - возвращает подписанный rawTx который нужно затем отправить используя eleet-api
     
    **/
    public func erc20Transfer(contractAddress: String, decimal: Int, to: String, amount: String, gasPrice: Int, nonce: Int, completionHandler: @escaping (Result<Tx>) -> Void) {
        let erc20 = ERC20(contractAddress: contractAddress, decimal: decimal, symbol: "");
        let txData = try! erc20.generateDataParameter(toAddress: to, amount: amount);
        
        estimateTx(to: contractAddress, value: "0", data: txData) {result in
            switch result {
            case .success(let gasLimit):
                self.createAndSignRawTx(
                    to: contractAddress, value: "0", gasPrice: gasPrice,
                    gasLimit: gasLimit, data: txData, nonce: nonce, completionHandler: completionHandler)
            case .failure(let error):
                completionHandler(Result<Tx>.failure(error));
            }
        }
    }
    
    
    // Отправка эфир-монет
    public func sendEth(to: String, value: String, gasPrice: Int, nonce: Int, completionHandler: @escaping (Result<Tx>) -> Void) {
        let val = try! Converter.toWei(ether: value).asString(withBase: 10)
        
        estimateTx(to: to, value: val) {result in
            switch result {
            case .success(let gasLimit):
                self.createAndSignRawTx(to: to, value: val, gasPrice: gasPrice, gasLimit: gasLimit, data: Data(), nonce: nonce, completionHandler: completionHandler);
            case .failure(let error):
                completionHandler(Result<Tx>.failure(error));
            }
        }
    }
    
    // Создание и подпись транзакции
    public func createAndSignRawTx(to: String, value: String, gasPrice: Int, gasLimit: Int, data: Data, nonce: Int, completionHandler: @escaping (Result<Tx>) -> Void) {
        let rawTransaction = RawTransaction(wei: value, to: to, gasPrice: gasPrice, gasLimit: gasLimit, nonce: nonce, data: data)
        let txraw: String
        
        do {
            txraw = try self.wallet.sign(rawTransaction: rawTransaction)
            let tx = Tx(raw: txraw, gasLimit: gasLimit, gasPrice: gasPrice);
            completionHandler(Result<Tx>.success(tx));
        } catch _ {
            completionHandler(Result<Tx>.failure(EthereumKitError.cryptoError(.failedToSign)));
        }
    }
    
    // Расчет количество gas которое нужно для отправки транзакции (gasLimit)
    public func estimateTx(to: String, value: String = "0", data: Data = Data(), completionHandler: @escaping (Result<Int>) -> Void) {
        geth.getEstimateGas(from: getAddress(), to: to, data: "0x" + data.toHexString()) { result in
            switch result {
            case .success(let gasLimit):
                completionHandler(Result<Int>.success(Converter.toInt(wei: gasLimit)))
            case .failure(let error):
                completionHandler(Result<Int>.failure(error));
            }
        }
    }
    
    // Получение nonce
    public func getNonce(completionHandler: @escaping (Result<Int>) -> Void) {
        geth.getTransactionCount(of: getAddress()) { result in
            switch result {
            case .success(let nonce):
                completionHandler(Result<Int>.success(nonce));
            case .failure(let error):
                completionHandler(Result<Int>.failure(error));
            }
        }
    }
    
    
    // Получение среднего gasPrice по сети
    public func getGasPrice(comlectionHandler: @escaping (Result<Int>) -> Void) {
        geth.getGasPrice() { result in
            switch(result) {
            case .success(let gasPrice):
                comlectionHandler(Result<Int>.success(Converter.toInt(wei: gasPrice)))
            case .failure(let error):
                comlectionHandler(Result<Int>.failure(error));
            }
        }
    }

    // Получить свой баланс в эфирах
    public func getMyBalance(completionHandler: @escaping (Result<Wei>) -> Void) {
        self.getBalance(of: self.getAddress(), completionHandler: completionHandler);
    }
    
    // Получить баланс указанного адреса в эфирах
    public func getBalance(of: String, completionHandler: @escaping (Result<Wei>) -> Void) {
        geth.getBalance(of: of){result in
            switch(result) {
            case .success(let balance):
                completionHandler(Result<Wei>.success(balance.wei));
            case .failure(let error):
                completionHandler(Result<Wei>.failure(error));
            }
        };
    }
    
    
    // Получение количество определенных токенов у определенного адреса
    public func getTokenBalance(contractAddress: String, address: String, complectionHandler: @escaping (Result<Wei>) -> Void) {
        let method = Utils.methodSignature(method: "balanceOf(address)").toHexString();
        let tokenAddress = Utils.pad(string: address.stripHexPrefix());
        
        let dataHex = method + tokenAddress;
        geth.call(to: contractAddress, data: "0x" + dataHex) { result in
            switch(result) {
            case .success(let res):
                let balance = Wei(res, radix: 16)!;
                complectionHandler(Result<Wei>.success(balance));
            case .failure(let error):
                complectionHandler(Result<Wei>.failure(error));
            }
        }
    }
    
    // Получить свой адрес
    public func getAddress() -> String {
        
        
        return "";
    }
    
    // Получение истории транзакций
    public func getHistory(complectionHandler: @escaping (Result<Transactions>) -> Void) {
        geth.getTransactions(address: getAddress(), completionHandler: complectionHandler);
    }
    
    // Экспортировать приватный ключ в незашифрованном виде (hex)
    public func exportPrivateKey() -> String {
        return ""
    }
    
    public func exportMnemonic() -> [String] {
        return self.mnemonic;
    }
    
    public func dump() -> String {
        return KeyStoreUtils.createDump(pk: self.exportPrivateKey(), mnemonic: self.exportMnemonic(), network: self.network);
    }
    
    
    
}

public class Tx {
    public let raw: String;
    public let gasLimit: Int;
    public let gasPrice: Int;
    
    public init(raw: String, gasLimit: Int, gasPrice: Int) {
        self.raw = raw;
        self.gasLimit = gasLimit;
        self.gasPrice = gasPrice;
    }
    
    
    public func estimateFee() -> Wei {
        return Wei.init(integerLiteral: self.gasLimit * self.gasPrice);
    }
    
}


extension Converter {
    static func toInt(wei: Wei) -> Int {
        return Int(wei.asString(withBase: 10))!;
    }
}


public class Utils {
    
    public static func toEther(wei: Wei) -> Ether {
        return try! Converter.toEther(wei: wei);
    }
    
    static func pad(string: String) -> String {
        var string = string
        while string.count != 256 / 4 {
            string = "0" + string
        }
        return string
    }
    
    static func methodSignature(method: String) -> Data {
        return method.data(using: .ascii)!.sha3(.keccak256)[0...3]
    }
  
    
}

class KeyStoreUtils {
    
    static func createDump(pk: String, mnemonic: [String], network: Network) -> String {
        let data = DumpKey(pk: pk, w: mnemonic, n: self.serializeNetworkType(network: network));
        let enc = try! JSONEncoder().encode(data);
        
        return enc.toHex();
    }
    
    
    
    static func parseDump(dump: String) -> DumpKeyDecoded {
        let data = try! JSONDecoder().decode(DumpKey.self, from: dump.toData()!);
        return DumpKeyDecoded(privateKey: data.pk, mnemonic: data.w, network: self.parseNetworkType(type: data.n))
    }
    
    
    static func serializeNetworkType(network: Network) -> String {
        switch network {
        case .mainnet:
            return "main"
        default:
            return "ropsten"
        }
    }
    
    static func parseNetworkType(type: String) -> Network {
        if(type == "main") {
            return Network.mainnet;
        }
        
        return Network.ropsten;
    }
    
}


struct DumpKey: Codable {
    let pk: String;
    let w: [String];
    let n: String;
}

struct DumpKeyDecoded {
    let privateKey: String;
    let mnemonic: [String];
    let network: Network;
}



extension Data {
    func toHex() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

extension String {
    func toData() -> Data? {
        var data = Data(capacity: count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSMakeRange(0, utf16.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }
        
        guard data.count > 0 else { return nil }
        
        return data
    }
    
}
