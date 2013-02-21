//
//  BLESerial.m
//
//  Created by Tomas Franzén on 2013-02-10.
//  Copyright (c) 2013 Tomas Franzén. All rights reserved.
//

#import "BLESerial.h"
#import <CoreBluetooth/CoreBluetooth.h>

NSString *const BLESerialErrorDomain = @"BLESerial";

static NSString *const BLESerialService = @"713D0000-503E-4C75-BA94-3148F18D941E";

static NSString *const BLESerialCharacteristicGetVendorName = @"713D0001-503E-4C75-BA94-3148F18D941E";
static NSString *const BLESerialCharacteristicGetSoftwareVersion = @"713D0005-503E-4C75-BA94-3148F18D941E";

static NSString *const BLESerialCharacteristicReset = @"713D0004-503E-4C75-BA94-3148F18D941E";
static NSString *const BLESerialCharacteristicReceive = @"713D0002-503E-4C75-BA94-3148F18D941E";
static NSString *const BLESerialCharacteristicTransmit = @"713D0003-503E-4C75-BA94-3148F18D941E";


@interface BLESerialDevice () <CBPeripheralDelegate>
@property(strong) CBPeripheral *peripheral;
@property(strong) BLESerialScanner *scanner;
@property(strong) CBService *service;

- (id)initWithPeripheral:(CBPeripheral*)peripheral scanner:(BLESerialScanner*)scanner;
- (void)didConnect;
- (void)didDisconnect;
- (void)failedToConnectWithError:(NSError*)error;
@end




@interface BLESerialScanner () <CBCentralManagerDelegate>
@property(weak) id<BLESerialScannerDelegate> delegate;
@property(strong) CBCentralManager *manager;
@property BOOL pendingScan;

@property(strong) NSMapTable *UUIDToDeviceMap;
@end


@implementation BLESerialScanner

- (id)initWithDelegate:(id<BLESerialScannerDelegate>)delegate {
	if(!(self = [super init])) return nil;
	
	self.delegate = delegate;
	self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
	self.UUIDToDeviceMap = [NSMapTable strongToWeakObjectsMapTable];
	
	return self;
}


- (void)failWithCode:(NSInteger)code {
	self.pendingScan = NO;
	NSError *error = [NSError errorWithDomain:BLESerialErrorDomain code:code userInfo:nil];
	if([self.delegate respondsToSelector:@selector(serialScanner:failedWithError:)])
		[self.delegate serialScanner:self failedWithError:error];
}


- (void)handleManagerStateForPendingScanStart:(CBCentralManagerState)state {
	if(!self.pendingScan) return;
	
	switch(state) {			
		case CBCentralManagerStatePoweredOff:
			[self failWithCode:BLESerialErrorBluetoothTurnedOff];
			break;
		case CBCentralManagerStateUnsupported:
			[self failWithCode:BLESerialErrorBLENotSupported];
			break;
		case CBCentralManagerStateUnauthorized:
			[self failWithCode:BLESerialErrorUnauthorized];
			break;
			
		case CBCentralManagerStatePoweredOn:
			[self.manager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:BLESerialService]] options:nil];
			if([self.delegate respondsToSelector:@selector(serialScannerStartedScanning:)])
				[self.delegate serialScannerStartedScanning:self];
			self.pendingScan = NO;
			break;
			
		default: break;
	}
}


- (void)startScanning {
	self.pendingScan = YES;
	[self handleManagerStateForPendingScanStart:self.manager.state];
}


- (void)stopScanning {
	[self.manager stopScan];
}


- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
	[self handleManagerStateForPendingScanStart:central.state];
}


- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
	BLESerialDevice *device = [[BLESerialDevice alloc] initWithPeripheral:peripheral scanner:self];
	if([self.delegate respondsToSelector:@selector(serialScanner:foundDevice:)])
		[self.delegate serialScanner:self foundDevice:device];
}


#pragma mark - Peripheral-specific handling


- (BLESerialDevice*)deviceForPeripheral:(CBPeripheral*)peripheral {
	return (BLESerialDevice*)peripheral.delegate;
}


- (void)connectToDevice:(BLESerialDevice*)device {
	[self.manager connectPeripheral:device.peripheral options:@{}];
}


