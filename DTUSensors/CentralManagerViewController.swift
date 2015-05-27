//
//  ConnectionViewController.swift
//  DTUSensors3
//
//  Created by Andres on 18/3/15.
//  Copyright (c) 2015 Andres. All rights reserved.
//

import UIKit
import CoreBluetooth

/**
*  The controller in charge of the central manager: explore devices and show them in a list
*/
class CentralManagerViewController: UITableViewController, CBCentralManagerDelegate {
    
    /// An array with the discovered peripherals
    var peripherals = [CustomPeripheralObject]()
    
    /// The BLE central manager object
    var centralManager : CBCentralManager!
    
    // MARK: - Functions related with the viewController
    
    /**
    Initialize the central manager after the view is loaded
    */
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        // Initialize central manager
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - IBActions
    
    /**
    Action for the right navigation button: refresh the detected BLE devices around
    :param: sender The button
    */
    @IBAction func refreshDevices(sender: UIBarButtonItem) {
        peripherals.removeAll(keepCapacity: false)
        tableView.reloadData()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    /**
    Erase NSUserDefaults data
    :param: sender The button
    */
    @IBAction func removePermanentData(sender: UIBarButtonItem) {
        if let appDomain = NSBundle.mainBundle().bundleIdentifier
        {
            NSUserDefaults.standardUserDefaults().removePersistentDomainForName(appDomain)
        }
    }
    
    // MARK: - Segues
    
    /**
    When the BLE peripheral is selected from the list changes to the next viewController
    :param: segue  segue to the next view
    :param: sender sender
    */
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showPeripheral" {
            if let indexPath = self.tableView.indexPathForSelectedRow() {
                
                // Stop scanning
                self.centralManager.stopScan()
                
                //Next view
                if let controller = segue.destinationViewController as? PeripheralViewController
                {
                    // Set as the peripheral to use and establish connection
                    controller.selectedDevice = peripherals[indexPath.row]
                    controller.selectedDevice.peripheral.delegate = controller
                    controller.previousVC = self
                    
                    self.centralManager.connectPeripheral(peripherals[indexPath.row].peripheral, options: nil)
                }
            }
        }
    }
    
    // MARK: - TableView delegate

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as! UITableViewCell
        
        if let objectName = (peripherals[indexPath.row].advertisementData as NSDictionary).objectForKey(CBAdvertisementDataLocalNameKey) as? String
        {
            cell.textLabel!.text = "Device name: " + objectName
        }
        else
        {
            cell.textLabel!.text = "Device name: unknown"
        }
        
        return cell
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }
    
    // MARK: - BLE related

    /**
    Detect a new peripheral and discover its services
    :param: central    Central manager
    :param: peripheral Peripheral description
    */
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        peripheral.discoverServices(nil)
        println("--centralManager didConnectPeripheral--\nConnected to new peripheral")
    }
    
    /**
    Check status of BLE hardware, basically controlling if bluetooth is activated
    :param: central central manager
    */
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        if central.state == CBCentralManagerState.PoweredOn {
            // Scan for peripherals if BLE is turned on
            central.scanForPeripheralsWithServices(nil, options: nil)
            println("--centralManager didUpdateState--\nBLE is turned on. Next step: search for BLE Devices")
        }
        else {
            // Can have different conditions for all states if needed - print generic message for now
            println("--centralManager didUpdateState--\nBluetooth switched off or not initialized")
            
            let alertController = UIAlertController(title: "Bluetooth switched off or not initialized", message:
                "Something happened while starting Bluetooth: maybe you need to turn it on?", preferredStyle: UIAlertControllerStyle.Alert)
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default,handler: nil))
            
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    /**
    Check the discovered peripherals, check their name (or give then one if they do not have it) and add them to the table
    :param: central           central manager
    :param: peripheral        peripheral description
    :param: advertisementData advertisementData description
    :param: RSSI              RSSI
    */
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        
        //Save all the information about the device in order to use it when the user selects it from the table
        var device = CustomPeripheralObject()
        device.peripheral = peripheral
        device.advertisementData = advertisementData
        device.RSSI = RSSI
        
        peripherals.insert(device, atIndex: 0)
        
        let indexPath = NSIndexPath(forRow: 0, inSection: 0)
        self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
  
        if let objectName = (peripherals[indexPath.row].advertisementData as NSDictionary).objectForKey(CBAdvertisementDataLocalNameKey) as? String
        {
            println("--centralManager didDiscoverPeripheral--\n" + "Device name: " + objectName)
        }
        else
        {
            println("--centralManager didDiscoverPeripheral--\n" + "Device name: unknown")
        }
    }
    
    /**
    If disconnected remove the device from the table and start searching for BLE devices again
    :param: central    central manager
    :param: peripheral peripheral description
    :param: error      error description
    */
    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        central.scanForPeripheralsWithServices(nil, options: nil)
        
        var index : Int = 0
        for index = 0; index < peripherals.count; index++
        {
            if (peripherals[index].peripheral == peripheral)
            {
                break;
            }
        }
        
        peripherals.removeAtIndex(index)
        tableView.reloadData()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        println("--centralManager didDisconnectPeripheral--\nDisconnected from peripheral")
    }

}
