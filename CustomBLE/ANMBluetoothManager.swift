//
//  BluetoothManager.swift
//  CustomBLE
//
//  Created by Jérome Freyre on 20.03.15.
//  Copyright (c) 2015 Anemomind. All rights reserved.
//

import Foundation
import CoreBluetooth

//MARK: Bluetooth services/chars id's

let BLE_SERVICE = "F7065DCC-CEBE-48FD-BD63-89426BC5F787"

let BLE_SERVICE_WRITABLE          = "F7065DCC-AAAA-48FD-BD63-89426BC5F787"
let BLE_SERVICE_READABLE_SHORT    = "F7065DCC-BBBB-48FD-BD63-89426BC5F787"
let BLE_SERVICE_READABLE_LARGE    = "F7065DCC-CCCC-48FD-BD63-89426BC5F787"
let BLE_SERVICE_NOTIFIER          = "F7065DCC-DDDD-48FD-BD63-89426BC5F787"



//MARK: BluetoothManagerDelegate
protocol BluetoothManagerDelegate {
    
    // Called on BLE state change
    func centralDidChangeState(state: CBCentralManagerState)
    
    // Called after scan
    func centralDidNotFoundAnyDevice()
    
    
    func centralIsConnectedToPeripheral(peripheral: CBPeripheral)
    func centralIsDisconnectedFromPeripheral(peripheral: CBPeripheral)
    
    // Called after write
    func peripheralDidWrote(characteristic: CBCharacteristic, onPeripheral peripheral: CBPeripheral)
    // Called after read
    func peripheralDidRead(value: NSString, ofCharacteristic characteristic: CBCharacteristic, onPeripheral peripheral: CBPeripheral)
    // Called after notification
    func peripheralDidUpdateValue(value: NSString, ofCharacteristic characteristic: CBCharacteristic, onPeripheral peripheral: CBPeripheral)
}


class BluetoothManager: NSObject {
    
    //MARK: - Properties
    var central: CBCentralManager!
    var centralManager: ANMCentralManager!
    var peripheralManager: ANMPeripheralManager!
    var delegate: BluetoothManagerDelegate?
    
    var connectedPeripherals: NSMutableArray = NSMutableArray()
    
    var listeningServices: NSMutableArray = NSMutableArray(objects:
        CBUUID(string: BLE_SERVICE)
    )
    var notifiableCharacteristics: NSMutableArray = NSMutableArray(objects:
        CBUUID(string: BLE_SERVICE_NOTIFIER)
    )
    
    var readableCharacteristics: NSMutableArray = NSMutableArray(objects:
        CBUUID(string: BLE_SERVICE_READABLE_SHORT),
        CBUUID(string: BLE_SERVICE_READABLE_LARGE)
    )
    
    // Amount of byte transmitted
    let MTU_NOTIFY = 512
    // Indicate end of contente transmission
    let EOM_CONTENT = "==EOM=="
    
    // Singleton
    class var sharedInstance: BluetoothManager {
        struct Static {
            static let instance: BluetoothManager = BluetoothManager()
        }
        return Static.instance
    }
    
    //MARK: - init Override
    override init() {
        super.init()
        centralManager = ANMCentralManager(bleMgr: self)
        peripheralManager = ANMPeripheralManager(bleMgr: self)
        
        central = CBCentralManager(delegate: centralManager, queue: dispatch_queue_create("ch.ble-manager.BLECentralQueue", nil))
    }
    
    //MARK: - Methods
    func isReady() -> Bool {
        return (central.state == .PoweredOn)
    }
    
