//
//  GCPDetailViewController.swift
//  DTUSensors3
//
//  Created by Andres on 24/5/15.
//  Copyright (c) 2015 Andres. All rights reserved.
//

import UIKit

/**
*  ViewController to configure the information sent for the gyroscope
*/
class GCPDetailViewController: UIViewController {
    
    /// SegmentControl with the buttons to set the length of the parameter
    @IBOutlet weak var lengthOfParameterSegmentedControl: UISegmentedControl!
    
    /// SegmentControl with the buttons to set the max value expected in the sensor
    @IBOutlet weak var maxValueSegmentedControl: UISegmentedControl!
    
    /// Array that relates the value of the length of the parameter with the text shown in the segmentControl object
    let lengthOfParameterData : [UInt8] = [ 1, 2, 4 ]
    
    /// Array that relates the value of the maximum value expected in the sensor with the text shown in the segmentControl object
    let maxValueData : [Double] = [ 1, 3.14, 6.28, 13 ]
    
    /// The object that stores the gyroscope information
    var sensor : CustomSensorsObject!
    
    /**
    Set the value of the segmentControl objects
    */
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        if let index = find(lengthOfParameterData, sensor.lengthOfParameter)
        {
            lengthOfParameterSegmentedControl.selectedSegmentIndex = index
        }
        
        if let index = find(maxValueData, sensor.maxValueOfParameter)
        {
            maxValueSegmentedControl.selectedSegmentIndex = index
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /**
    Synchronize the value of the segmentControl objects with the value of the TransmissionParametersController object
    :param: sender The segmentControl object
    */
    @IBAction func segmentedControlValueChanged(sender: UISegmentedControl) {
        if sender == lengthOfParameterSegmentedControl
        {
            sensor.lengthOfParameter = lengthOfParameterData[sender.selectedSegmentIndex]
        }
        else if sender == maxValueSegmentedControl
        {
            sensor.maxValueOfParameter = maxValueData[sender.selectedSegmentIndex]
        }
        
    }
}
