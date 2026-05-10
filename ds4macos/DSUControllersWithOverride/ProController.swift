//
//  ProController.swift
//  ds4macos
//

import Foundation
import GameController
import JoyConSwift


@available(OSX 11.0, *)
class ProController: DSUController {

    override func updateJoyConSwiftMotionVariables() {
        guard let joyConSwiftController = self.joyConSwiftController else { return }
        
        timeStamp = UInt64(Date().timeIntervalSince1970 * 1000000)
        
        self.motionLock.lock()
        // acceleration
        accX = getUInt8arrayFromCGFloat(num:  joyConSwiftController.acceleration.y)
        accY = getUInt8arrayFromCGFloat(num: -joyConSwiftController.acceleration.z)
        accZ = getUInt8arrayFromCGFloat(num:  joyConSwiftController.acceleration.x)

        // gyroscope
        gyroX = getUInt8arrayFromCGFloat(num: -joyConSwiftController.gyro.y)
        gyroY = getUInt8arrayFromCGFloat(num: -joyConSwiftController.gyro.z)
        gyroZ = getUInt8arrayFromCGFloat(num:  joyConSwiftController.gyro.x)
        self.motionLock.unlock()
    }

}
