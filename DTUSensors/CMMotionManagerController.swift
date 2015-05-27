//
//  CMMotionManager.swift
//  DTUSensors3
//
//  Created by Andres on 3/5/15.
//  Copyright (c) 2015 Andres. All rights reserved.
//

import UIKit
import CoreMotion
import CoreLocation

/**
*  CMMotionManagerController class to manage the sensors
*/
class CMMotionManagerController: NSObject, CLLocationManagerDelegate {
    
    /// The CMMotionManager object needed for some sensors
    let motionManager = CMMotionManager()
    
    /// The CLLocationManager object needed for some localization
    var locationManager : CLLocationManager?
    
    /// Object that stores all the information related with the sensors, baudrate...
    var TPC : TransmissionParametersController
    
    /**
    Custom init function
    :param: TPC Object that stores all the information related with the sensors, baudrate...
    */
    init (TPC : TransmissionParametersController)
    {
        self.TPC = TPC
    }
    
    // MARK: START/STOP sensors
    
    /**
    Initialize all sensors
    :param: updateInterval Refresh interval
    */
    func startSensors(updateInterval : NSTimeInterval!) {
        if TPC.AC.state
        {
            startAccelerometer(updateInterval)
        }
        
        if TPC.GPS.state
        {
            startLocation()
        }
        
        if TPC.GCP.state
        {
            startGyroscope(updateInterval)
        }
    }
    
    /**
    Stop all sensors
    */
    func stopSensors() {
        if TPC.AC.state
        {
            stopAccelerometer()
        }
        
        if TPC.GPS.state
        {
            stopLocation()
        }
        
        if TPC.GCP.state
        {
            stopGyroscope()
        }
    }
    
    // MARK: Data conversion
    
    /**
    Convert an scaled value to NSData in order to send it
    :param: valueScaled The scaled value from the sensors
    :param: bytes       Number of bytes available to scale the value
    :returns: An NSData object with the length specified in "bytes" that has an scaled value of the data from the sensor
    */
    func convertValueToData(valueScaled: Int, bytes: UInt8) -> NSData
    {
        var returnData : NSData
        
        switch bytes
        {
        case 1:
            var bytes = Int8(valueScaled)
            returnData = NSData(bytes: &bytes, length: 1)
            
        case 2:
            var bytes = Int16(valueScaled)
            returnData = NSData(bytes: &bytes, length: 2)
            
        case 4:
            var bytes = Int32(valueScaled)
            returnData = NSData(bytes: &bytes, length: 4)
            
        default:
            returnData = NSData(bytes: [0,0,0,0], length: 4)
            NSException(name: "Error", reason: "Value for the number of bytes not correct", userInfo: nil).raise()
        }
        return returnData
    }
    
    /**
    Scale a value in order to get the maximum precission with the available number of bytes
    :param: value Number to convert
    :param: max   Maximum value expected from the sensor
    :param: bytes Number of bytes available to scale the value
    :returns: An scaled value
    */
    func scaleValue(value: Double, max: Double, bytes: UInt8) -> Int
    {
        var returnValue : Double = 0

        if abs(value) <= max
        {
            returnValue = (value/max)*(pow(Double(2), Double(8*bytes))/2-1)
        }
        else if value > max
        {
            returnValue = (1)*(pow(Double(2), Double(8*bytes))/2-1)
        }
        else if value < max*(-1)
        {
            returnValue = (-1)*(pow(Double(2), Double(8*bytes))/2-1)
        }
        
        return Int(returnValue)
    }
    
    /**
    Set the sensor values for showing them in the transmission view (realData), the scaled values (integers) and the data to be sent (NSData)
    :param: sensor     The sensor to set the information
    :param: parameters The values obtained from the sensor
    :param: max        The maximum values. Used for the scaleValue() function
    */
    func setValues(sensor : CustomSensorsObject, parameters : [Double], max : [Double])
    {
        for var i = 0; i<count(parameters); i++
        {
            if sensor.realDataDescrition.count >= i+1
            {
                sensor.realDataDescrition[i] = parameters[i]
            }
            else
            {
                sensor.realDataDescrition.append(parameters[i])
            }
            
            let paramScaled = scaleValue(parameters[i], max: max[i], bytes: sensor.lengthOfParameter)
            if sensor.scaledDataDescrition.count >= i+1
            {
                sensor.scaledDataDescrition[i] = paramScaled
            }
            else
            {
                sensor.scaledDataDescrition.append(paramScaled)
            }
            
            let paramData = convertValueToData(paramScaled, bytes: sensor.lengthOfParameter)
            if sensor.parameters.count >= i+1
            {
                sensor.parameters[i] = paramData
            }
            else
            {
                sensor.parameters.append(paramData)
            }
        }
    }
    
    // MARK: Accelerometer related
    
