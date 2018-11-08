//
//  MainViewController.swift
//  TCP Commander
//
//  Created by Admin on 26.03.2018.
//  Copyright © 2018 Ivan Elyoskin. All rights reserved.
//

import UIKit
import UnderLineTextField
import LGButton
import ProgressHUD
import DropDown
import SCLAlertView
import RLBAlertsPickers

class MainViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, ClientServiceDelegate, UnderLineTextFieldDelegate {
    
    @IBOutlet var commandTextField: UnderLineTextField!
    @IBOutlet var sendCommandButton: LGButton!
    @IBOutlet var expandButton: UIButton!
    
    @IBOutlet var commandContainerView: UIView!
    @IBOutlet var commandHigthConstraint: NSLayoutConstraint!
    @IBOutlet var commandsTable: UITableView!
    @IBOutlet var logTextView: UITextView!
    
    @IBOutlet var menuBarButton: UIBarButtonItem!
    var dropDownMenu: DropDown = DropDown()
    var dropDownItems: Array = ["Add Command", "Format", "CR LF", "Clear log", "Help", "About"]
    
    var clientService: ClientService?
    var commands: [String] = []
    
    var crlfEnabled: Bool = false
    var currentFormat: String = "utf8"
    var formats: [String] = ["utf8", "utf16", "HEX"]
    
    lazy var tutorialVC: KJOverlayTutorialViewController = {
        return KJOverlayTutorialViewController()
    }()
    
//---------------------------------------------------------------------------------------------------------------
//***************************************************************************************************************
//---------------------------------------------------------------------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        componentSetup()
        styleSetup()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if animated {
            UIView.animate(withDuration: 0.7, animations: {
                self.view.backgroundColor = UIColor(hex: 0xf3f0e0)//AppColors.lightGreenColor
            })
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if (clientService?.isConnected)! {
            clientService?.closeConnection()
        }
    }
    
//-Setup---------------------------------------------------------------------------------------------------------
    func componentSetup(){
        let userDefaults = UserDefaults.standard
        if let formatStr = userDefaults.object(forKey: "Format") {
            currentFormat = formatStr as! String
            dropDownItems[1] = "Format" + " (" +  (formatStr as! String) + ")"
        }
        if let commandsArr = userDefaults.object(forKey: "Commands") {
            commands = commandsArr as! [String]
        } else {
            commands = ["empty"]
        }
        crlfEnabled = userDefaults.bool(forKey: "CRLF")
        if crlfEnabled {
            dropDownItems[2] = "CR LF (Enabled)"
        } else {
            dropDownItems[2] = "CR LF (Disabled)"
        }

        navigationController?.navigationBar.tintColor = .white
        dropDownMenu.anchorView = menuBarButton
        dropDownMenu.dataSource = dropDownItems
        dropDownMenu.direction = .bottom
        dropDownMenu.selectionAction = { (index: Int, item: String) in self.menuChoose(item: item) }
        
        logTextView.isEditable = false
        logTextView.text = ""
        
        let heigth = expandButton.frame.height
        let angleImage = UIImage(from: .FontAwesome, code: "angledown", textColor: .gray, backgroundColor: .clear, size: CGSize(width: heigth, height: heigth))
        expandButton.setImage(angleImage, for: .normal)
        expandButton.setTitle(nil, for: .normal)
        
        commandTextField.delegate = self
        if (clientService?.isConnected)! {
            clientService?.delegate = self
        } else {
            writeLog("Offline Mode")
        }
    }
    
    func styleSetup(){
        self.commandHigthConstraint.constant = 0
        
        commandContainerView.layer.cornerRadius = 10
        commandContainerView.layer.borderColor = UIColor.gray.cgColor
        commandContainerView.layer.borderWidth = 1
        commandContainerView.layer.masksToBounds = true
        
        commandsTable.layer.cornerRadius = 10
        commandsTable.layer.borderColor = UIColor.gray.cgColor
        commandsTable.layer.borderWidth = 1
        commandsTable.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        
        logTextView.layer.cornerRadius = 10
        
        
        self.view.backgroundColor = .white
        
        if (clientService?.isConnected)! {
            enableComponents()
        } else {
            disableComponents()
        }
    }
    
//-Client-delegate-----------------------------------------------------------------------------------------------
    func streamOpenEvent() {
        return
    }
    func streamCloseEvent() {
        ProgressHUD.showError("Disconected")
        navigationController?.popViewController(animated: true)
    }
    
