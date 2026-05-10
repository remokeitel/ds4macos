//
//  ControllerService.swift
//  ds4macos
//
//  Created by Marco Dijkslag on 07/01/2021.
//

import Foundation
import GameController
import SwiftUI
import JoyConSwift

@available(OSX 10.15, *)
class ControllerService: ObservableObject {
    
    let maximumControllerCount: Int
    
    @ObservedObject var gameControllerInfo = ControllerInfo()
    var prevMotion: GCMotion?
    
    @Published var numberOfControllersConnected = 0
    @Published var connectedControllers: [Int: DSUController] = [:]
    
    var server: DSUServer?
    
    var joyConManager = JoyConManager()
    var unmatchedJoyConSwiftControllers: [JoyConSwift.Controller] = []
    
    init(server: DSUServer, maximumControllerCount: Int = 4) {
        self.maximumControllerCount = maximumControllerCount
        self.server = server
        
        if #available(macOS 11.3, *) {
            GCController.shouldMonitorBackgroundEvents = true
        }
        
        self.observeControllers()
    }
    
    func reportControllers() {
        for dsuController in self.connectedControllers {
            self.server!.report(controller: dsuController.value)
        }
    }
    
    func reportController(dsuController: DSUController) {
        self.server!.report(controller: dsuController)
    }
    
    func observeControllers() {
        NotificationCenter.default.addObserver(self, selector: #selector(onControllerConnect), name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onControllerDisconnect), name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
        
        self.joyConManager.connectHandler = { [weak self] joyConSwiftController in
            self?.addJoyConSwiftController(joyConSwiftController)
        }
        self.joyConManager.disconnectHandler = { [weak self] joyConSwiftController in
            self?.removeJoyConSwiftController(joyConSwiftController)
        }
        
        _ = self.joyConManager.runAsync()
    }
    
    func firstFreeSlot() -> Int {
        for i in 0..<self.maximumControllerCount {
            if !self.connectedControllers.keys.contains(i) {
                return i
            }
        }
        return -1
    }
    
    @objc func onControllerConnect(_ notification: Notification) {
        guard self.connectedControllers.count < self.maximumControllerCount else { return }
        let gameController = notification.object as! GCController
        let freeSlot = self.firstFreeSlot()
        if freeSlot != -1 {
            self.addControllerToSlots(gameController: gameController, slot: freeSlot)
        }
    }
    
    func addJoyConSwiftController(_ joyConSwiftController: JoyConSwift.Controller) {
        //joyConSwiftController.setPlayerLights(l1: .on, l2: .off, l3: .off, l4: .off)
        joyConSwiftController.enableIMU(enable: true)
        joyConSwiftController.setInputMode(mode: .standardFull)
        
        for (_, dsuController) in self.connectedControllers {
            if dsuController.gameController!.motion == nil && dsuController.joyConSwiftController == nil {
                dsuController.initJoyConSwiftController(joyConSwiftController)
                return
            }
        }
        unmatchedJoyConSwiftControllers.append(joyConSwiftController)
    }
    
    func isProController(_ gameController: GCController) -> Bool {
        let category = gameController.productCategory
        let vendor = gameController.vendorName ?? ""
        return category.contains("Pro Controller") || vendor.contains("Nintendo")
    }

    func addControllerToSlots(gameController: GCController, slot: Int) {
        if isProController(gameController) {
            self.connectedControllers[slot] = ProController(controllerService: self, gameController: gameController, slot: UInt8(slot))
            
            let dsuController = self.connectedControllers[slot]!
            if dsuController.gameController!.motion == nil {
                if let joyConSwiftControllerIndex = unmatchedJoyConSwiftControllers.firstIndex(where: { $0.type == .ProController }) {
                    let joyConSwiftController = unmatchedJoyConSwiftControllers.remove(at: joyConSwiftControllerIndex)
                    dsuController.initJoyConSwiftController(joyConSwiftController)
                }
            }
        } else {
            self.connectedControllers[slot] = DSUController(controllerService: self, gameController: gameController, slot: UInt8(slot))
        }
        self.gameControllerInfo.info = "Connected: [vendor: \(gameController.vendorName ?? "?"), productCategory: \(gameController.productCategory)]"
        print(self.gameControllerInfo.info)
        self.numberOfControllersConnected += 1
    }
    
    @objc func onControllerDisconnect(_ notification: Notification) {
        let gameController = notification.object as! GCController
        print("Disconnected: [vendor: \(gameController.vendorName ?? "?"), productCategory: \(gameController.productCategory)]")
        self.removeControllerFromSlots(gameController: gameController)
    }
    
    func removeJoyConSwiftController(_ joyConSwiftController: JoyConSwift.Controller) {
        self.unmatchedJoyConSwiftControllers.removeAll { $0.serialID == joyConSwiftController.serialID }
        for (_, dsuController) in self.connectedControllers {
            if dsuController.joyConSwiftController?.serialID == joyConSwiftController.serialID {
                dsuController.joyConSwiftController = nil
                print("JoyConSwift motion fallback removed for slot \(dsuController.slot)")
            }
        }
    }
    
    func removeControllerFromSlots(gameController: GCController) {
        var removeSlot: Int = -1
        for dsuController in self.connectedControllers {
            if dsuController.value.gameController == gameController {
                removeSlot = Int(dsuController.value.slot)
                break
            }
        }
        if removeSlot != -1 {
            self.connectedControllers.removeValue(forKey: removeSlot)
        }
        self.numberOfControllersConnected -= 1
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
        
        joyConManager.stop()
    }

}
