//
//  TransmissionParametersController.swift
//  DTUSensors4
//
//  Created by Andres on 12/5/15.
//  Copyright (c) 2015 Andres. All rights reserved.
//

/*
Conf Package:

Added CF before the header in order to identify it easily (2 bytes)
Added first byte after CF indicatting number of fragments (1 byte - 255 fragments maximum)

Next bytes in groups of 2:
1nd byte indicates the number of parameters (max 255)
2nd byte indicates the length of the parameters (max 255)

Max size of conf package = 18 bytes (maximum allowed by the standard is 20 bytes)
*/

/*
Normal Package:
1st byte indicates the index of the package (255 maximum)
Next bytes have the data to transmit
*/

import Foundation

/**
*  Class to manage, access and store the information of the sensors
*/
class TransmissionParametersController: NSObject {
    /// Baudrate selected by the user
    var baudrate : Int
    
    /// Array of pointers to all the sensors
    var sensors : [CustomSensorsObject]
    
    /// AC sensor
    var AC : CustomSensorsObject
    
    /// GPS sensor
    var GPS : CustomSensorsObject
    
    /// Gyroscope sensor
    var GCP : CustomSensorsObject
    
    /**
    Initialize the baudrate and value for the sensors with the default data
    */
    override init ()
    {
        self.baudrate = 1
        self.AC = CustomSensorsObject(name: "AC", state: true, numberOfParameters: 3, lengthOfParameter: 2, maxValueOfParameter: 3.0)
        self.GPS = CustomSensorsObject(name: "GPS", state: true, numberOfParameters: 3, lengthOfParameter: 2, maxValueOfParameter: 100)
        self.GCP = CustomSensorsObject(name: "GCP", state: true, numberOfParameters: 3, lengthOfParameter: 2, maxValueOfParameter: 6.28)
        
        self.sensors = [
            self.AC,
            self.GPS,
            self.GCP
        ]
    }
    
    // MARK: - Permanent data related
    
    /**
    Safe baudrate and sensors information to keep it after app exits
    */
    func safeTPC()
    {
        let defaults = NSUserDefaults.standardUserDefaults()
        
        defaults.setObject(baudrate, forKey: "baudrate")
        
        var ACData : NSData = NSKeyedArchiver.archivedDataWithRootObject(AC)
        defaults.setObject(ACData, forKey: "AC")
        
        var GPSData : NSData = NSKeyedArchiver.archivedDataWithRootObject(GPS)
        defaults.setObject(GPSData, forKey: "GPS")
        
        var GCPData : NSData = NSKeyedArchiver.archivedDataWithRootObject(GCP)
        defaults.setObject(GCPData, forKey: "GCP")
    }
    
    /**
    Retrieve baudrate and sensors information at startup
    */
    func retrieveTPC() -> Bool
    {
        var retrieveOK = true
        
        let defaults = NSUserDefaults.standardUserDefaults()
        
        if let baudrate = defaults.objectForKey("baudrate") as? Int {
            self.baudrate = baudrate
        } else {
            retrieveOK = false
        }
        
        if let ACData = defaults.objectForKey("AC") as? NSData {
            if let AC : CustomSensorsObject = NSKeyedUnarchiver.unarchiveObjectWithData(ACData) as? CustomSensorsObject{
                self.AC = AC
            } else {
                retrieveOK = false
            }
        } else {
            retrieveOK = false
        }
        
        if let GPSData = defaults.objectForKey("GPS") as? NSData {
            if let GPS : CustomSensorsObject = NSKeyedUnarchiver.unarchiveObjectWithData(GPSData) as? CustomSensorsObject{
                self.GPS = GPS
            } else {
                retrieveOK = false
            }
        } else {
            retrieveOK = false
        }
        
        if let GCPData = defaults.objectForKey("GCP") as? NSData {
            if let GCP : CustomSensorsObject = NSKeyedUnarchiver.unarchiveObjectWithData(GCPData) as? CustomSensorsObject{
                self.GCP = GCP
            } else {
                retrieveOK = false
            }
        } else {
            retrieveOK = false
        }
        
        if retrieveOK == true {
            self.sensors = [
                self.AC,
                self.GPS,
                self.GCP
            ]
        } else {
            let appDomain = NSBundle.mainBundle().bundleIdentifier!
            NSUserDefaults.standardUserDefaults().removePersistentDomainForName(appDomain)
        }
        
        return retrieveOK
    }
    
