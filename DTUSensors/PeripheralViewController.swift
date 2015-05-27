//
//  MasterViewController.swift
//  DTUSensors3
//
//  Created by Andres on 18/3/15.
//  Copyright (c) 2015 Andres. All rights reserved.
//

import UIKit
import CoreBluetooth

/**
*  Controller for the peripheral view
*/
class PeripheralViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CBPeripheralDelegate {
    
    /// Previous controller (centralManager). Used to go back when the watchdog finishes
    var previousVC : CentralManagerViewController!
    
    /// Object that stores all the information related with the sensors, baudrate...
    var TPC = TransmissionParametersController()
    
    /// Texfield to set the baudrate value
    @IBOutlet weak var textFieldBaudrate: UITextField!
    
    /// Slider to set the baudrate value
    @IBOutlet weak var sliderBaudrate: UISlider!
    
    /// Table with the sensors
    @IBOutlet weak var tableView: UITableView!
    
    /// Object that stores the information of the BLE device selected
    var selectedDevice : CustomPeripheralObject!
    
    /// Identifier of the services of the BLE device (specific for adafruit BLE device nRF8001)
    let BLEServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    
    /// Identifier of the tx characteristic of the BLE device (specific for adafruit BLE device nRF8001)
    let BLEtxUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    
    /// Identifier of the rx characteristic of the BLE device (specific for adafruit BLE device nRF8001)
    let BLErxUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    
    /// Whatchdog that limits the time used for get the services of the BLE device (tell you to choose other device if the chosen one is not the expected one)
    var whatchdog : NSTimer!
    
    // MARK: - Functions related with the viewController
    