    /**
    Start the accelerometer
    :param: updateInterval Refresh interval
    */
    func startAccelerometer(updateInterval : NSTimeInterval!)
    {
        motionManager.accelerometerUpdateInterval = updateInterval
        
        setValues(TPC.AC, parameters: [0, 0, 0], max: [TPC.AC.maxValueOfParameter, TPC.AC.maxValueOfParameter, TPC.AC.maxValueOfParameter])
        
        self.motionManager.startAccelerometerUpdatesToQueue(NSOperationQueue(), withHandler: {
            (data: CMAccelerometerData!, error: NSError!) in
            
            dispatch_async(dispatch_get_main_queue()) {
                
                self.setValues(self.TPC.AC, parameters: [data.acceleration.x, data.acceleration.y, data.acceleration.z], max: [self.TPC.AC.maxValueOfParameter, self.TPC.AC.maxValueOfParameter, self.TPC.AC.maxValueOfParameter])
                
                println("--getAccelerometerData--\n--Accelerometer data received:\n")
                println("X: \(data.acceleration.x) ==> \(self.TPC.AC.parameters[0])--\n")
                println("Y: \(data.acceleration.y) ==> \(self.TPC.AC.parameters[1])--\n")
                println("Z: \(data.acceleration.z) ==> \(self.TPC.AC.parameters[2])--\n")
            }
        })
    }
    
    /**
    Stop the accelerometer
    */
    func stopAccelerometer()
    {
        if motionManager.accelerometerActive == true
        {
            motionManager.stopAccelerometerUpdates()
        }
    }
    
    // MARK: GPS related
    
    /**
    Start GPS
    */
    func startLocation()
    {
        //Range of latitude -90 to 90 => max = 90
        //Range of longitude -180 to 180 => max = 180
        setValues(TPC.GPS, parameters: [0, 0, 0], max: [90, 180, self.TPC.GPS.maxValueOfParameter])
        
        let status = CLLocationManager.authorizationStatus()
        if status == CLAuthorizationStatus.Restricted || status == CLAuthorizationStatus.Denied
        {
            let alertController = UIAlertController(title: "The app is not allowed to fetch GPS data", message:
                "Change the privacy settings", preferredStyle: UIAlertControllerStyle.Alert)
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default,handler: nil))
        }
        else
        {
            locationManager = CLLocationManager()
            if locationManager != nil
            {
                locationManager!.delegate = self
                
                if status == CLAuthorizationStatus.NotDetermined
                {
                    locationManager!.requestAlwaysAuthorization()
                }
                
                locationManager!.desiredAccuracy = kCLLocationAccuracyBest
                locationManager!.startUpdatingLocation()
            }
        }
    }
    
    /**
    Stop GPS
    */
    func stopLocation()
    {
        if locationManager != nil
        {
            locationManager!.stopUpdatingLocation()
        }
    }
    
    /**
    Delegate that updates the location values
    :param: manager   The location manager
    :param: locations The locations
    */
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!)
    {
        //Range of latitude -90 to 90 => max = 90
        //Range of longitude -180 to 180 => max = 180
        setValues(TPC.GPS, parameters: [manager.location.coordinate.latitude, manager.location.coordinate.longitude, manager.location.altitude], max: [90, 180, self.TPC.GPS.maxValueOfParameter])
        
        println("--startLocation--\n--GPS data changed:\n")
        println("Latitude: \(manager.location.coordinate.latitude) ==> \(self.TPC.GPS.parameters[0])--\n")
        println("Longitude: \(manager.location.coordinate.longitude) ==> \(self.TPC.GPS.parameters[1])--\n")
        println("Altitude: \(manager.location.altitude) ==> \(self.TPC.GPS.parameters[2])--\n")
    }
    
    /**
    Delegate to detect error when getting the location
    :param: manager The location manager
    :param: error   The error description
    */
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!)
    {
        println("Error while updating location" + error.localizedDescription)
    }
    
    // MARK: GCP related
    
    /**
    Start gyroscope
    :param: updateInterval The interval for refresh the values
    */
    func startGyroscope(updateInterval : NSTimeInterval!)
    {
        motionManager.gyroUpdateInterval = updateInterval
        
        setValues(TPC.GCP, parameters: [0, 0, 0], max: [TPC.GCP.maxValueOfParameter, TPC.GCP.maxValueOfParameter, TPC.GCP.maxValueOfParameter])
        
        self.motionManager.startGyroUpdatesToQueue(NSOperationQueue(), withHandler: {
            (data: CMGyroData!, error: NSError!) in
            
            dispatch_async(dispatch_get_main_queue()) {
                self.setValues(self.TPC.GCP, parameters: [data.rotationRate.x, data.rotationRate.y, data.rotationRate.z], max: [self.TPC.GCP.maxValueOfParameter, self.TPC.GCP.maxValueOfParameter, self.TPC.GCP.maxValueOfParameter])

                println("--startGyroscope--\n--Gyroscope data received:\n")
                println("X: \(data.rotationRate.x) ==> \(self.TPC.GCP.parameters[0])--\n")
                println("Y: \(data.rotationRate.y) ==> \(self.TPC.GCP.parameters[1])--\n")
                println("Z: \(data.rotationRate.z) ==> \(self.TPC.GCP.parameters[2])--\n")
            }
        })
    }
    
    /**
    Stop gyroscope
    */
    func stopGyroscope()
    {
        if motionManager.gyroActive == true
        {
            motionManager.stopGyroUpdates()
        }
    }
    
}