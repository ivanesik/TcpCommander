//
//  ClientService.swift
//  TCP Commander
//
//  Created by Admin on 26.03.2018.
//  Copyright © 2018 Ivan Elyoskin. All rights reserved.
//

import  Foundation


@objc protocol ClientServiceDelegate {
    func streamOpenEvent()
    func streamCloseEvent()
    @objc optional func streamReceiveData(data: Data)
}


class ClientService: Thread, StreamDelegate {
    
    public var isConnected: Bool {
        get {
            return (inputStream != nil && outputStream != nil) && (inputStream.streamStatus == .open && outputStream.streamStatus == .open)
        }
    }
    
    private var inputStream: InputStream!
    private var outputStream: OutputStream!
    
    private let maxReadLength: Int = 1024
    public var delegate: ClientServiceDelegate?
    
    private var inputIsOpened: Bool = false
    private var outputIsOpened: Bool = false
    
//--------------------------------------------------------------------------------------------------------------------------
    func initConnection(hostIp: String, port: String) {
        var readStream : Unmanaged<CFReadStream>?
        var writeStream : Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, hostIp as CFString, UInt32(port)!, &readStream, &writeStream)
        
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()
        inputStream.delegate = self
        outputStream.delegate = self
        inputStream.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)
        outputStream.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)
        inputStream.open()
        outputStream.open()
    }
    
//--------------------------------------------------------------------------------------------------------------------------
    func closeConnection() {
        inputStream?.close()
        outputStream?.close()
        inputIsOpened = false
        outputIsOpened = false
        delegate?.streamCloseEvent()
    }
    
//--------------------------------------------------------------------------------------------------------------------------
    func writeData(data: Data) -> String? {
        if isConnected {
            _ = data.withUnsafeBytes{ outputStream.write($0, maxLength: data.count) }
            return nil
        } else {
            return "Connection error"
        }
    }
    
//--------------------------------------------------------------------------------------------------------------------------
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.openCompleted:
            switch aStream {
            case inputStream:
                inputIsOpened = true
                break
            case outputStream:
                outputIsOpened = true
                break
            default:
                break
            }
            if inputIsOpened && outputIsOpened {
                delegate?.streamOpenEvent()
            }
            break
            
        case Stream.Event.hasBytesAvailable:
            if aStream == inputStream {
                let data = readAvailableBytes(stream: inputStream)
                delegate?.streamReceiveData!(data: data)
            }
            break
            
        case Stream.Event.hasSpaceAvailable:
            break
            
        case Stream.Event.errorOccurred:
            inputIsOpened = false
            outputIsOpened = false
            delegate?.streamCloseEvent()
            break
            
        case Stream.Event.endEncountered:
            inputIsOpened = false
            outputIsOpened = false
            delegate?.streamCloseEvent()
            break
            
        default:
            break
        }
    }
    
//--------------------------------------------------------------------------------------------------------------------------
    private func readAvailableBytes(stream: InputStream) -> Data {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
        var data: Data = Data()
        
        while stream.hasBytesAvailable {
            let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)
            
            if numberOfBytesRead < 0 {
                if let _ = stream.streamError {
                    break
                }
            }
            data += Data(bytes: buffer, count: Int(numberOfBytesRead))
        }
        return data
    }
    
    
}