    // Used to scan peripheral during a defined time
    // -1 means continuous scan
    func scanForPeripheralsWithInterval(interval: NSNumber) -> Bool {
        NSLog("-> start scanning for devices")
        
        if central.state == .PoweredOn {
            
            central.scanForPeripheralsWithServices(listeningServices, options: nil)
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                if interval.integerValue > 0 {
                    var timer = NSTimer.scheduledTimerWithTimeInterval(interval.doubleValue, block: { () -> Void in
                        NSLog("-> scan is terminated")
                        self.central.stopScan()
                        if self.connectedPeripherals.count == 0 {
                            self.delegate?.centralDidNotFoundAnyDevice()
                        }
                        }, repeats: false) as NSTimer
                }
            })
            return true
        }
        return false
    }
    
    // Trying to read data from a peripheral
    func read(peripheral: CBPeripheral, characteristic: CBCharacteristic) -> Bool {
        return self.peripheralManager.readData(peripheral, characteristic: characteristic);
    }
    
    // Trying to write data from a peripheral
    func write(data: NSData, peripheral: CBPeripheral, characteristic: CBCharacteristic) -> Bool {
        return self.peripheralManager.writeData(data, peripheral: peripheral, characteristic: characteristic)
    }
    
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    
    //MARK: - ANMCentralManager
    // Will be used to managed the central as a private object
    class ANMCentralManager: NSObject, CBCentralManagerDelegate {
        //MARK: - Properties
        // We keep a reference to the parent
        var bleMgr: BluetoothManager
        
        //MARK: - UI Base Override
        init(bleMgr: BluetoothManager) {
            self.bleMgr = bleMgr
        }
        
        //MARK: - Delegate
        func centralManagerDidUpdateState(central: CBCentralManager!) {
            bleMgr.delegate?.centralDidChangeState(central.state)
        }
        
        func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
            
            if (!bleMgr.connectedPeripherals.containsObject(peripheral)) {
                NSLog("-> Discovered a new peripheral: %@, rssi: %@)", peripheral.name, RSSI);
                bleMgr.connectedPeripherals.addObject(peripheral)
                bleMgr.central.connectPeripheral(peripheral, options: NSDictionary(object: NSNumber(bool: true), forKey: CBConnectPeripheralOptionNotifyOnDisconnectionKey))
            }
        }
        
        func centralManager(central: CBCentralManager!, didFailToConnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
            NSLog("-> ✘ Connecting periperal %@ ", peripheral.name)
            if bleMgr.connectedPeripherals.containsObject(peripheral) {
                bleMgr.connectedPeripherals.removeObject(peripheral)
            }
        }
        
        func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
            NSLog("-> Connected to %@", peripheral.name)
            
            if (!bleMgr.connectedPeripherals.containsObject(peripheral)) {
                bleMgr.connectedPeripherals.addObject(peripheral)
            }
            
            if (bleMgr.delegate != nil) {
                bleMgr.delegate?.centralIsConnectedToPeripheral(peripheral)
            }
            
            peripheral.delegate = bleMgr.peripheralManager
            peripheral.discoverServices(nil)
        }
        
        func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
            NSLog("-> Disconnected from %@", peripheral.name)
            
            if bleMgr.connectedPeripherals.containsObject(peripheral) {
                bleMgr.connectedPeripherals.removeObject(peripheral)
            }
            
            if (bleMgr.delegate != nil) {
                bleMgr.delegate?.centralIsDisconnectedFromPeripheral(peripheral)
            }
        }
    }
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    
    //MARK: - ANMPeripheralManager
    // Will be used to managed all peripheral action
    class ANMPeripheralManager: NSObject, CBPeripheralDelegate {
        //MARK: - Properties
        private var receivingMessage: NSString = ""
        private var receivingCharacteristic: CBCharacteristic?
        private var isReceivingData = false
        
        private var isSendingData = false
        private var sendingDataIndex: NSInteger = 0
        private var dataToSend: NSData?
        private var currentAmountOfSendingData: NSInteger = 0
        private var sendingEOM = false
        private var EOMHasBeenSent = false
        private var sendingPeripheral: CBPeripheral?
        private var sendingChar: CBCharacteristic?
        
        //MARK: - init base Override
        var bleMgr: BluetoothManager
        init(bleMgr: BluetoothManager) {
            self.bleMgr = bleMgr
        }
        
        
        //MARK: - Delegate
        
        func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
            if (error != nil) {
                NSLog("-> ERROR updating value services")
                NSLog(error.description)
                return
            }
            
            if (characteristic.value?.length > 0) {
                
                var content = NSString(data: characteristic.value, encoding: NSUTF8StringEncoding)
                
                if bleMgr.notifiableCharacteristics.containsObject(characteristic.UUID) {
                    bleMgr.delegate?.peripheralDidUpdateValue(content!, ofCharacteristic: characteristic, onPeripheral: peripheral)
                } else if bleMgr.readableCharacteristics.containsObject(characteristic.UUID) {
                    
                    if content == bleMgr.EOM_CONTENT {
                        bleMgr.delegate?.peripheralDidRead(receivingMessage, ofCharacteristic: characteristic, onPeripheral: peripheral)
                        receivingMessage = ""
                        isReceivingData = false
                    } else {
                        NSLog("RECEIVED: \(content)")
                        if content != nil {
                            receivingMessage = receivingMessage.stringByAppendingString(content!)
                        }
                        peripheral.readValueForCharacteristic(characteristic)
                    }
                }
                
                
            }
        }
        
        func peripheral(peripheral: CBPeripheral!, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
            if (error != nil) {
                NSLog("-> ERROR retrieving services")
                NSLog(error.description)
                return
            }
            if (characteristic.value?.length > 0) {
                var content = NSString(data: characteristic.value, encoding: NSUTF8StringEncoding)
                NSLog("New notification value!!!! %@", content!)
            }
            
        }
        
        func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
            if (error != nil) {
                NSLog("-> ✘ retrieving services of %@", peripheral.name)
                NSLog("-> Error: %@", error.description)
                return
            }
            
            for service in peripheral.services as [CBService] {
                NSLog("-> Found service %@ for %@", service.UUID.UUIDString, peripheral.name)
                
                if (bleMgr.listeningServices.containsObject(service.UUID)) {
                    NSLog("-> Discovering characteristics for service %@", service.UUID.UUIDString)
                    peripheral.discoverCharacteristics(nil, forService: service)
                }
                
            }
        }
        
        func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
            if (error != nil) {
                NSLog("-> ✘ retrieving services")
                NSLog("-> Error: %@", error.description)
                return
            }
            
            // Is the service surveyed ?
            if bleMgr.listeningServices.containsObject(service.UUID) {
                // then browsing his characteristics
                for characteristics in service.characteristics as [CBCharacteristic] {
                    NSLog("-> Discovered char: %@", characteristics.UUID.UUIDString)
                    // Is the characteristics watched for notifications ?
                    if bleMgr.notifiableCharacteristics.containsObject(characteristics.UUID) {
                        peripheral.setNotifyValue(true, forCharacteristic: characteristics)
                    }
                }
            }
        }
        
        func peripheral(peripheral: CBPeripheral!, didWriteValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
            // An error occured ? Then try to rewrite data
            if (error != nil) {
                NSLog("-> ✘ writing data")
                if !sendingEOM {
                    sendingDataIndex -= currentAmountOfSendingData
                }
                
                self.sendData()
                return
                
            }
            // End of data ? Then notify delegate
            if (sendingEOM) {
                sendingEOM = false
                isSendingData = false
                bleMgr.delegate?.peripheralDidWrote(sendingChar!, onPeripheral: sendingPeripheral!)
                return
                
                // End of data
            } else if sendingDataIndex >= dataToSend?.length {
                sendingEOM = true
            }
            
            NSLog("-> ✓ chunk of data sent");
            
            // Send a new block of data
            self.sendData()
            
        }
        
        
        //MARK: - Methods
        
        func readData(peripheral: CBPeripheral, characteristic: CBCharacteristic) -> Bool {
            if isReceivingData {
                return false
            }
            receivingCharacteristic = characteristic
            isReceivingData = true
            receivingMessage = ""
            
            peripheral.readValueForCharacteristic(characteristic)
            
            return true
        }
        
        func writeData(data: NSData, peripheral: CBPeripheral, characteristic: CBCharacteristic) -> Bool {
            
            if (isSendingData) {
                return false
            }
            
            isSendingData = true
            sendingDataIndex = 0
            currentAmountOfSendingData = 0
            
            dataToSend = data
            sendingEOM = false
            EOMHasBeenSent = false
            sendingPeripheral = peripheral
            sendingChar = characteristic
            
            sendData()
            
            return true
        }
        
        func sendData() {
            
            // Should we send the EOM ?
            if sendingEOM {
                var data = bleMgr.EOM_CONTENT.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
                currentAmountOfSendingData = data!.length
                sendingPeripheral!.writeValue(data, forCharacteristic: sendingChar!, type: CBCharacteristicWriteType.WithResponse)
                return;
            }
            
            // All data have been sent ?
            if sendingDataIndex > dataToSend?.length {
                return;
            }
            
            // Calculating amount of data that will be sent
            currentAmountOfSendingData = dataToSend!.length - sendingDataIndex
            if (currentAmountOfSendingData > bleMgr.MTU_NOTIFY) {
                currentAmountOfSendingData = bleMgr.MTU_NOTIFY
            }
            
            // Preparing chunk of data
            var chunk = dataToSend!.subdataWithRange(NSMakeRange(sendingDataIndex, currentAmountOfSendingData))
            
            NSLog("Sent: %@", NSString(data: chunk, encoding: NSUTF8StringEncoding)!);
            
            // Writing value to characteristic
            sendingPeripheral!.writeValue(chunk, forCharacteristic: sendingChar, type: CBCharacteristicWriteType.WithResponse)
            
            sendingDataIndex += currentAmountOfSendingData
        }
        
        
        
    }
}