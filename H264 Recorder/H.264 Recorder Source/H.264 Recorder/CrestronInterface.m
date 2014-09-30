//
//  CrestronInterface.m
//  H.264 Recorder
//
//  Created by Filip Sandborg-Olsen on 28/08/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import "CrestronInterface.h"

#import "AppDelegate.h"
#import "H264Recorder.h"

@implementation CrestronInterface

-(CrestronInterface*) initWithPort:(uint16_t)port andRecorder:(H264Recorder*)recorder {
    
    _recorder = recorder;
    queue = dispatch_queue_create("CrestronInterface", NULL);
    
    appDelegate = (AppDelegate*)[[NSApplication sharedApplication] delegate];
    
    socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:queue];
    
    clientList = [[NSMutableArray alloc] initWithCapacity:1];
    
    NSError* error = nil;
    if(![socket acceptOnPort:port error:&error]) {
        [appDelegate showNotification:@"Error starting Crestron Interface" withDescription:[error description] tag:nil];
        NSLog(@"%@", [error description]);
        return nil;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recordingStatus:) name:@"recording" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(streamingStatus:) name:@"streaming" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(autosnapshotStatus:) name:@"autoSnapshot" object:nil];
    
    return self;
}

-(void) autosnapshotStatus: (NSNotification*)n {
    NSString* state = [n object];
    NSString* MSG = @"";
    if ([state isEqualToString:@"stopped"]) {
        MSG = @"AUTOSNAPSHOT_STATUS=STOPPED";
    } else if([state isEqualToString:@"started"]) {
        MSG = @"AUTOSNAPSHOT_STATUS=STARTED";
    }
    if (![MSG isEqualToString:@""]) {
        @synchronized(clientList) {
            for (GCDAsyncSocket* sock in clientList) {
                [sock writeData:[[NSString stringWithFormat:@"%@\n", MSG] dataUsingEncoding:NSUTF8StringEncoding] withTimeout:5 tag:0];
            }
        }
    }
}

-(void) streamingStatus:(NSNotification*) n {
    NSString* state = [n object];
    NSString* MSG = @"";
    if ([state isEqualToString:@"stopped"]) {
        MSG = @"STREAMING_STATUS=STOPPED";
    } else if([state isEqualToString:@"started"]) {
        MSG = @"STREAMING_STATUS=STARTED";
    }
    if (![MSG isEqualToString:@""]) {
        @synchronized(clientList) {
            for (GCDAsyncSocket* sock in clientList) {
                [sock writeData:[[NSString stringWithFormat:@"%@\n", MSG] dataUsingEncoding:NSUTF8StringEncoding] withTimeout:5 tag:0];
            }
        }
    }
}

-(void) recordingStatus:(NSNotification*) n {
    NSString* state = [n object];
    NSString* MSG = @"";
    if ([state isEqualToString:@"stopped"]) {
        MSG = @"RECORD_STATUS=STOPPED";
    } else if([state isEqualToString:@"started"]) {
        MSG= @"RECORD_STATUS=STARTED";
    }
    if (![MSG isEqualToString:@""]) {
        @synchronized(clientList) {
            for (GCDAsyncSocket* sock in clientList) {
                [sock writeData:[[NSString stringWithFormat:@"%@\n", MSG] dataUsingEncoding:NSUTF8StringEncoding] withTimeout:5 tag:0];
            }
        }
    }
}


-(void) socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    NSLog(@"New connection %@ from %@", [newSocket debugDescription], [newSocket connectedHost]);
    @synchronized(clientList){
        [clientList addObject:newSocket];
    };
    
    // Read until newline occurs
    [newSocket readDataToData:[GCDAsyncSocket LFData] withTimeout:-1 tag:0];
    //[newSocket readDataWithTimeout:-1 tag:0];
}

-(NSTimeInterval) socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length {
    [sock writeData:[@"TIMEOUT\n" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:1 tag:0];
    [sock disconnectAfterWriting];
    
    return 0.0;
}

-(void) socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    @autoreleasepool {
        NSString* dataString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        NSLog(@"Received data: %@", dataString);
        NSArray* cmdParts = [dataString componentsSeparatedByString:@":"];
        NSMutableDictionary* options = [[NSMutableDictionary alloc] init];
        
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
        
        if (response != nil) {
            [sock writeData:response withTimeout:5 tag:0];
        }
        // Close connection immediately after write completes
        //[sock disconnectAfterWriting];
        [sock readDataToData:[GCDAsyncSocket LFData] withTimeout:-1 tag:0];
    }
}

