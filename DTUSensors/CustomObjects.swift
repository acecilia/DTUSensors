//
//  PeripheralDataType.swift
//  DTUSensors3
//
//  Created by Andres on 10/4/15.
//  Copyright (c) 2015 Andres. All rights reserved.
//

import CoreBluetooth

/**
*  Class to save the peripheral information
*/
class CustomPeripheralObject: NSObject {
    /// The peripheral
    var peripheral : CBPeripheral!
    
    /// The advertisementData
    var advertisementData : [NSObject : AnyObject]!
    
    /// The RSSI
    var RSSI: NSNumber!
    
    /// The BLEtxCharacteristic
    var BLEtxCharacteristic : CBCharacteristic!
    
    /// The BLErxCharacteristic
    var BLErxCharacteristic : CBCharacteristic!
}

/**
*  Class to save the sensor information
*/
class CustomSensorsObject: NSObject, NSCoding {
    /// Name of the sensor
    var name : String
    
    /// State: enabled or disabled
    var state : Bool
    
    /// Number of parameters to be sent
    var numberOfParameters : UInt8
    
    /// Length of the paramaters
    var lengthOfParameter : UInt8
    
    /// Maximum value expected from the sensor
    var maxValueOfParameter : Double
    
    /// Data obtained from the sensor (to be sent after)
    var parameters : [NSData]
    
    /// String with the values obtained from the sensors
    var realDataDescrition : [Double]
    
    /// String with the values sent
    var scaledDataDescrition : [Int]
    
    /**
    Init the sensor
    :param: name                Name of the sensor
    :param: binaryName          Binary name to be send in the configuration package
    :param: state               State: enabled or disabled
    :param: numberOfParameters  Number of parameters to be sent
    :param: lengthOfParameter   Length of the paramaters
    :param: maxValueOfParameter Maximum value expected from the sensor
    :returns: An initialized sensor
    */
    init (name : String, state : Bool, numberOfParameters : UInt8, lengthOfParameter : UInt8, maxValueOfParameter : Double)
    {
        self.name = name
        self.state = state
        self.numberOfParameters = numberOfParameters
        self.lengthOfParameter = lengthOfParameter
        self.maxValueOfParameter = maxValueOfParameter
        self.parameters = []
        self.realDataDescrition = []
        self.scaledDataDescrition = []
    }
    
    // MARK: save data
    
    /**
    Init when we get the init values from standardUserDefaults
    :param: aDecoder aDecoder description
    */
    required init(coder aDecoder: NSCoder) {
        self.name  = aDecoder.decodeObjectForKey("name") as! String
        self.state  = aDecoder.decodeObjectForKey("state") as! Bool
        self.numberOfParameters  = UInt8(aDecoder.decodeObjectForKey("numberOfParameters") as! Int)
        self.lengthOfParameter  = UInt8(aDecoder.decodeObjectForKey("lengthOfParameter") as! Int)
        self.maxValueOfParameter  = aDecoder.decodeObjectForKey("maxValueOfParameter") as! Double
        self.parameters = []
        self.realDataDescrition = []
        self.scaledDataDescrition = []
    }
    
    /**
    Encoder when we safe the values to standardUserDefaults
    :param: aCoder aDecoder description
    */
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(name, forKey: "name")
        aCoder.encodeObject(state, forKey: "state")
        aCoder.encodeObject(Int(numberOfParameters), forKey: "numberOfParameters")
        aCoder.encodeObject(Int(lengthOfParameter), forKey: "lengthOfParameter")
        aCoder.encodeObject(maxValueOfParameter, forKey: "maxValueOfParameter")
    }
}