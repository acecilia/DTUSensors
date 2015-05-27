//
//  TransmisionViewController.swift
//  DTUSensors3
//
//  Created by Andres on 11/4/15.
//  Copyright (c) 2015 Andres. All rights reserved.
//

import UIKit
import CoreBluetooth

/**
*  ViewController in charge of the transmission
*/
class TransmisionViewController: UITableViewController, CBPeripheralDelegate {
    
    /// Object that stores all the information related with the sensors, baudrate...
    var TPC : TransmissionParametersController!
    
    /// Stores the transmission period in seconds (usually less than 1)
    var transmissionPeriod : Double!
    
    /// The CMMotionManagerController
    var motionManagerController : CMMotionManagerController!
    
    /// Previous controller (peripehralViewController). Used to go back when the watchdog finishes
    var previousVC : PeripheralViewController!
    
    /// Stores the sensors enabled, to present the table
    var enabledSensors : [CustomSensorsObject]!
    
    /// Object that stores the information of the BLE device selected
    var selectedDevice : CustomPeripheralObject!
    
    //MARK: - Control of the transmission
    
    /// Object used as transmission window for fragmented information
    var transmissionWindow = [NSData]()
    
    /// Stores the value of the connection health knowing the packages sent and the packages received
    var connectionHealth : Double = 1
    
    /// Stores the state of the transmission
    var state = 0

    /// Stores the value of the configuration state
    let STATE_CONFIGURING_CONNECTION = 0
    
    /// Stores the value of the sending first fragment state
    let STATE_SENDING_FIRST_FRAGMENT = 1
    
    /// Stores the value of the sending fragments state
    let STATE_SENDING_FRAGMENTS = 2
    
    //MARK: - Timer related
    
    /// Timer used to send the information based on the baudrate selected by the user and the fragments of the package
    var timer: NSTimer!
    
    /// Whatchdog to control a correct transmission
    var whatchdog: NSTimer!
    
    /// Interval for the whatchdog: if there is no answer from the arduino in 2 seconds the transmission is cancelled and an alert is raised
    var whatchdogInterval : Double = 2
    
    /// Variable to control the safe execution of the sending code
    var safeExecution = true

    //MARK: - Functions related with the viewController
    
