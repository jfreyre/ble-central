//
//  SecondViewController.swift
//  CustomBLE
//
//  Created by Jérome Freyre on 20.03.15.
//  Copyright (c) 2015 Anemomind. All rights reserved.
//

import Foundation
import CoreBluetooth

class ViewController: UIViewController, BluetoothManagerDelegate {
    
    var myBLE: BluetoothManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        myBLE = BluetoothManager.sharedInstance
        BluetoothManager.sharedInstance.delegate = self
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func rescan(sender: UIButton) {
        if BluetoothManager.sharedInstance.isReady() {
            BluetoothManager.sharedInstance.scanForPeripheralsWithInterval(15)
        }
    }
    
    
    
    
    @IBAction func readSomething(sender: UIButton) {
        if var peripheral = BluetoothManager.sharedInstance.connectedPeripherals.firstObject as? CBPeripheral {
            
            for service in peripheral.services as [CBService] {
                
                if service.UUID.UUIDString == BLE_SERVICE {
                    for characteristic in service.characteristics as [CBCharacteristic] {
                        
                        if characteristic.UUID.UUIDString == BLE_SERVICE_READABLE_SHORT {
                            BluetoothManager.sharedInstance.read(peripheral, characteristic: characteristic)
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func readSomethingLong(sender: UIButton) {
        if var peripheral = BluetoothManager.sharedInstance.connectedPeripherals.firstObject as? CBPeripheral {
            for service in peripheral.services as [CBService] {
                
                if service.UUID.UUIDString == BLE_SERVICE {
                    for characteristic in service.characteristics as [CBCharacteristic] {
                        
                        if characteristic.UUID.UUIDString == BLE_SERVICE_READABLE_LARGE {
                            var res = BluetoothManager.sharedInstance.read(peripheral, characteristic: characteristic)
                            
                            if (res) {
                                SVProgressHUD.showWithStatus("Receiving data")
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    @IBAction func writeSomething(sender: UIButton) {
        
        
        if var peripheral = BluetoothManager.sharedInstance.connectedPeripherals.firstObject as? CBPeripheral {
            
            let msg = Lorem.words(313)
            
            var data = msg.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
            
            
            for service in peripheral.services as [CBService] {
                
                if service.UUID.UUIDString == BLE_SERVICE {
                    for characteristic in service.characteristics as [CBCharacteristic] {
                        
                        if characteristic.UUID.UUIDString == BLE_SERVICE_WRITABLE {
                            var res = BluetoothManager.sharedInstance.write(data!, peripheral: peripheral, characteristic: characteristic)
                            
                            if res {
                                SVProgressHUD.showWithStatus("Writing data")
                            }
                        }
                    }
                }
            }
        }
        
        
        
    }
    
    
    
    //MARK: Delegate
    
    func centralDidChangeState(state: CBCentralManagerState) {
        var msg: NSString
        switch state {
        case CBCentralManagerState.Unknown:
            msg = "Central state updated to Unknown"
        case CBCentralManagerState.Resetting:
            msg = "Central state updated to Resetting"
        case CBCentralManagerState.Unsupported:
            msg = "Central state updated to Unsupported"
        case CBCentralManagerState.Unauthorized:
            msg = "Central state updated to Unauthorized"
        case CBCentralManagerState.PoweredOff:
            msg = "Central state updated to PoweredOff"
        case CBCentralManagerState.PoweredOn:
            msg = "Central state updated to PoweredOn"
            BluetoothManager.sharedInstance.scanForPeripheralsWithInterval(5)
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                SVProgressHUD.showSuccessWithStatus("Scanning for peripherals")
            })
            return
        default:
            msg = "Central state updated to WHAT??!!"
        }
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            SVProgressHUD.showErrorWithStatus(msg)
        })
    }
    
    
    func centralDidNotFoundAnyDevice() {
        SVProgressHUD.showErrorWithStatus("No peripheral found...")
    }
    func centralIsConnectedToPeripheral(peripheral: CBPeripheral) {
        SVProgressHUD.showWithStatus("Connected to \(peripheral.name)")
    }
    func centralIsDisconnectedFromPeripheral(peripheral: CBPeripheral) {
        SVProgressHUD.showWithStatus("Disconnected to \(peripheral.name)")
    }
    
    
    
    
    
   
    func peripheralDidWrote(characteristic: CBCharacteristic, onPeripheral peripheral: CBPeripheral) {
        NSLog("Characteristic %@ => written", characteristic)
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            SVProgressHUD.showSuccessWithStatus("Data sent!")
        })
    }
    
    
    func peripheralDidRead(value: NSString, ofCharacteristic characteristic: CBCharacteristic, onPeripheral peripheral: CBPeripheral) {
        if characteristic.UUID.UUIDString == BLE_SERVICE_READABLE_SHORT {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                SVProgressHUD.showSuccessWithStatus("Read short: \(value)")
            })
        } else if characteristic.UUID.UUIDString == BLE_SERVICE_READABLE_LARGE {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                SVProgressHUD.showSuccessWithStatus("Read long: \(value)")
            })
        }
    }
    
    func peripheralDidUpdateValue(value: NSString, ofCharacteristic characteristic: CBCharacteristic, onPeripheral peripheral: CBPeripheral) {
        
        let message = "Notified for \(value)"
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            SVProgressHUD.showSuccessWithStatus(message)
        })
    }
}