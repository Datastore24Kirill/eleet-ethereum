//
//  ViewController.swift
//  eleet-eth
//
//  Created by руслан on 24.06.2018.
//  Copyright © 2018 руслан. All rights reserved.
//

import UIKit
import EthereumKit

struct ITxInput {
    var gasPrice: Int
    var nonce: Int
}

class ViewController: UIViewController {

    var wallet: EthereumWallet!;
    
    @IBAction func onClick(_ sender: Any) {
        wallet = EthereumWallet.fromPrivateKey(privateKey: "81CE075F512F4912BDC6FF2368E9653DA25996BA91C514DF9E894D7042899805", network: .ropsten)
        //transferErc20Example();
        //getHistoryExample();
        
        //getTokenBalanceExample();
       
        sendEthExample();
    }
    
    func sendEthExample() {
        //wallet.sendEth(to: "", value: "0.011", gasPrice: 1)
        
        self.getGasPriceAndNonce() { result in
            switch(result) {
            case .success(let info):
                self.wallet?.sendEth(to: "0x3C437b1141e4e5393EC4Fac04184AefA04bF08d4", value: "0.011", gasPrice: info.gasPrice, nonce: info.nonce) { result in
                    switch(result) {
                    case .success(let rawTx): //rawTx - подписанная транзакция которую нужно отправить через eleet-api
                        print("ok", rawTx.raw);
                    case .failure(let error):
                        print("error", error);
                    }
                }
            case .failure(let error):
                print("Error", error);
            }
        }
        
    }
    
    func getGasPriceAndNonce(completionHandler: @escaping (Result<ITxInput>) -> Void) {
        wallet.getNonce() { result in
            switch(result) {
            case .success(let nonce):
                self.wallet?.getGasPrice()  { result in
                    switch(result) {
                    case .success(let gasPrice):
                        completionHandler(Result<ITxInput>.success(ITxInput(gasPrice: gasPrice, nonce: nonce)));
                    case .failure(let error):
                        completionHandler(Result<ITxInput>.failure(error));
                    }
                }
            case .failure(let error):
                completionHandler(Result<ITxInput>.failure(error));
            }
        }
    }
    
    func getTokenBalanceExample() {
        wallet.getTokenBalance(contractAddress: "0xd749c1be21724a26a0f9fbadda319299b9353ea7", address: "0x064F953306211F4D95DC5A380bd04b3E35F4B241") { result in
            switch(result) {
            case .success(let balance):
                print("tokenBalance", balance);
            case .failure(let error):
                print("error", error);
            }
        }
    }
    
    func getHistoryExample() {
        wallet?.getHistory() { result in
            switch(result) {
            case .success(let txs):
                print("ok", txs)
            case .failure(let error):
                print("Error", error);
            }
        }
    }
    
    
    func transferErc20Example() {
        self.getGasPriceAndNonce()  { result in
            switch(result) {
            case .success(let info):
                self.wallet?.erc20Transfer(contractAddress: "0x0b7af3d5c5c842fca31f7297984d5ff4e99b20ce", decimal: 18, to: "0x3C437b1141e4e5393EC4Fac04184AefA04bF08d4", amount: "1000000", gasPrice: info.gasPrice, nonce: info.nonce) { result in
                    switch(result) {
                    case .success(let rawTx): //rawTx - подписанная транзакция которую нужно отправить через eleet-api
                        print("ok", rawTx);
                    case .failure(let error):
                        print("error", error);
                    }
                }
            case .failure(let error):
                print("Error", error);
            }
        }
    }
    
    @IBOutlet weak var btn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func testThreadsAction(_ sender: UIButton) {
//        let privateKeys: [String] = ["8d2e98e915899591fdb171210949f8e681e0afe5f23c88e1d024417f86c2a687",
//                                     "d9c7e0ceafd36c97ea11c2546a40b5189698fefe597769801e1b0d0c94eac4ac",
//                                     "c4c2ae5703446d44230df41848da392d053834b8378aae4994dbd8e2d4618310"]
        
//        for key in privateKeys {
//            let wallet = EthereumWallet.fromPrivateKey(privateKey: key, network: .ropsten)
//            wallet.getBalance(of: wallet.getAddress(), completionHandler:{(result: Result<Balance>) -> Void in
//                switch(result) {
//                case .success(let balance):
//                    print("getBalance: success", balance);
//                case .failure(let error):
//                    print("getBalance: failure", error);
//                }
//            })
//        }
        
        let tokensAddressed: [String] = ["0x0b7af3d5c5c842fca31f7297984d5ff4e99b20ce",
                                         "0x0b7af3d5c5c842fca31f7297984d5ff4e99b20ce",
                                         "0x0b7af3d5c5c842fca31f7297984d5ff4e99b20ce",
                                         "0x0b7af3d5c5c842fca31f7297984d5ff4e99b20ce",
                                         "0x0b7af3d5c5c842fca31f7297984d5ff4e99b20ce",
                                         "0x0b7af3d5c5c842fca31f7297984d5ff4e99b20ce"]
        
        for address in tokensAddressed {
            let queue = DispatchQueue.global()
            queue.async {
                let wallet = EthereumWallet.fromPrivateKey(privateKey: "8d2e98e915899591fdb171210949f8e681e0afe5f23c88e1d024417f86c2a687", network: .ropsten)
                wallet.getTokenBalance(contractAddress: wallet.getAddress(), address: address, complectionHandler:{(result: Result<Wei>) -> Void in
                    switch(result) {
                    case .success(let balance):
                        print("getBalance: success", balance);
                    case .failure(let error):
                        print("getBalance: failure", error);
                    }
                })
            }
        }
    }
}