- (void)disconnectFromDevice:(BLESerialDevice*)device {
	[self.manager cancelPeripheralConnection:device.peripheral];
}


- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
	[[self deviceForPeripheral:peripheral] didConnect];
}


- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
	[[self deviceForPeripheral:peripheral] failedToConnectWithError:error];
}


- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
	[[self deviceForPeripheral:peripheral] didDisconnect];
}


@end




@implementation BLESerialDevice


- (id)initWithPeripheral:(CBPeripheral*)peripheral scanner:(BLESerialScanner*)scanner {
	if(!(self = [super init])) return nil;
	
	self.peripheral = peripheral;
	self.scanner = scanner;
	
	self.peripheral.delegate = self;
	
	return self;
}


- (void)connect {
	NSAssert(self.delegate != nil, @"set device's delegate before connecting");
	[self.scanner connectToDevice:self];
}


- (void)disconnect {
	[self.scanner disconnectFromDevice:self];
}


- (void)didConnect {
	[self.peripheral discoverServices:@[[CBUUID UUIDWithString:BLESerialService]]];
}


- (void)failedToConnectWithError:(NSError*)error {
	if([self.delegate respondsToSelector:@selector(serialDevice:failedToConnectWithError:)])
		[self.delegate serialDevice:self failedToConnectWithError:error];
}


- (void)didDisconnect {
	if([self.delegate respondsToSelector:@selector(serialDeviceDidDisconnect:)])
		[self.delegate serialDeviceDidDisconnect:self];
}


- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
	for(CBService *service in self.peripheral.services) {
		if([[service UUID] isEqual:[CBUUID UUIDWithString:BLESerialService]]) {
			self.service = service;
			[self.peripheral discoverCharacteristics:nil forService:self.service];
		}
	}	
}


- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
	CBCharacteristic *readChar = [self characteristicForUUID:BLESerialCharacteristicReceive];
	[self.peripheral setNotifyValue:YES forCharacteristic:readChar];
	
	if([self.delegate respondsToSelector:@selector(serialDeviceDidConnect:)])
		[self.delegate serialDeviceDidConnect:self];
}


- (CBCharacteristic*)characteristicForUUID:(NSString*)UUIDString {
	CBUUID *UUID = [CBUUID UUIDWithString:UUIDString];
	for(CBCharacteristic *characteristic in self.service.characteristics)
		if([characteristic.UUID isEqual:UUID])
			return characteristic;
	return nil;
}


- (void)readVendorName {
	[self.peripheral readValueForCharacteristic:[self characteristicForUUID:BLESerialCharacteristicGetVendorName]];
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
	if([characteristic.UUID isEqual:[CBUUID UUIDWithString:BLESerialCharacteristicGetVendorName]]) {
		// Vendor name
		NSString *string = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
		if([self.delegate respondsToSelector:@selector(serialDevice:didReadVendorName:)])
			[self.delegate serialDevice:self didReadVendorName:string];

	}else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:BLESerialCharacteristicReceive]]) {
		// Receive data
		if([self.delegate respondsToSelector:@selector(serialDevice:didReadData:)])
			[self.delegate serialDevice:self didReadData:characteristic.value];
		
		NSData *one = [NSData dataWithBytes:"\x01" length:1];
		[self.peripheral writeValue:one forCharacteristic:[self characteristicForUUID:BLESerialCharacteristicReset] type:CBCharacteristicWriteWithoutResponse];
	}
}


- (void)writeData:(NSData*)data {
	CBCharacteristic *writeChar = [self characteristicForUUID:BLESerialCharacteristicTransmit];
	[self.peripheral writeValue:data forCharacteristic:writeChar type:CBCharacteristicWriteWithoutResponse];
}


- (void)updateRSSI {
	[self.peripheral readRSSI];
}


- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error {
	if([self.delegate respondsToSelector:@selector(serialDevice:didUpdateRSSI:)])
		[self.delegate serialDevice:self didUpdateRSSI:self.peripheral.RSSI.integerValue];
}


- (NSInteger)RSSI {
	return self.peripheral.RSSI.integerValue;
}


@end