    /**
    Reloads table and configurates the cell selected
    :param: animated
    */
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.reloadData()
        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow()
        {
            tableView.deselectRowAtIndexPath(indexPathForSelectedRow, animated: true)
        }
    }
    
    /**
    Invalidate watchdog to avoid getting the alert out of the viewController
    :param: animated
    */
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        whatchdog.invalidate()
    }

    /**
    Loads TransmissionParametersController from NSUserDefaults, enables watchdog
    */
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        TPC.retrieveTPC()
        
        textFieldBaudrate.text = "\(TPC.baudrate)"
        sliderBaudrate.value = Float(TPC.baudrate)

        if let startButton = self.navigationItem.rightBarButtonItem
        {
            startButton.enabled = false
        }
        
        whatchdog = NSTimer.scheduledTimerWithTimeInterval(3, target: self, selector: "communicationError", userInfo: nil, repeats: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Whatchdog related
    
    /**
    Gets called when the watchdog reaches the end, raising an alert to the user and returning to the previous controller
    */
    func communicationError()
    {
        let alertController = UIAlertController(title: "Error in the communication", message:
            "Something happened while initiating the communication with the arduino. If you can not fix this issue try to reset the arduino and restart the iPhone", preferredStyle: UIAlertControllerStyle.Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default,handler: nil))
        
        self.navigationController?.popViewControllerAnimated(true)
        previousVC.presentViewController(alertController, animated: true, completion: nil)
    }

    // MARK: - Segues

    /**
    Manages the movements to other controllers
    :param: segue  The corresponding segue
    :param: sender The sender
    */
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetailAC" {
            if let indexPath = self.tableView.indexPathForSelectedRow() {
                if let controller = segue.destinationViewController as? ACDetailViewController
                {
                    controller.sensor = TPC.sensors[indexPath.row]
                }
            }
        }else if segue.identifier == "showDetailGPS" {
            if let indexPath = self.tableView.indexPathForSelectedRow() {
                if let controller = segue.destinationViewController as? GPSDetailViewController
                {
                    controller.sensor = TPC.sensors[indexPath.row]
                }
            }
        }else if segue.identifier == "showDetailGCP" {
            if let indexPath = self.tableView.indexPathForSelectedRow() {
                if let controller = segue.destinationViewController as? GCPDetailViewController
                {
                    controller.sensor = TPC.sensors[indexPath.row]
                }
            }
        }else if segue.identifier == "startTransmision" {
            TPC.baudrate = Int(round(sliderBaudrate.value))
            
            TPC.safeTPC()
            
            //Prepare next view
            if let controller = segue.destinationViewController as? TransmisionViewController
            {
                controller.selectedDevice = selectedDevice
                controller.previousVC = self
                controller.TPC = TPC
            }
            
            println("The baudrate for the communications is: \(TPC.baudrate)\n")
        }
    }

    // MARK: - TableView delegate

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return TPC.sensors.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as! UITableViewCell
        
        if let label = cell.contentView.viewWithTag(51) as? UILabel
        {
            label.text = TPC.sensors[indexPath.row].name
        }
        
        if let switchObject = cell.contentView.viewWithTag(52) as? UISwitch
        {
            switchObject.on = TPC.sensors[indexPath.row].state
        }
        
        if let segmentedControl = cell.contentView.viewWithTag(53) as? UISegmentedControl
        {
            segmentedControl.setTitle("Parameters=\(TPC.sensors[indexPath.row].numberOfParameters)", forSegmentAtIndex: 0)
            segmentedControl.setTitle("Size=\(TPC.sensors[indexPath.row].lengthOfParameter) bytes", forSegmentAtIndex: 1)
        }
        
        return cell
    }

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.performSegueWithIdentifier("showDetail\(TPC.sensors[indexPath.row].name)", sender: self)
    }

    
    // MARK: - BLE related
    
    /**
    Looks for the service inside adafruit BLE device
    :param: peripheral The peripheral
    :param: error      Error description
    */
    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        for service in peripheral.services {
            if let thisService = service as? CBService
            {
                // List of UUIDs related with services
                println("--peripheral didDiscoverServices--\nService:")
                println(thisService)
                
                if service.UUID == BLEServiceUUID {
                    // Discover characteristics of service
                    peripheral.discoverCharacteristics(nil, forService: thisService)
                }
            }
        }
    }
    
    /**
    Discovers the characteristics of the service and looks for rx and tx characteristics presented in adafruit BLE device. if they are correct it invalidates the watchdog, allowing the user start the transmission
    :param: peripheral The peripheral
    :param: service    Service description
    :param: error      Error description
    */
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        
        println("--peripheral didDiscoverCharacteristicsForService--\nService:")
        println(service)
        println("Characteristics:")
        
        // check the uuid of each characteristic to find tx and rx
        for charateristic in service.characteristics {
            let thisCharacteristic = charateristic as! CBCharacteristic
            println(thisCharacteristic)
            
            // check for tx characteristic
            if thisCharacteristic.UUID == BLEtxUUID {
                selectedDevice.BLEtxCharacteristic = thisCharacteristic
            }
            
            // check for rx characteristic
            if thisCharacteristic.UUID == BLErxUUID {
                selectedDevice.BLErxCharacteristic = thisCharacteristic
                selectedDevice.peripheral.setNotifyValue(true, forCharacteristic: thisCharacteristic)
            }
        }
        
        if selectedDevice.BLEtxCharacteristic != nil && selectedDevice.BLErxCharacteristic != nil
        {
            //We enable the button to transmit after the characteristics have been found
            if let startButton = self.navigationItem.rightBarButtonItem
            {
                startButton.enabled = true
            }
            
            whatchdog.invalidate()
        }
    }
    
    // MARK: - IBActions
    
    /**
    Manages changes in the switches that controls which sensors are enabled for transmission
    :param: sender The switch
    */
    @IBAction func swithValueChanged(sender: UISwitch)
    {
        if let cell = sender.superview?.superview as? UITableViewCell
        {
            let indexPath = self.tableView.indexPathForCell(cell)
            if let row = indexPath?.row
            {
                TPC.sensors[row].state = sender.on
            }
        }
    }
    
    /**
    Manages changes in the value of the slider that controls the baudrate value
    :param: sender The slider
    */
    @IBAction func sliderBaudrateValueChanged(sender: AnyObject) {
        textFieldBaudrate.text = "\(Int(round(sliderBaudrate.value)))"
        sliderBaudrate.value = round(sliderBaudrate.value)
    }
    
    /**
    Gets called when user finish editing the text field corresponding to tha baudrate
    :param: sender The textField
    */
    @IBAction func textFieldBaudrateEditingDidEnd(sender: AnyObject) {
        textFieldBaudrateEnd()
    }
    
    /**
    Synchronize the values shown in the textfield and in the slider
    */
    func textFieldBaudrateEnd ()
    {
        let futureValue = NSNumberFormatter().numberFromString(textFieldBaudrate.text)
        
        if futureValue != nil && sliderBaudrate.minimumValue <= futureValue!.floatValue &&  futureValue!.floatValue <= sliderBaudrate.maximumValue
        {
            sliderBaudrate.value = futureValue!.floatValue
        }
        else
        {
            textFieldBaudrate.text = "\(Int(round(sliderBaudrate.value)))"
        }
    }
    
    /**
    Asks the delegate if the text field should process the pressing of the return button
    :param: textField The textField
    :returns: The answer
    */
    func textFieldShouldReturn(textField: UITextField) -> Bool
    {
        textField.resignFirstResponder()
        
        if(textField == textFieldBaudrate)
        {
            textFieldBaudrateEnd()
        }
        return false
    }
}

