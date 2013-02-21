//
//  BLESerial.h
//
//  Created by Tomas Franzén on 2013-02-10.
//  Copyright (c) 2013 Tomas Franzén. All rights reserved.
//

#import <Foundation/Foundation.h>
@class BLESerialDevice, BLESerialScanner;


extern NSString *const BLESerialErrorDomain;

enum {
	BLESerialErrorBLENotSupported,
	BLESerialErrorBluetoothTurnedOff,
	BLESerialErrorUnauthorized,
};


@protocol BLESerialScannerDelegate <NSObject>
@optional
- (void)serialScanner:(BLESerialScanner*)scanner failedWithError:(NSError*)error;
- (void)serialScannerStartedScanning:(BLESerialScanner*)scanner;
- (void)serialScanner:(BLESerialScanner*)scanner foundDevice:(BLESerialDevice*)device;
@end


@interface BLESerialScanner : NSObject
- (id)initWithDelegate:(id<BLESerialScannerDelegate>)delegate;
- (void)startScanning;
- (void)stopScanning;
@end


@protocol BLESerialDeviceDelegate <NSObject>
@optional
- (void)serialDeviceDidConnect:(BLESerialDevice*)device;
- (void)serialDevice:(BLESerialDevice*)device failedToConnectWithError:(NSError*)error;
- (void)serialDeviceDidDisconnect:(BLESerialDevice*)device;

- (void)serialDevice:(BLESerialDevice*)device didReadVendorName:(NSString*)vendorName;
- (void)serialDevice:(BLESerialDevice *)device didUpdateRSSI:(NSInteger)RSSI;
- (void)serialDevice:(BLESerialDevice *)device didReadData:(NSData*)data;
@end

@interface BLESerialDevice : NSObject
@property(weak) id<BLESerialDeviceDelegate> delegate;
@property(readonly) NSInteger RSSI;

- (void)connect;
- (void)disconnect;

- (void)readVendorName;
- (void)writeData:(NSData*)data;
- (void)updateRSSI;
@end
