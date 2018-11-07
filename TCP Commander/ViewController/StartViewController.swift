//
//  ViewController.swift
//  TCP Commander
//
//  Created by Admin on 26.03.2018.
//  Copyright © 2018 Ivan Elyoskin. All rights reserved.
//

import UIKit
import LGButton
import UnderLineTextField
import ProgressHUD
import DropDown
import SCLAlertView
import SwiftIconFont

class StartViewController: UIViewController, UITextFieldDelegate, UnderLineTextFieldDelegate, ClientServiceDelegate {

    @IBOutlet var ipTextField: UnderLineTextField!
    @IBOutlet var portTextField: UnderLineTextField!
    @IBOutlet var connectButton: LGButton!
    @IBOutlet var menuBarButton: UIBarButtonItem!
    
    var clientService: ClientService! = ClientService()
    
    var dropDownMenu: DropDown = DropDown()
    var dropDownItems: Array = ["Offline mode", "Help", "About"]
    
    lazy var tutorialVC: KJOverlayTutorialViewController = {
        return KJOverlayTutorialViewController()
    }()
    
//---------------------------------------------------------------------------------------------------------------
//***************************************************************************************************************
//---------------------------------------------------------------------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        componentSetup()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        clientService.delegate = self // делегат на активном экране
    }


//-Setup---------------------------------------------------------------------------------------------------------
    func componentSetup() {
        ipTextField.validationType = .afterEdit
        portTextField.validationType = .afterEdit
        
        ipTextField.delegate = self
        portTextField.delegate = self
        
        dropDownMenu.anchorView = menuBarButton
        dropDownMenu.dataSource = dropDownItems
        dropDownMenu.direction = .bottom
        dropDownMenu.selectionAction = { (index: Int, item: String) in self.menuChoose(item: item) }
        
        let userDefaults = UserDefaults.standard
        if let ipStr = userDefaults.object(forKey: "Ip") {
            ipTextField.text = ipStr as? String
        }
        if let portStr = userDefaults.object(forKey: "Port") {
            portTextField.text = portStr as? String
        }
    }

    func styleSetup(){
        navigationController?.navigationBar.barTintColor = AppColors.logoGreenColor
        if clientService.isConnected {
            buttonToStopStyle(button: connectButton)
        } else {
            buttonToConnectStyle(button: connectButton)
        }
    }
    
//-Actions-------------------------------------------------------------------------------------------------------
    @IBAction func connectAction(_ sender: LGButton) {
        if sender.isLoading {
            clientService.closeConnection()
            sender.isLoading = false
            buttonToConnectStyle(button: sender)
        } else {
            var ipValid: Bool = true
            var portValid: Bool = true
            do { try ipTextField.validate() } catch { ipValid = false }
            do { try portTextField.validate() } catch { portValid = false }
        
            if ipValid && portValid {
                sender.isLoading = true
                buttonToStopStyle(button: sender)
                sender.isUserInteractionEnabled = true // чтобы мог по повторному нажатию сделать Disconnect
                ipTextField.endEditing(true)
                portTextField.endEditing(true)
                clientService.initConnection(hostIp: ipTextField.text!, port: portTextField.text!)
            }
        }
    }

    @IBAction func menuAction(_ sender: Any) {
        dropDownMenu.show()
    }
    
    func menuChoose(item: String){
        switch item {
        case self.dropDownItems[0]://Offline mode
            clientService.closeConnection()
            self.performSegue(withIdentifier: "ToMainSegue", sender: self)
            break
        case self.dropDownItems[1]: //Help
            helpTutorialShow()
            break
        case self.dropDownItems[2]: // About
            showAboutAlertView()
            break
        default:
            break
        }
    }
    
    @IBAction func viewTouchAction(_ sender: Any) {
        ipTextField.endEditing(false)
        portTextField.endEditing(false)
    }
    
    
//-Client-Delegate-----------------------------------------------------------------------------------------------    
    func streamOpenEvent() {
        ProgressHUD.showSuccess("Connected")
        connectButton.isLoading = false
        buttonToConnectStyle(button: connectButton)
        let userDefaults = UserDefaults.standard
        userDefaults.set(ipTextField.text, forKey: "Ip")
        userDefaults.set(portTextField.text, forKey: "Port")
        performSegue(withIdentifier: "ToMainSegue", sender: self)
    }
    func streamCloseEvent() {
        ProgressHUD.showError("No connection")
        connectButton.isLoading = false
        buttonToConnectStyle(button: connectButton)
    }
    
    
