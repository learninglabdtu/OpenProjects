//
//  TCPInterfaceController.m
//  H.264 Recorder
//
//  Created by Filip Sandborg-Olsen on 08/03/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import "TCPInterfaceController.h"

#import "AppDelegate.h"
#import "H264Recorder.h"

@implementation TCPInterfaceController

-(TCPInterfaceController*) initWithPort:(uint16_t)port andRecorder:(H264Recorder*)recorder {
    
    _recorder = recorder;
    queue = dispatch_queue_create("TCPInterface", NULL);
    
    appDelegate = (AppDelegate*)[[NSApplication sharedApplication] delegate];
    
    socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:queue];
    
    clientList = [[NSMutableArray alloc] initWithCapacity:1];
    
    NSError* error = nil;
    if(![socket acceptOnPort:port error:&error]) {
        [appDelegate showNotification:@"Error starting TCP interface" withDescription:[error description] tag:nil];
        NSLog(@"%@", [error description]);
        return nil;
    }
    
    return self;
}


-(void) socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    //NSLog(@"New connection from %@", [newSocket connectedHost]);
    @synchronized(clientList){
        [clientList addObject:newSocket];
    };
    
    // Read until newline occurs
    //[newSocket readDataToData:[GCDAsyncSocket LFData] withTimeout:30 tag:0];
    [newSocket readDataWithTimeout:10 tag:0];
}

-(NSTimeInterval) socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length {
    [sock writeData:[@"TIMEOUT\n" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:1 tag:0];
    [sock disconnectAfterWriting];
    
    return 0.0;
}

-(void) socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    @autoreleasepool {
        NSString* dataString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];

        NSArray* cmdParts = [dataString componentsSeparatedByString:@":"];
        NSMutableDictionary* options = [[NSMutableDictionary alloc] init];
        
        if(![[cmdParts objectAtIndex:0] isEqualToString:@"IS_STREAMING"] && ![[cmdParts objectAtIndex:0] isEqualToString:@"IS_RECORDING"]) {
            NSLog(@"%@: %@", [sock connectedHost], dataString);
        }
        if([cmdParts count] > 1) {
            for (NSString* part in cmdParts) {
                if (part != [cmdParts objectAtIndex:0]) {
                    NSArray* subParts = [part componentsSeparatedByString:@"="];
                    if([subParts count] == 2) {
                        [options setObject:[subParts objectAtIndex:1] forKey:[subParts objectAtIndex:0]];
                    }
                }
            }
        }
        
        __block NSData *response;
        dispatch_sync(dispatch_get_main_queue(), ^{
            response = [self parseCommand:[cmdParts objectAtIndex:0] withOptions:options];
        });
        
        [sock writeData:response withTimeout:5 tag:0];
        
        // Close connection immediately after write completes
        [sock disconnectAfterWriting];
    }
}

-(void) socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if(sock != socket) {
        @synchronized(clientList) {
            [clientList removeObject:sock];
        }
    }
}

-(NSData*) parseCommand:(NSString*) cmd withOptions:(NSDictionary*) options {
    NSString *response = @"INVALID";

    for (NSString* key in options) {
        //if ([key isEqualToString:@"username"] || [key isEqualToString:@"email"]) {
            [appDelegate setUserOption:[options objectForKey:key] forKey:key];
        //}
    }
    if ([options count] > 0) {
        [appDelegate updateMetadata];
    }
    
    if ([cmd isEqualToString:@"IS_RECORDING"]) {
        if([_recorder isConfirmedRecording]) {
            response = @"TRUE";
        } else {
            response = @"FALSE";
        }
    } else if([cmd isEqualToString:@"IS_STREAMING"]) {
        if([_recorder isConfirmedStreaming]) {
            response = @"TRUE";
        } else {
            response = @"FALSE";
        }
    } else if([cmd isEqualToString:@"START_RECORDING"]) {
        if(![_recorder isRecording]) {
            [_recorder startRecording];
            response = @"OK";
        } else {
            response = @"ERROR";
        }
    } else if([cmd isEqualToString:@"STOP_RECORDING"]) {
        if([_recorder isRecording]) {
            [_recorder stopRecording];
        }
        response = @"OK";
    } else if([cmd isEqualToString:@"IS_USB_RECORDING"]) {
        response = ([_recorder isUSBFileOpen]? @"TRUE": @"FALSE");
    } else if([cmd isEqualToString:@"IS_USB_AVAILABLE"]) {
        response = ([_recorder canRecordToUSB]? @"TRUE": @"FALSE");
    } else if([cmd isEqualToString:@"START_STREAMING"]) {
        if(![_recorder isStreaming]) {
            [_recorder startStreaming];
            response = @"OK";
        } else {
            response = @"ERROR";
        }
    } else if([cmd isEqualToString:@"STOP_STREAMING"]) {
        if([_recorder isStreaming]) {
            [_recorder stopStreaming];
        }
        response = @"OK";
    } else if([cmd isEqualToString:@"START_AUTOSNAPSHOTS"]) {
        if (![[_recorder autoSnapshot] isValid]) {
            [_recorder startAutoSnapshots];
            response = @"OK";
        } else {
            response = @"ERROR";
        }
    } else if([cmd isEqualToString:@"STOP_AUTOSNAPSHOTS"]) {
        if ([[_recorder autoSnapshot] isValid]) {
            [_recorder stopAutoSnapshots];
            response = @"OK";
        } else {
            response = @"ERROR";
        }
    } else if([cmd isEqualToString:@"IS_AUTOSNAPSHOTS_RUNNING"]) {
        if ([[_recorder autoSnapshot] isValid]) {
            response = @"TRUE";
        } else {
            response = @"FALSE";
        }
    } else if([cmd isEqualToString:@"TAKE_SNAPSHOT"]) {
        if(![_recorder isManualSnapshot]) {
            if ([options objectForKey:@"prefix"]) {
                [_recorder takeSnapshotWithPrefix:[options objectForKey:@"prefix"]];
            } else {
                [_recorder takeSnapshot];
            }
            response = @"OK";
        } else {
            response = @"ERROR";
        }
    } else if([cmd isEqualToString:@"GET_USER"]) {
        if([appDelegate getUserOption:@"username"]) {
            response = [appDelegate getUserOption:@"username"];
        } else {
            response = @"NOT_SET";
        }
    } else if([cmd isEqualToString:@"GET_EMAIL"]) { // Deprecated. Should be removed..
        if([appDelegate getUserOption:@"email"]) {
            response = [appDelegate getUserOption:@"email"];
        } else {
            response = @"NOT_SET";
        }
    } else if([cmd isEqualToString:@"CLEAR_USER"]) {
        [appDelegate clearUserOptions];
        response = @"OK";
    }
    
    return [[NSString stringWithFormat:@"%@\n",response] dataUsingEncoding:NSUTF8StringEncoding];
}
@end
