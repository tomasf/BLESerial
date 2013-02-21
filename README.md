BLESerial
=========

BLESerial is an iOS/Mac library for [Red Bear Lab's BLE Mini](http://redbearlab.com/blemini/) (and presumably BLE Shield) that doesn't suck.

Link to CoreBluetooth on iOS or IOBluetooth on OS X.
Create a `BLESerialScanner` and call `-startScanning` to start looking for available serial devices. The scanner delegate's `-serialScanner:foundDevice:` will be called for every found device. If there's a problem that prevents a scan, `-serialScanner:failedWithError:` is called.

When you've found a device that you would like to use, set its delegate and call `-connect`. When you get a `-serialDeviceDidConnect:`, you can interact with the device to send and receive data.