//-Validation----------------------------------------------------------------------------------------------------
    func textFieldValidate(underLineTextField: UnderLineTextField) throws {
        switch underLineTextField {
        case ipTextField:
            let reg = "^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$";
            let options = NSRegularExpression.Options.caseInsensitive
            var num: Int = 0
            var validationError: Bool = false
            do {
                let regex = try NSRegularExpression(pattern: reg, options: options)
                num = regex.numberOfMatches(in: ipTextField.text!, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(location: 0, length: (ipTextField.text?.count)!))
            } catch {
                validationError = true
            }
            if validationError {
                throw UnderLineTextFieldErrors.error(message: "Ip format validation error. Try again or connect with developer")
            } else if num != 1 {
                throw UnderLineTextFieldErrors.error(message: "Ip adress should be \"xxx.xxx.xxx.xxx\" format")
            } /*else {
                throw UnderLineTextFieldErrors.warning(message: "")
            }*/
            break
            
        case portTextField:
            let port = Int(underLineTextField.text!)
            if port == nil || port! < 0 || port! > 65535 {
                throw UnderLineTextFieldErrors.error(message: "Port should be in 0-65535 range")
            }
            break
            
        default:
            break
        }
    }
    
    
//-TextField-Delegate--------------------------------------------------------------------------------------------
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case ipTextField:
            _ = portTextField.becomeFirstResponder()
            break
            
        case portTextField:
            textField.endEditing(false)
            break
            
        default:
            break
        }
        return false
    }
    
    
//-View-Help--------------------------------------------------------------------------------------------------
    func enableInteraction() {
        ipTextField.isEnabled = true
        portTextField.isEnabled = true
        menuBarButton.isEnabled = true
        connectButton.isEnabled = true
        // TODO: Color
    }
    
    func disableInteraction() {
        ipTextField.isEnabled = false
        portTextField.isEnabled = false
        menuBarButton.isEnabled = false
        connectButton.isEnabled = false
        // TODO: change button color
    }
    
    
//-Navigation--------------------------------------------------------------------------------------------------
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "ToMainSegue"?:
            let dest = segue.destination as! MainViewController
            dest.clientService = self.clientService
            break
        default:
            break
        }
    }
    
    
//-View-Help----------------------------------------------------------------------------------------
    func showAboutAlertView() {
        buttonToConnectStyle(button: connectButton)
        let alert = SCLAlertView()
        alert.showInfo("About", subTitle: "Created by Ivan Elyoskin\n\nContacts\nIvan Elyoskin: elyoskin@gmail.com\nJury Chursin: _ju_@mail.ru", closeButtonTitle: "Close", colorStyle: 0x80BF44)
    }
    
    func helpTutorialShow() {
        // tut1
        let focusRect1 = self.ipTextField.frame
        let icon = UIImage(from: .FontAwesome, code: "pencil", textColor: .white, backgroundColor: .clear, size: CGSize(width: 72, height: 72))
        let icon1Frame = CGRect(x: self.view.bounds.width/2-72/2, y: focusRect1.minY - 72 - 12 - 20, width: 72, height: 72)
        let message1 = "Enter server's ip adress"
        let message1Center = CGPoint(x: self.view.bounds.width/2, y: icon1Frame.maxY + 12)
        let tut1 = KJTutorial.textWithIconTutorial(focusRectangle: focusRect1, text: message1, textPosition: message1Center, icon: icon, iconFrame: icon1Frame)
        // tut2
        let focusRect2 = self.portTextField.frame
        let icon2Frame = CGRect(x: self.view.bounds.width/2-72/2, y: focusRect2.minY - 72 - 12 - 20, width: 72, height: 72)
        let message2 = "Enter the open server port"
        let message2Center = CGPoint(x: self.view.bounds.width/2, y: icon2Frame.maxY + 12)
        let tut2 = KJTutorial.textWithIconTutorial(focusRectangle: focusRect2, text: message2, textPosition: message2Center, icon: icon, iconFrame: icon2Frame)
        // tut3
        let focusRect3 = self.connectButton.frame
        let icon3 = UIImage(from: .FontAwesome, code: "handoup", textColor: .white, backgroundColor: .clear, size: CGSize(width: 72, height: 72))
        let icon3Frame = CGRect(x: self.view.bounds.width/2-72/2, y: focusRect3.maxY + 12, width: 72, height: 72)
        let message3 = "And tap button to connect to the server"
        let message3Center = CGPoint(x: self.view.bounds.width/2, y: icon3Frame.maxY + 24)
        var tut3 = KJTutorial.textWithIconTutorial(focusRectangle: focusRect3, text: message3, textPosition: message3Center, icon: icon3, iconFrame: icon3Frame)
        tut3.focusRectangleCornerRadius = connectButton.frame.height / 2
        // tuts
        self.tutorialVC.tutorials = [tut1, tut2, tut3]
        self.tutorialVC.showInViewController(self)
    }
    
    func buttonToConnectStyle(button: LGButton) {
        button.gradientStartColor = AppColors.blueColor
        button.gradientEndColor = AppColors.blueColor2
    }
    
    func buttonToStopStyle(button: LGButton) {
        button.gradientStartColor = AppColors.redColor
        button.gradientEndColor = AppColors.redColor
    }
}