    /**
    Start the sensors, start the timer to transmit and start the watchdog
    */
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        startTransmission()
    }
    
    /**
    Change delegate of the selected peripheral and invalidate timer and watchdog. Also stop sensors.
    :param: animated
    */
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        stopTransmission()
    }
    
    // MARK: - TableView delegate
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        var sections = 2
        enabledSensors = []
        
        for sensor in TPC.sensors
        {
            if sensor.state == true
            {
                enabledSensors.append(sensor)
                sections++
            }
        }
        
        return sections
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let result : Int
        
        if section >= 2 {
            result = 3
        }
        else {
            result = 1
        }
        
        return result
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let resultTitle : String?
        
        switch section
        {
        case 0:
            resultTitle = "Real baudrate"
        case 1:
            resultTitle = "Connection health"
        default:
            resultTitle = "Data for the " + enabledSensors[section-2].name
        }
        
        return resultTitle
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as! UITableViewCell
        
        switch indexPath.section
        {
        case 0:
            if let label = cell.contentView.viewWithTag(51) as? UILabel
            {
                label.text = "\(1/transmissionPeriod)"
            }
        case 1:
            if let label = cell.contentView.viewWithTag(51) as? UILabel
            {
                label.text = "\(Int(connectionHealth*100))%"
            }
        default:
            switch indexPath.row
            {
            case 0:
                if let label = cell.contentView.viewWithTag(51) as? UILabel
                {
                    var stringToShow = ""
                    for parameter in enabledSensors[indexPath.section-2].realDataDescrition
                    {
                        stringToShow += "| \(round(10000*parameter)/10000) |"
                    }
                    label.text = stringToShow
                }
            case 1:
                if let label = cell.contentView.viewWithTag(51) as? UILabel
                {
                    var stringToShow = ""
                    for parameter in enabledSensors[indexPath.section-2].scaledDataDescrition
                    {
                        stringToShow += "| \(parameter) |"
                    }
                    label.text = stringToShow
                }
            case 2:
                if let label = cell.contentView.viewWithTag(51) as? UILabel
                {
                    label.text = "Index of sensor = \(indexPath.section-2)"
                }
            default: ()
            }
        }
        return cell
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }
    
    //MARK: - Send data related functions 
    
    /**
    Automaton controlling the transmission
    */
    func sendData() {
        if safeExecution == true
        {
            safeExecution = false
            
            switch state
            {
            case STATE_CONFIGURING_CONNECTION:
                writeData(TPC.getConfigurationPackage())
                
            case STATE_SENDING_FIRST_FRAGMENT:
                transmissionWindow = TPC.getNormalPackage()
                writeData(transmissionWindow.removeAtIndex(0))
                
                if count(transmissionWindow) > 0
                {
                    state = STATE_SENDING_FRAGMENTS
                }
                
            case STATE_SENDING_FRAGMENTS:
                writeData(transmissionWindow.removeAtIndex(0))
                if count(transmissionWindow) == 0
                {
                    state = STATE_SENDING_FIRST_FRAGMENT
                }
                
            default:
                println("--sendData--\nState not known (error)")
                NSException(name: "Error", reason: "State not found in sendData()", userInfo: nil).raise()
            }
            
            safeExecution = true
        }
        tableView.reloadData()
    }
    
    /**
    Function to send a string
    :param: string The string to send
    */
    func writeString(string: String)
    {
        if let data = string.dataUsingEncoding(NSUTF8StringEncoding)
        {
            if selectedDevice.BLEtxCharacteristic.properties & .WriteWithoutResponse != nil
            {
                selectedDevice.peripheral.writeValue(data, forCharacteristic: selectedDevice.BLEtxCharacteristic, type: CBCharacteristicWriteType.WithoutResponse)
                
                NSLog("--writeString--\nData sent (without response):\n=>" + string + "<=")
            } else if selectedDevice.BLEtxCharacteristic.properties & .Write != nil
            {
                selectedDevice.peripheral.writeValue(data, forCharacteristic: selectedDevice.BLEtxCharacteristic, type: CBCharacteristicWriteType.WithResponse)
                
                NSLog("--writeString--\nData sent (with response):\n=>" + string + "<=")
                
            } else
            {
                println("--writeString--\nNo write property found on TX characteristics: \(selectedDevice.BLEtxCharacteristic.properties)")
            }
        }
    }
    
    /**
    Function to send and array of bytes
    :param: data The NSData to send
    */
    func writeData(data: NSData?)
    {
        if data != nil
        {
            if selectedDevice.BLEtxCharacteristic.properties & .WriteWithoutResponse != nil
            {
                selectedDevice.peripheral.writeValue(data!, forCharacteristic: selectedDevice.BLEtxCharacteristic, type: CBCharacteristicWriteType.WithoutResponse)
                
                NSLog("--writeString--\nData sent (without response):\n=>\(data)<=")
            } else if selectedDevice.BLEtxCharacteristic.properties & .Write != nil
            {
                selectedDevice.peripheral.writeValue(data!, forCharacteristic: selectedDevice.BLEtxCharacteristic, type: CBCharacteristicWriteType.WithResponse)
                
                NSLog("--writeString--\nData sent (without response):\n=>\(data)<=")
            } else
            {
                println("--writeString--\nNo write property found on TX characteristics: \(selectedDevice.BLEtxCharacteristic.properties)")
            }
        }
    }
    
    //MARK - BLE related
    
    /**
    Get data values when they are updated. Receive information sended from the arduino
    :param: peripheral     Peripheral description
    :param: characteristic Characteristic description
    :param: error          Error description
    */
    func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        if (error != nil)
        {
            println("--peripheral didUpdateValueForCharacteristic--\nError while receiving data:")
            println(error)
            
            let alertController = UIAlertController(title: "Error while receiving data", message:
                nil, preferredStyle: UIAlertControllerStyle.Alert)
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default,handler: nil))
        }
        else if characteristic.UUID == selectedDevice.BLErxCharacteristic.UUID {
            
            let receivedData : NSData = characteristic.value
            
            println("--peripheral didUpdateValueForCharacteristic--\nReceived string:\n=>\(receivedData)<=")

            whatchdog.invalidate()
            whatchdog = NSTimer.scheduledTimerWithTimeInterval(whatchdogInterval, target: self, selector: "communicationError", userInfo: nil, repeats: false)
            
            switch state
            {
            case STATE_CONFIGURING_CONNECTION:
                if let receivedString = NSString(data: receivedData, encoding: NSUTF8StringEncoding) as? String
                {
                    if receivedString == "OK_CF"
                    {
                        state = STATE_SENDING_FIRST_FRAGMENT
                        println("--peripheral didUpdateValueForCharacteristic--\nFINISHED CONFIGURATION")
                    }
                }
            
            default:
                let receivedPackagesInt16 = UnsafePointer<Int16>(receivedData.bytes)
                
                if receivedPackagesInt16 != nil
                {
                    println("Confirm packages:\n=>\(Double(receivedPackagesInt16.memory))<=")
                    calculateConnectionHealth(Double(receivedPackagesInt16.memory))
                }
                else
                {
                    calculateConnectionHealth(0)
                }
            }
        }
    }

    /**
    Calculate a value to show to the user that indicates the health of the connection approximately
    :param: receivedPackages The number received from the arduino indicatting the amount of packages correctly received
    */
    func calculateConnectionHealth(receivedPackages : Double) {
        let connectionHealthTemp = receivedPackages/Double(TPC.baudrate)
        
        if !(connectionHealthTemp <= 1) || !(connectionHealthTemp >= 0)
        {
            connectionHealth = 1
        }
        else
        {
            connectionHealth = connectionHealthTemp
        }
    }
    
    //MARK: - Stop/start button delegate
    
    /**
    Caller for the start/stop button
    :param: sender the button
    */
    @IBAction func startStopButtonTouched(sender: UIBarButtonItem)
    {
        if sender.title == "Start"
        {
            startTransmission()
            sender.title = "Stop"
        }
        else
        {
            stopTransmission()
            sender.title = "Start"
        }
    }

    //MARK: - Stop/start transmission

    /**
    Stop the transmission
    */
    func stopTransmission()
    {
        if timer.valid
        {
            state = STATE_CONFIGURING_CONNECTION
            
            selectedDevice.peripheral.delegate = previousVC
            
            timer.invalidate()
            whatchdog.invalidate()
            
            motionManagerController.stopSensors()
            println("--viewWillDisappear, stopTransmission--\n--TRANSMISSION STOPPED--\n")
        }
    }
    
    /**
    Start the transmission
    */
    func startTransmission()
    {
        if timer == nil || !timer.valid
        {
            selectedDevice.peripheral.delegate = self
            
            let piecesTmp = TPC.calculatePieces()
            if piecesTmp > 1
            {
                transmissionPeriod = 1/(Double(TPC.baudrate)*Double(piecesTmp))
            }
            else
            {
                transmissionPeriod = 1/Double(TPC.baudrate)
            }
            
            motionManagerController = CMMotionManagerController(TPC: TPC)
            motionManagerController.startSensors(transmissionPeriod)
            
            timer = NSTimer.scheduledTimerWithTimeInterval(transmissionPeriod, target: self, selector: "sendData", userInfo: nil, repeats: true)
            
            whatchdog = NSTimer.scheduledTimerWithTimeInterval(whatchdogInterval, target: self, selector: "communicationError", userInfo: nil, repeats: false)
            
            println("--viewDidLoad, startTransmission--\n--TRANSMISSION STARTED--\n")
        }
    }
    
    //MARK: - Whatchdog
    
    /**
    Gets called when the watchdog reaches the end, raising an alert to the user and returning to the previous controller
    */
    func communicationError() {
        let alertController = UIAlertController(title: "Error in the communication", message:
            "Something happened while transmitting: arduino is not responding. If you can not fix this issue try to reset the arduino and restart the iPhone", preferredStyle: UIAlertControllerStyle.Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default,handler: nil))
        
        self.navigationController?.popViewControllerAnimated(true)
        previousVC.presentViewController(alertController, animated: true, completion: nil)
    }
}