    func streamReceiveData(data: Data) {
        var stringData: String = ""
        switch currentFormat {
        case formats[0]: // utf8
            stringData = String(data: data, encoding: String.Encoding.utf8)!
            break
        case formats[1]: // utf16
            stringData = String(data: data, encoding: String.Encoding.utf16)!
            break
        case formats[2]: // HEX
            stringData = data.map{ String(format: " 0x%02hhx", $0) }.joined()
            break
        default:
            break
        }
        writeLog("Recieved: " + stringData)
    }
    
//-Table-Delegate------------------------------------------------------------------------------------------------
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return commands.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CommandCellId", for: indexPath)
        cell.textLabel?.text = commands[indexPath.row]
        if commands[indexPath.row] == "empty" && indexPath.row == 0 {
            cell.accessoryType = .none
        } else {
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if commands[indexPath.row] == "empty"{
            return false
        } else {
            return true
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            commands.remove(at: indexPath.row)
            if commands.count == 0 {
                commands.append("empty")
            }
            let userDef = UserDefaults.standard
            userDef.set(self.commands, forKey: "Commands")
            tableView.reloadData()
            expandCommandsTable(animated: false)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let commandStr = tableView.cellForRow(at: indexPath)?.textLabel?.text
        if (clientService?.isConnected)! && commandStr != "empty" {
            let crlf = crlfEnabled ? "\r\n" : ""
            let sendStr = commandStr! + crlf
            let data = sendStr.data(using: String.Encoding.utf8)
            let error = clientService?.writeData(data: data!)
            if error != nil {
                // TODO: Error
            } else {
                writeLog("Send: " + (tableView.cellForRow(at: indexPath)?.textLabel?.text)!)
            }
        } else {
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }
    
//-TextField-Delegate--------------------------------------------------------------------------------------------
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(false)
        return true
    }
    
    func textFieldValidate(underLineTextField: UnderLineTextField) throws {
        switch underLineTextField {
        case commandTextField:
            if underLineTextField.text!.isEmpty {
                throw UnderLineTextFieldErrors.error(message: "Command must have more than 1 character")
            }
        default:
            break;
        }
    }
    
//-Actions--------------------------------------------------------------------------------------------------
    @IBAction func sendAction(_ sender: LGButton) {
        var valid = true
        do { try commandTextField.validate() } catch { valid = false }
        
        if valid {
            if (clientService?.isConnected)! {
                let crlf = crlfEnabled ? "\r\n" : ""
                let sendStr = (commandTextField.text)! + crlf
                let data = sendStr.data(using: String.Encoding.utf8)
                let error = clientService?.writeData(data: data!)
                if error != nil {
                    // TODO: Error
                } else {
                    writeLog("Sended: " + commandTextField.text!)
                }
            }
        }
    }
    
    @IBAction func toggleCommandAction(_ sender: UIButton) {
        if self.commandHigthConstraint.constant == 0 {
            expandCommandsTable(animated: true)
        } else {
            collapseCommandsTable(animated: true)
        }
    }
    
    @IBAction func menuAction(_ sender: Any) {
        dropDownMenu.show()
    }
    
    private func menuChoose(item: String){
        switch item {
        case self.dropDownItems[0]: // "Add command"
            showNewCommandAlertView()
            break
        case self.dropDownItems[1]: // "Format"
            formatChoose()
            break
        case self.dropDownItems[2]: // "CR LF"
            chooseCRLF()
            break
        case self.dropDownItems[3]: // "Clear log"
            clearLog()
            break
        case self.dropDownItems[4]: // Help
            helpTutorialShow()
            break
        case self.dropDownItems[5]: // About
            showAboutAlertView()
            break
        default:
            break
        }
    }
    
//-Menu-Actions-------------------------------------------------------------------------------------
    func showNewCommandAlertView(){
        let alert = SCLAlertView()
        let tf = alert.addTextField("Enter command")
        alert.addButton("Save", action: {
            if self.commands.first! != "empty"{
                self.commands.append(tf.text!)
            } else {
                self.commands[0] = tf.text!
            }
            self.commandsTable.reloadData()
            let userDef = UserDefaults.standard
            userDef.set(self.commands, forKey: "Commands")
            self.expandCommandsTable(animated: true)
        })
        alert.showEdit("Command", subTitle: "That command will be storage in your device", closeButtonTitle: "Cancel", colorStyle: SCLAlertViewStyle.question.defaultColorInt)
    }
    
    
    func formatChoose() {
        let alert = UIAlertController(style: .actionSheet, title: "Choose output format")
        formats.forEach {
            alert.addAction(title: $0, color: .black, style: .default) { action in
                self.currentFormat = action.title!
                self.dropDownItems[1] = "Format" + " (" + action.title! + ")"
                self.dropDownMenu.dataSource = self.dropDownItems
                let userDefaults = UserDefaults.standard
                userDefaults.set(action.title!, forKey: "Format")
            }
        }
        alert.show()
    }
    
    
    func chooseCRLF() {
        let alert = UIAlertController(style: .actionSheet, title: "CR LF")
        alert.addAction(title: "Enable", color: .black, style: .default) { action in
            self.crlfEnabled = true
            self.dropDownItems[2] = "CR LF (Enabled)"
            self.dropDownMenu.dataSource = self.dropDownItems
            let userDefaults = UserDefaults.standard
            userDefaults.set(true, forKey: "CRLF")
        }
        alert.addAction(title: "Disable", color: .black, style: .default) { action in
            self.crlfEnabled = false
            self.dropDownItems[2] = "CR LF (Disabled)"
            self.dropDownMenu.dataSource = self.dropDownItems
            let userDefaults = UserDefaults.standard
            userDefaults.set(false, forKey: "CRLF")
        }
        alert.show()
    }
    
    func clearLog() {
        logTextView.text = ""
    }
    
    func helpTutorialShow() {
        // tut1
        let focusRect1 = CGRect(x: commandTextField.frame.origin.x, y: commandTextField.frame.origin.y, width: sendCommandButton.frame.maxX - commandTextField.frame.minX, height: commandTextField.frame.height)
        let icon1 = UIImage(from: .FontAwesome, code: "pencil", textColor: .white, backgroundColor: .clear, size: CGSize(width: 72, height: 72))
        let icon1Frame = CGRect(x: self.view.bounds.width/2-72/2, y: focusRect1.maxY + 12, width: 72, height: 72)
        let message1 = "You may write and send command there"
        let message1Center = CGPoint(x: self.view.bounds.width/2, y: icon1Frame.maxY + 24)
        let tut1 = KJTutorial.textWithIconTutorial(focusRectangle: focusRect1, text: message1, textPosition: message1Center, icon: icon1, iconFrame: icon1Frame)
        // tut2
        let focusRect2 = CGRect(x: commandContainerView.frame.origin.x, y: commandContainerView.frame.origin.y, width: commandContainerView.frame.width, height: commandContainerView.frame.height + commandsTable.frame.height)
        let icon2 = UIImage(from: .FontAwesome, code: "handoup", textColor: .white, backgroundColor: .clear, size: CGSize(width: 72, height: 72))
        let icon2Frame = CGRect(x: self.view.bounds.width/2-72/2, y: focusRect2.maxY + 12, width: 72, height: 72)
        let message2 = "Or choose storage one"
        let message2Center = CGPoint(x: self.view.bounds.width/2, y: icon2Frame.maxY + 24)
        var tut2 = KJTutorial.textWithIconTutorial(focusRectangle: focusRect2, text: message2, textPosition: message2Center, icon: icon2, iconFrame: icon2Frame)
        tut2.focusRectangleCornerRadius = 10
        // tut3
        let focusRect3 = logTextView.frame
        let icon3 = UIImage(from: .FontAwesome, code: "handodown", textColor: .white, backgroundColor: .clear, size: CGSize(width: 72, height: 72))
        let icon3Frame = CGRect(x: self.view.bounds.width/2-72/2, y: focusRect3.minY - 72 - 20, width: 72, height: 72)
        let message3 = "All connection events will be logged"
        let message3Center = CGPoint(x: self.view.bounds.width/2, y: icon3Frame.maxY - 72 - 12 - 20)
        var tut3 = KJTutorial.textWithIconTutorial(focusRectangle: focusRect3, text: message3, textPosition: message3Center, icon: icon3, iconFrame: icon3Frame)
        tut3.focusRectangleCornerRadius = 10

        // tuts
        self.tutorialVC.tutorials = [tut1, tut2, tut3]
        self.tutorialVC.showInViewController(self)
    }
    
    func showAboutAlertView() {
        let alert = SCLAlertView()
        alert.showInfo("About", subTitle: "Created by Ivan Elyoskin\n\nContacts\nIvan Elyoskin: elyoskin@gmail.com\nJury Chursin: _ju_@mail.ru", closeButtonTitle: "Close", colorStyle: 0x80BF44)
    }
    
    
//-View-Help----------------------------------------------------------------------------------------
    private func expandCommandsTable(animated: Bool) {
        let contentHeigth = commandsTable.contentSize.height
        let maxHeigth = (self.commandHigthConstraint.constant + self.logTextView.frame.height) / 2
        commandHigthConstraint.constant = min(contentHeigth, maxHeigth)
        self.commandContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        if animated {
            UIView.animate(withDuration: 0.5, animations: {
                self.view.layoutIfNeeded()  // изменение положения
                self.expandButton.transform = CGAffineTransform.identity.rotated(by: -0.9999*CGFloat.pi)
            })
        }
    }
    
    private func collapseCommandsTable(animated: Bool){
        commandHigthConstraint.constant = 0
        if animated {
            UIView.animate(withDuration: 0.5,
                           animations: {
                            self.view.layoutIfNeeded()
                            //self.view.setNeedsDisplay()
                            self.expandButton.transform = CGAffineTransform(rotationAngle: 0)
                            },
                           completion: { isComplete in
                            self.commandContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]

            })
        }
    }
    
    
    func enableComponents() {
        sendCommandButton.bgColor = AppColors.blueColor
        sendCommandButton.isEnabled = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Disconnect", style: .plain, target: self, action: #selector(back))
    }
    
    func disableComponents() {
        sendCommandButton.bgColor = .gray
        sendCommandButton.isEnabled = false
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(back))
    }
    
    @objc func back() {
        navigationController?.popViewController(animated: true)
    }
    
    func writeLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("[HH:mm:ss]")
        let dateStr = formatter.string(from: Date())
        logTextView.text = "[" + dateStr + "]" + " " + message + "\n" + logTextView.text
        logTextView.scrollRangeToVisible(NSMakeRange(0, 0)) //scroll
    }
    
}

