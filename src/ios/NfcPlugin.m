#import "NfcPlugin.h"
#import <CoreNFC/CoreNFC.h>

@interface NfcPlugin() <NFCNDEFReaderSessionDelegate>
@property (nonatomic, strong) NFCNDEFReaderSession *nfcSession;
@property (nonatomic, copy) NSString *callbackId;
@end

@implementation NfcPlugin

#pragma mark - Plugin Initialization

- (void)pluginInitialize {
    NSLog(@"NFC Plugin Initialized");
    if (@available(iOS 11.0, *)) {
        if (![NFCNDEFReaderSession readingAvailable]) {
            NSLog(@"NFC is not supported on this device or disabled.");
        } else {
            NSLog(@"NFC reading is available on this device.");
        }
    } else {
        NSLog(@"NFC is only available on iOS 11.0 and later.");
    }
}

#pragma mark - Cordova Methods

- (void)scanNdef:(CDVInvokedUrlCommand *)command {
    if (@available(iOS 11.0, *)) {
        NSLog(@"Starting NFC scan session");
        
        self.callbackId = command.callbackId;
        if (![NFCNDEFReaderSession readingAvailable]) {
            NSLog(@"Cannot start NFC session: NFC reading not available.");
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                             messageAsString:@"NFC reading is not available on this device."];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }

        self.nfcSession = [[NFCNDEFReaderSession alloc] initWithDelegate:self
                                                                  queue:nil
                                               invalidateAfterFirstRead:YES];
        self.nfcSession.alertMessage = @"Hold your device near an NFC tag.";
        [self.nfcSession beginSession];
    } else {
        NSLog(@"NFC scanning requires iOS 11.0 or later.");
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                         messageAsString:@"NFC is not supported on this device."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void)cancelScan:(CDVInvokedUrlCommand *)command {
    if (self.nfcSession) {
        NSLog(@"Cancelling NFC session.");
        [self.nfcSession invalidateSession];
        self.nfcSession = nil;
    }
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

#pragma mark - NFCNDEFReaderSessionDelegate

- (void)readerSession:(NFCNDEFReaderSession *)session didDetectNDEFs:(NSArray<NFCNDEFMessage *> *)messages {
    NSLog(@"NFC Tag detected with %lu message(s).", (unsigned long)messages.count);

    NSMutableArray *tagMessages = [NSMutableArray new];
    for (NFCNDEFMessage *message in messages) {
        NSMutableArray *recordsArray = [NSMutableArray new];
        for (NFCNDEFPayload *payload in message.records) {
            NSDictionary *payloadDict = @{
                @"tnf": @(payload.typeNameFormat),
                @"type": [self uint8ArrayFromNSData:payload.type],
                @"id": [self uint8ArrayFromNSData:payload.identifier],
                @"payload": [self uint8ArrayFromNSData:payload.payload]
            };
            [recordsArray addObject:payloadDict];
        }
        [tagMessages addObject:@{ @"records": recordsArray }];
    }

    NSLog(@"Parsed NFC messages: %@", tagMessages);

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                       messageAsArray:tagMessages];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
}

- (void)readerSession:(NFCNDEFReaderSession *)session didInvalidateWithError:(NSError *)error {
    NSLog(@"NFC session invalidated: %@", error.localizedDescription);

    CDVPluginResult *pluginResult;
    if (error.code == NFCReaderSessionInvalidationErrorUserCanceled) {
        NSLog(@"NFC session canceled by the user.");
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                         messageAsString:@"NFC session canceled by user."];
    } else {
        NSLog(@"Error occurred during NFC session: %@", error.localizedDescription);
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                         messageAsString:error.localizedDescription];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];

    self.nfcSession = nil;
}

#pragma mark - Helper Methods

- (NSArray *)uint8ArrayFromNSData:(NSData *)data {
    const uint8_t *bytes = data.bytes;
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:data.length];
    for (NSUInteger i = 0; i < data.length; i++) {
        [array addObject:@(bytes[i])];
    }
    return array;
}

@end