    // MARK: - Packages
    
    /**
    Creates the package to be send in the configuration state of the transmission
    :returns: An NSData object with the information
    */
    func getConfigurationPackage() -> NSData
    {
        var package : NSMutableData = "CF".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!.mutableCopy() as! NSMutableData
        
        var pieces : UInt8 = self.calculatePieces()
        package.appendBytes(&pieces, length: 1)
        
        for sensor in sensors
        {
            if sensor.state == true
            {
                package.appendBytes(&sensor.numberOfParameters, length: 1)
                package.appendBytes(&sensor.lengthOfParameter, length: 1)
            }
        }
        
        return NSData(data: package)
    }
    
    /**
    Creates the package to be send when transmitting data
    :returns: An NSData aray with the information devided in groups of 20 bytes maximum
    */
    func getNormalPackage() -> [NSData]
    {
        var package = NSMutableData()
        
        for sensor in sensors
        {
            if sensor.state == true
            {
                for parameter in sensor.parameters
                {
                    package.appendData(parameter)
                }
            }
        }

        var pieces : UInt8 = 0
        var returnArray = [NSData]()
        var tempData = NSMutableData()
        
        do
        {
            tempData.appendBytes(&pieces, length: 1)
            if (Int(pieces)+1)*19 <= package.length
            {
                tempData.appendData(package.subdataWithRange(NSMakeRange(Int(pieces)*19, 19)))
            }
            else if (package.length > 0)
            {
                tempData.appendData(package.subdataWithRange(NSMakeRange(Int(pieces)*19, package.length-Int(pieces)*19)))
            }

            returnArray.append(NSData(data: tempData))
            tempData = NSMutableData()
            pieces++
        }while(package.length > Int(pieces)*19)
        
        let length : Int
        if returnArray.count > 0
        {
            length = (returnArray.count-1)*20 + (returnArray[returnArray.count-1] as NSData).length
        }
        else
        {
            length = 0
        }
        
        if length != calculateLength()
        {
            NSException(name: "Error", reason: "Precalculated package size is not the real package size.\ntempData.length=\(length) and calculateLength()=\(calculateLength())", userInfo: nil).raise()
        }
        
        return returnArray
    }
    
    /**
    Calculates the expected length of the package
    :returns: The expected length
    */
    func calculateLength() -> Int
    {
        var lengthOfStringToSend = 0
        
        for sensor in sensors
        {
            if sensor.state == true
            {
                lengthOfStringToSend += Int(sensor.numberOfParameters) * Int(sensor.lengthOfParameter)
            }
        }
        
        //Add size of the headers deppending on how many pieces has the package to send
        let pieces : Int
        if lengthOfStringToSend%19 > 0 || lengthOfStringToSend == 0
        {
            pieces = lengthOfStringToSend/19 + 1
        }
        else
        {
            pieces = lengthOfStringToSend/19
        }
        
        lengthOfStringToSend += pieces
        
        return lengthOfStringToSend
    }
    
    /**
    Calculates the fragments of the package based on its length
    :returns: An Uint8 with the value (255 maximum)
    */
    func calculatePieces() -> UInt8
    {
        let lengthOfStringToSend = calculateLength()
        let pieces : Int
        
        if lengthOfStringToSend%20 > 0 || lengthOfStringToSend == 0
        {
            pieces = lengthOfStringToSend/20 + 1
        }
        else
        {
            pieces = lengthOfStringToSend/20
        }
        
        let piecesuInt: UInt8 = UInt8(pieces)
        return piecesuInt
    }
}