-(void) socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if(sock != socket) {
        NSLog(@"Client %@ disconnected", [sock debugDescription]);
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
    
    if ([cmd isEqualToString:@"PING"]) {
        response = @"ACK";
    } else if ([cmd isEqualToString:@"RECORD_STATUS?"]) {
        if([_recorder isConfirmedRecording]) {
            response = @"RECORD_STATUS=STARTED";
        } else {
            response = @"RECORD_STATUS=STOPPED";
        }
    } else if([cmd isEqualToString:@"STREAMING_STATUS?"]) {
        if([_recorder isConfirmedStreaming]) {
            response = @"STREAMING_STATUS=STARTED";
        } else {
            response = @"STREAMING_STATUS=STOPPED";
        }
    } else if([cmd isEqualToString:@"RECORD_START"]) {
        if(![_recorder isRecording]) {
            [_recorder startRecording];
            response = @"RECORD_STATUS=STARTED";
        } else {
            response = @"RECORD_STATUS=ERROR";
        }
        response = nil;
    } else if([cmd isEqualToString:@"RECORD_STOP"]) {
        if([_recorder isRecording]) {
            [_recorder stopRecording];
        }
        response = @"RECORD_STATUS=STOPPED";
        response = nil;
    } else if([cmd isEqualToString:@"USB_STATUS"]) {
        response = ([_recorder isUSBFileOpen]? @"USB_STATUS=STARTED": @"USB_STATUS=STOPPED");
    } else if([cmd isEqualToString:@"USB_AVAILABLE"]) {
        response = ([_recorder canRecordToUSB]? @"USB_AVAILABLE=YES": @"USB_AVAILABLE=NO");
    } else if([cmd isEqualToString:@"USB_VOLUME_NAME"]) {
        response = [@"USB_VOLUME_NAME=" stringByAppendingString:[_recorder getUSBVolumeName]];
    } else if([cmd isEqualToString:@"STREAM_START"]) {
        if(![_recorder isStreaming]) {
            [_recorder startStreaming];
            response = @"STREAMING_STATUS=STARTED";
        } else {
            response = @"STREAMING_STATUS=ERROR";
        }
        response = nil;
    } else if([cmd isEqualToString:@"STREAM_STOP"]) {
        if([_recorder isStreaming]) {
            [_recorder stopStreaming];
        }
        response = @"STREAMING_STATUS=STOPPED";
        response = nil;
    } else if([cmd isEqualToString:@"AUTOSNAPSHOTS_START"]) {
        if (![[_recorder autoSnapshot] isValid]) {
            [_recorder startAutoSnapshots];
        }
        response = nil;
    } else if([cmd isEqualToString:@"AUTOSNAPSHOTS_STOP"]) {
        if ([[_recorder autoSnapshot] isValid]) {
            [_recorder stopAutoSnapshots];
        }
        response = nil;
    } else if([cmd isEqualToString:@"AUTOSNAPSHOTS_STATUS?"]) {
        if ([[_recorder autoSnapshot] isValid]) {
            response = @"AUTOSNAPSHOTS_STATUS=STARTED";
        } else {
            response = @"AUTOSNAPSHOTS_STATUS=STOPPED";
        }
    } else if([cmd isEqualToString:@"SNAPSHOT_TAKE"]) {
        if(![_recorder isManualSnapshot]) {
            if ([options objectForKey:@"prefix"]) {
                [_recorder takeSnapshotWithPrefix:[options objectForKey:@"prefix"]];
            } else {
                [_recorder takeSnapshot];
            }
            response = @"SNAPSHOT_STATUS=EXECUTED";
        } else {
            response = @"SNAPSHOT_STATUS=ERROR";
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
    
    if (response == nil) {
        return nil;
    }
    
    return [[NSString stringWithFormat:@"%@\n",response] dataUsingEncoding:NSUTF8StringEncoding];
}
@end
