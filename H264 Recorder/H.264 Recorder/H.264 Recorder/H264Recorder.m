//
//  H264Recorder.m
//  H.264 Recorder
//
//  Created by Filip Sandborg-Olsen on 20/02/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import "H264Recorder.h"
#import "AppDelegate.h"

@implementation H264Recorder
- (H264Recorder*) initwithDelegate:(id) delegate {
    [self setIsEncoding:NO];
    [self setIsRecording:NO];
    [self setIsStreaming:NO];
    [self setIsConnected:NO];
    [self setIsPreviewing:NO];
    [self setIsManualSnapshot:NO];
    
    [self setIsConfirmedRecording:NO];
    [self setIsConfirmedStreaming:NO];
    
    statusLock = [[NSLock alloc] init];
    
    streamingStart = [NSDate dateWithTimeIntervalSince1970:0];
    recordingStart = [NSDate dateWithTimeIntervalSince1970:0];
    
    isTerminating = NO;
    
    _delegate = delegate;
    appDelegate = (AppDelegate*)[[NSApplication sharedApplication] delegate];
    
    deviceState = @"";
    deviceName = @"";
    deviceDisplayMode = @"";
    deviceInput = @"";
    
    dataCount = 0;
    
    width = 0;
    height = 0;
    interlaced = NO;
    
    
    q = dispatch_queue_create("com.learninglab.socketqueue", DISPATCH_QUEUE_SERIAL);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopSnapshot:) name:@"manualSnapshot" object:nil];
    
    frames = [[NSMutableArray alloc] init];
    [self setCmdSocket:[[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()]];
    [self setDataSocket:[[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:q]];
    
    isData = [[NSConditionLock alloc] initWithCondition:0];
    isConnection = [[NSConditionLock alloc] initWithCondition:1];

    
    [self performSelectorInBackground:@selector(dataWatcher) withObject:nil];
    [self performSelectorInBackground:@selector(statusPoller) withObject:nil];
    [self performSelectorInBackground:@selector(connectToRecorder) withObject:nil];
    
    [self setAutoSnapshot: [[NSTimer alloc] init]];
    
    return self;
}

-(void) reloadPreferences {
    if ([[appDelegate preferences] objectForKey:@"recordingDir"]) {
        outputFile = [[[appDelegate preferences] objectForKey:@"recordingDir"] stringByAppendingPathComponent:[@"Recording" stringByAppendingString:[[appDelegate preferences] objectForKey:@"outputFormat"]]];
        recordingDir = [[appDelegate preferences] objectForKey:@"recordingDir"];
    } else {
        outputFile = nil;
        recordingDir = nil;
    }
    if([[appDelegate preferences] objectForKey:@"streamUrl"] && [[appDelegate preferences] objectForKey:@"streamKey"]) {
        streamURL = [[[appDelegate preferences] objectForKey:@"streamUrl"] stringByAppendingPathComponent:[[appDelegate preferences] objectForKey:@"streamKey"]];
    } else {
        streamURL = nil;
    }
    if([[appDelegate preferences] objectForKey:@"streamingPassthrough"]) {
        streamingPassthrough = [[appDelegate preferences] boolForKey:@"streamingPassthrough"];
    } else {
        streamingPassthrough = NO;
    }
    if([[appDelegate preferences] objectForKey:@"streamAutoRestart"]) {
        streamAutoRestart = [[appDelegate preferences] boolForKey:@"streamAutoRestart"];
    } else {
        streamAutoRestart = YES;
    }
    
    if([[appDelegate preferences] objectForKey:@"x264preset"]) {
        x264preset = [[appDelegate preferences] objectForKey:@"x264preset"];
    } else {
        x264preset = @"veryfast";
    }
}

-(void) connectToRecorder {
    while(1) {
        [isConnection lockWhenCondition:1];
        if (isTerminating) {
            return;
        }
        
        if(![[self cmdSocket] isConnected]) {
            if(![[self cmdSocket] connectToHost:@"127.0.0.1" onPort:13823 error:nil]){
                NSLog(@"BAH!");
            }
            [[self cmdSocket] readDataWithTimeout:-1 tag:0];
        }
        if(![[self dataSocket] isConnected]) {
            [[self dataSocket] connectToHost:@"127.0.0.1" onPort:13823 error:nil];
            [[self dataSocket] readDataWithTimeout:-1 tag:0];
        }
        if([[self cmdSocket] isConnected] && [[self dataSocket] isConnected]) {
            [isConnection unlockWithCondition:0];
        } else {
            [isConnection unlockWithCondition:1];
        }
        sleep(1);
    }
}

-(void) sendCommandWithType:(NSString*)commandType {
    [self sendCommandWithType:commandType withCommand:nil andArguments:nil];
}
-(void) sendCommandWithType:(NSString*)commandType withCommand:(NSString*) command {
    [self sendCommandWithType:commandType withCommand:command andArguments:nil];
}



-(void) sendCommandWithType:(NSString*)commandType withCommand:(NSString*) command andArguments:(NSString*)arguments {
    NSString* cmd = nil;
    if (commandType != nil) {
        if (command != nil) {
            if (arguments != nil) {
                cmd = [NSString stringWithFormat:@"%@ -id %@ -%@ %@\n", commandType, [self recorderID], command, arguments];
            } else {
                cmd = [NSString stringWithFormat:@"%@ -id %@ -%@\n", commandType, [self recorderID], command];
            }
        } else {
            if ([commandType isEqualToString:@"notify"]) {
                cmd = [NSString stringWithFormat:@"%@\n", commandType];
            } else {
                cmd = [NSString stringWithFormat:@"%@ -id %@\n", commandType, [self recorderID]];
            }
        }
    }
    
    if(cmd != nil && [[self cmdSocket] isConnected]) {
        [[self cmdSocket] writeData:[cmd dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
        NSLog(@"Sent command: %@", cmd);
    } else {
        NSLog(@"Could not send command.");
    }
}

- (void) statusPoller {
    while(1){
        @autoreleasepool {
            if(isTerminating) {
                return;
            }
            if(![self isEncoding] && [self isConnected]) {
                if (![deviceDisplayMode isEqualToString:@"Unknown"] && ![deviceDisplayMode isEqualToString:@""] && ![deviceState isEqualToString:@"Unknown"]) {
                    NSString* resPrefs = nil;
                    NSArray* pParts = [deviceDisplayMode componentsSeparatedByString:@"p"];
                    NSArray* iParts = [deviceDisplayMode componentsSeparatedByString:@"i"];
                    NSArray* parts;
                    if ([pParts count] == 1) {
                        interlaced = YES;
                        parts = iParts;
                    } else {
                        parts = pParts;
                        interlaced = NO;
                    }
                    if ([parts count] == 2) {
                        height = [[parts objectAtIndex:0] intValue];
                        width = [[parts objectAtIndex:0] intValue] * 16/9;
                        framerate = [[parts objectAtIndex:1] intValue];

                        resPrefs = [NSString stringWithFormat:@"-fps %d%c -srcx 0 -srcy 0 -srcw %d -srch %d -dstw %d -dsth %d", framerate, (interlaced?'i':'p'), width, height, width, height];
                    }
                    if(resPrefs) {
                        [self sendCommandWithType:@"set" withCommand:@"encoding" andArguments:[NSString stringWithFormat:@"%@ -vkbps %@ -profile high -level 40 -cabac 0 -bframes 0 -arate 48000 -achannels 2 -abits 16 -akbps 256 -preset 0", resPrefs, [[appDelegate preferences] objectForKey:@"H264VideoBitrate"]]];
                    } else {
                        NSLog(@"ERROR: Unknown format %@", deviceDisplayMode);
                    }
                    [self performSelectorOnMainThread:@selector(sendCommandWithType:) withObject:@"start" waitUntilDone:YES];
                }
            }
        }
        sleep(1);
    }
}

-(void) videoPreview {
    @autoreleasepool {
        [self setIsPreviewing:YES];
        previewTask = [[NSTask alloc] init];
        [previewTask setLaunchPath:@"/Applications/VLC.app/Contents/MacOS/VLC"];
        [previewTask setArguments:@[@"-",@"--quiet", @"--no-audio", @"--play-and-stop"]];
        [previewTask setStandardInput:[NSPipe pipe]];
        previewInput = [[previewTask standardInput] fileHandleForWriting];
        [previewTask launch];
        sleep(5);
        [[[NSAppleScript alloc] initWithSource:@"tell application \"VLC\" to set the bounds of the front window to {600,212,1240,630}"] executeAndReturnError:nil];
        [previewTask waitUntilExit];
        [self setIsPreviewing:NO];
    }
}

-(void) stopPreview {
    if([self isPreviewing] && [previewTask isRunning]) {
        kill([previewTask processIdentifier], SIGKILL);
    }
}

#pragma mark AsyncSocketDelegate


-(void) socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    if([sock isEqualTo:[self cmdSocket]]){
        NSLog(@"CMDConnection established!");
        [self sendCommandWithType:@"notify"];
    } else {
        NSLog(@"DataConnection established!");
        if([self recorderID]) {
            [[self dataSocket] writeData:[[NSString stringWithFormat:@"receive -id %@ -transport tcp\n", [self recorderID]] dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:1];
        }
    }
}
-(void) socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    NSLog(@"Socket did disconnect. Attempting reconnect");
    if([isConnection condition] == 0) {
        [isConnection lock];
        [isConnection unlockWithCondition:1];
    }
}
-(void) onSocket:(GCDAsyncSocket *)sock willDisconnectWithError:(NSError *)err {
    //NSLog(@"Socket disconnected with error %@", err);
}
-(void) socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if ([sock isEqual:[self dataSocket]]) {
        @synchronized(frames) {
//            if([frames count] > 100) {
//                [self stopPreview];
//            }
            if([frames count] > 1000) {
                [frames removeLastObject];
                NSLog(@"Dropping frame!!!");
            }
            [frames insertObject:data atIndex:0];
        }
        if([isData condition] == 0) {
            [isData lock];
            [isData unlockWithCondition:1];
        }
    } else if([sock isEqual:[self cmdSocket]]) {
        NSString* dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        for (NSString* line in [dataStr componentsSeparatedByString:@"\n"]) {
            NSArray* parts = [line componentsSeparatedByString:@":"];
            if ([[parts objectAtIndex:0] isEqualToString:@"arrived"]) {
                NSArray *subParts;
                if ([parts objectAtIndex:1]!=nil) {
                    subParts = [[[parts objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@" "];
                    [self setRecorderID:[[NSNumberFormatter alloc] numberFromString:[subParts objectAtIndex:0]]];
                    NSLog(@"Recorder ID: %@", [self recorderID]);
                    [self sendCommandWithType:@"stop"];
                    deviceName = [parts objectAtIndex:1];
                }
                [self setIsConnected:YES];
            } else if([line hasPrefix:@"device"]) {
                deviceState = [[line componentsSeparatedByString:@" "] lastObject];
                if([line hasSuffix:@"idle"]) {
                    NSLog(@"Device is not encoding.");
                    [self setIsEncoding:NO];
                } else if ([line hasSuffix:@"encoding"]) {
                    [self setIsEncoding:YES];
                    NSLog(@"Encoding started. Restarting dataconnection to be safe..");
                    [[self dataSocket] disconnect];
                    dataCount = 0;
                    [self performSelector:@selector(checkDataCount) withObject:nil afterDelay:5.0f];
                }
                
                if (![line hasSuffix:@"Unknown"]) {
                    [appDelegate dismissNotificationIfTagName:@"unknownState"];
                }
            } else if([line hasPrefix:@"connector"]) {
                deviceInput = [[line componentsSeparatedByString:@" "] lastObject];
            } else if([line hasPrefix:@"input"]) {
                deviceDisplayMode = [[line componentsSeparatedByString:@" "] lastObject];
            } else if([line hasPrefix:@"removed"]) {
                deviceName = @"Not connected";
                deviceState = @"Not connected";
                deviceInput = @"Not connected";
                deviceDisplayMode = @"Not connected";
                [self setIsEncoding:NO];
                [self setIsConnected:NO];
                [self setRecorderID:nil];
            } else if ([line hasPrefix:@"Error"]) {
                if([line hasSuffix:[NSString stringWithFormat:@"set -id %@", [self recorderID]]]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [appDelegate showNotification:@"Error setting encoder settings" withDescription:@"An error occured setting the encoder settings on the recorder device. The recorder will use default settings." tag:nil];
                    });
                }
            } else {
                NSLog(@"%@", line);
            }
            [_delegate stateUpdate:@{@"deviceState": deviceState, @"deviceInput": deviceInput, @"deviceDisplayMode": deviceDisplayMode, @"deviceName": deviceName}];
        }
    } else {
        NSLog(@"UNKNOWN SOCKET!!");
    }
    [sock readDataWithTimeout:-1 tag:0];
}

-(void) socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    NSLog(@"Partial data...");
}

-(BOOL) startStreaming {
    [self reloadPreferences];
    if(!streamURL) {
        return NO;
    }
    if (![self isStreaming] && [self isConnected]) {
        [statusLock lock];
        streamingStart = [NSDate date];
        [statusLock unlock];
        
        if(streamingPassthrough) {
            streaming = [[FFMpegWrapper alloc] initWithArguments:[[NSString stringWithFormat:@"-fflags nobuffer -i - -c copy -c:a libmp3lame -ar 44100 -b:a %@k -f flv %@", [[appDelegate preferences] objectForKey:@"audioBitrate"], streamURL] componentsSeparatedByString:@" "] autoRestart:streamAutoRestart label:@"streaming"];
        } else {
            streaming = [[FFMpegWrapper alloc] initWithArguments:[[NSString stringWithFormat:@"-fflags nobuffer -i - -acodec libmp3lame -ar 44100 -b:a %@k -vcodec libx264 -b:v %@k -preset %@ -tune zerolatency -f flv %@", [[appDelegate preferences] objectForKey:@"audioBitrate"],[[appDelegate preferences] objectForKey:@"videoBitrate"], x264preset ,streamURL] componentsSeparatedByString:@" "] autoRestart:streamAutoRestart label:@"streaming"];
        }
        [self setIsStreaming:YES];
        [self setIsConfirmedStreaming:YES];
    }
    return YES;
}

-(void) stopStreaming {
    [streaming terminateTask];
    [self setIsStreaming:NO];
    [statusLock lock];
    [self setIsConfirmedStreaming:NO];
    streamingStart = [NSDate date];
    [statusLock unlock];
}

-(BOOL) startRecording {
    if(![self isRecording] && [self isConnected]) {
        [statusLock lock];
        recordingStart = [NSDate date];
        [statusLock unlock];
        
        [self reloadPreferences];
        currentRecordingFormat = [[[appDelegate preferences] objectForKey:@"outputFormat"] copy];
        currentOutputFile = [outputFile copy];
        BOOL isDirectory = YES;
        if(![[NSFileManager alloc] fileExistsAtPath:recordingDir isDirectory:&isDirectory]) {
            [[NSFileManager alloc] createDirectoryAtPath:recordingDir withIntermediateDirectories:NO attributes:nil error:nil];
        }
        
        if ([[NSFileManager alloc] fileExistsAtPath:recordingDir isDirectory:&isDirectory] && [[NSFileManager alloc] isWritableFileAtPath:recordingDir]) {
            recording = [[FFMpegWrapper alloc] initWithArguments:@[@"-analyzeduration", @"1000000", @"-i", @"-", @"-s", [NSString stringWithFormat:@"%dx%d", width, height], @"-r", @"50", @"-acodec", @"aac", @"-b:a", @"128k", @"-strict", @"-2", @"-vcodec", @"copy", currentOutputFile, @"-y"] autoRestart:NO label:@"recording"];
            [self setIsRecording:YES];
            [self setIsConfirmedRecording:YES];
            return YES;
        }
    }
    return NO;
}

-(NSString*) createPathWithFilename:(NSString*)filename inDir: (NSString*) dir {
    NSString* path;
    if ([appDelegate getUserOption:@"username"]) {
        NSString* userDir = [dir stringByAppendingPathComponent:[appDelegate getUserOption:@"username"]];
        if(![[NSFileManager alloc]fileExistsAtPath:userDir]) {
            [[NSFileManager alloc] createDirectoryAtPath:userDir withIntermediateDirectories:NO attributes:nil error:nil];
        }
        path = [[dir stringByAppendingPathComponent:[appDelegate getUserOption:@"username"]] stringByAppendingPathComponent:filename];
    } else {
        path = [dir stringByAppendingPathComponent:filename];
    }
    
    if(![[[[path stringByStandardizingPath] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] isEqualToString:dir] && ![[[path stringByStandardizingPath] stringByDeletingLastPathComponent] isEqualToString:dir]) {
        NSLog(@"Potentially malicious path.. Saving to root folder.");
        return [dir stringByAppendingPathComponent:filename];
    } else {
        return [path stringByStandardizingPath];
    }
}

-(BOOL) takeSnapshot {
    return [self takeSnapshotWithPrefix: @"snapshot"];
}

-(void) takeAutoSnapshot {
    [self takeSnapshotWithPrefix:@"auto" toDirectory:[[appDelegate preferences] objectForKey:@"autoSnapshotsDirectory"]];
}
-(BOOL) takeSnapshotWithPrefix: (NSString*) prefix {
    return [self takeSnapshotWithPrefix:prefix toDirectory:[[appDelegate preferences] objectForKey:@"snapshotsDirectory"]];
}

-(NSString*) formattedDate {
    NSDateFormatter* formatter = [[NSDateFormatter alloc] initWithDateFormat:@"%Y%m%d%H%M%S" allowNaturalLanguage:YES];
    return [formatter stringFromDate:[NSDate date]];
}

-(BOOL) takeSnapshotWithPrefix: (NSString*) prefix toDirectory: (NSString*) dir {
    if (![self isManualSnapshot] && [self isConnected]) {
        [self reloadPreferences];
        BOOL isDirectory = YES;
        if(![[NSFileManager alloc] fileExistsAtPath:dir isDirectory:&isDirectory]) {
            [[NSFileManager alloc] createDirectoryAtPath:dir withIntermediateDirectories:NO attributes:nil error:nil];
        }
        
        
        if ([[NSFileManager alloc] fileExistsAtPath:dir isDirectory:&isDirectory] && [[NSFileManager alloc] isWritableFileAtPath:dir]) {
            NSString *filename = [self createPathWithFilename:[NSString stringWithFormat:@"%@-%@.png", prefix, [self formattedDate]] inDir:dir];
            NSLog(@"Saving snapshot to %@", filename);
            manualSnapshot = [[FFMpegWrapper alloc] initWithArguments:@[@"-analyzeduration", @"500000", @"-f", @"mpegts", @"-i", @"-", @"-frames", @"1", @"-f", @"image2", filename] autoRestart:NO label:@"manualSnapshot"];
            [self setIsManualSnapshot:YES];
            return YES;
        }
    }
    return NO;
}

-(void) checkDataCount {
    //NSLog(@"Datacount: %f", dataCount);
    if (dataCount < 1) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate showNotification:@"Error" withDescription:@"Did not receive any data from the recorder within the first 5 seconds. Try toggling USB/Power." tag:nil ];
        });
    }
}

-(void) stopRecording {
    [stopLock lock];
    if([self isRecording]) {
        [statusLock lock];
        [self setIsConfirmedRecording:NO];
        recordingStart = [NSDate date];
        [statusLock unlock];
        [recording terminateTask];
        NSString* finalPath = [self createPathWithFilename:[NSString stringWithFormat:[@"video-%@" stringByAppendingString:currentRecordingFormat], [self formattedDate]] inDir:recordingDir];
        
        [[NSFileManager alloc] moveItemAtPath:currentOutputFile toPath:finalPath error:nil];
        [self setIsRecording:NO];
    }
    [stopLock unlock];
}

-(void) stopSnapshot: (NSNotification*)n {
    if([[n object] isEqualToString:@"stopped"]) {
        [manualSnapshot terminateTask];
        [self setIsManualSnapshot:NO];
        NSLog(@"Stopping snapshot..");
    }
}

-(void) startAutoSnapshots {
    if (![[self autoSnapshot] isValid]) {
        [self setAutoSnapshot:[NSTimer scheduledTimerWithTimeInterval:[[[appDelegate preferences] objectForKey:@"autoSnapshotsInterval"] integerValue] target:self selector:@selector(takeAutoSnapshot) userInfo:nil repeats:YES]];
        [[self autoSnapshot] fire];
    }
}

-(void) stopAutoSnapshots {
    if([[self autoSnapshot] isValid]) {
        [[self autoSnapshot] invalidate];
    }
}

//-(void) dataWatcher {
//    
//    dispatch_queue_t previewqueue = dispatch_queue_create("com.h264.preview", DISPATCH_QUEUE_SERIAL);
//    dispatch_queue_t streamqueue = dispatch_queue_create("com.h264.streaming", DISPATCH_QUEUE_SERIAL);
//    dispatch_queue_t recordqueue = dispatch_queue_create("com.h264.record", DISPATCH_QUEUE_SERIAL);
//    dispatch_queue_t snapshotqueue = dispatch_queue_create("com.h264.snapshot", DISPATCH_QUEUE_SERIAL);
//
//    while (1) {
//        [isData lockWhenCondition:1];
//        @synchronized(frames) {
//            while ([frames count] > 0) {
//                @autoreleasepool {
//
//                    dataCount += [[frames lastObject] length];
//                    BOOL Iframe = [self parseFrame:[frames lastObject]];
//                    NSData* frame = [frames lastObject];
//                    
//                    if([self isStreaming]){
//                        if([streaming hasStarted] || Iframe) {
//                            dispatch_async(streamqueue, ^{
//                                [streaming writeData:frame];
//                            });
//                        }
//                    }
//                    if([self isRecording]) {
//                        if([recording hasStarted] || Iframe) {
//                            dispatch_async(recordqueue, ^{
//                                [recording writeData:frame];
//                            });
//                        }
//                    }
//                    if([self isManualSnapshot]) {
//                        if([manualSnapshot hasStarted] || Iframe) {
//                            dispatch_async(snapshotqueue, ^{
//                                [manualSnapshot writeData:frame];
//                            });
//                        }
//                    }
//                    
//                    if([self isPreviewing]) {
//                            dispatch_async(previewqueue, ^(void) {
//                                @autoreleasepool {
//                                    @try {
//                                        [previewInput writeData:frame];
//                                    }
//                                    @catch (NSException *exception) {
//                                        
//                                    } @finally {
//
//                                    }
//                                }
//                            });
//                    }
//                    [frames removeLastObject];
//                }
//            }
//        }
//        [isData unlockWithCondition:0];
//    }
//}

-(void) dataWatcher {
    BOOL Iframe;
    while (1) {
        [isData lockWhenCondition:1];
            @synchronized(frames) {
            while ([frames count] > 0) {
                @autoreleasepool {
                    dataCount += [[frames lastObject] length];
                    Iframe = [self parseFrame:[frames lastObject]];
                    
                    if([self isStreaming]){
                        if([streaming hasStarted] || Iframe) {
                            [streaming writeData:[frames lastObject]];
                        }
                    }
                    if([self isRecording]) {
                        if([recording hasStarted] || Iframe) {
                            [recording writeData:[frames lastObject]];
                        }
                    }
                    if([self isManualSnapshot]) {
                        if([manualSnapshot hasStarted] || Iframe) {
                            [manualSnapshot writeData:[frames lastObject]];
                        }
                    }
                    
                    if([self isPreviewing]) {
                            @try {
                                [previewInput writeData:[frames lastObject]];
                            }
                            @catch (NSException *exception) {
                                
                            } @finally {
                                
                            }
                    }
                    
                    [frames removeLastObject];
                }
            }
        }
        [isData unlockWithCondition:0];
    }
}


- (BOOL) checkStreaming {
    [statusLock lock];
    @autoreleasepool {
        if([[NSDate date] timeIntervalSinceDate:streamingStart] > 10.0f) {
        
            NSTask *streamChecker = [[NSTask alloc] init];
            NSPipe* outputPipe = [NSPipe pipe];
            if(outputPipe) {
                [streamChecker setLaunchPath:@"/bin/sh"];
                [streamChecker setArguments:@[@"-c", @"lsof -iTCP -n | grep ffmpeg | grep ESTABLISHED | grep macromedia-fcs"]];
                [streamChecker setStandardOutput:outputPipe];
                @try{
                    [streamChecker launch];
                }@catch (NSException* exception) {
                    NSLog(@"Caught exception %@ %@", [exception name], [exception description]);
                    [statusLock unlock];
                    return NO;
                }
                
                [streamChecker waitUntilExit];
                NSString* output = [[[NSString alloc] initWithData:[[[streamChecker standardOutput] fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                
                if ([output hasPrefix:@"ffmpeg"]) {
                    [self setIsConfirmedStreaming:YES];
                } else {
                    [self setIsConfirmedStreaming:NO];
                }
            } else {
                NSLog(@"Could not open pipe!");
                [self setIsConfirmedStreaming:NO];
            }
        }
    }
    [statusLock unlock];
    return [self isConfirmedStreaming];
}

-(void) recordingStatus: (NSNotification*)n {
    NSString* state = [n object];
    if([state isEqualToString: @"stopped"]) {
        [self stopRecording];
    }
}

-(void) terminate {
    isTerminating = YES;
    [self sendCommandWithType:@"stop"];
    [[self dataSocket] disconnectAfterReading];
    [[self cmdSocket] disconnectAfterReadingAndWriting];
    [self stopPreview];
}

-(BOOL) parseFrame: (NSData*) frame {
    @autoreleasepool {
        BOOL hasSPS = NO;
        BOOL hasPPS = NO;
        BOOL isIFrame = NO;
        
        NSUInteger length = [frame length];
        unsigned char* ptr = (unsigned char *) [frame bytes];
        if(ptr[0] == 0x47) {
        NSUInteger payload_begin = 4;
        if(!(ptr[3] << 4)) {
            NSLog(@"No payload in NAL");
        } else {
            if(ptr[3] << 5) {
                payload_begin += ptr[4];
            }

            long i = payload_begin;
            while(i+4 < length) {
                if (ptr[i]== 0 && ptr[i+1] == 0 && ptr[i+2] == 1) {
                    if((ptr[i+3] & 0x1f) == 5) {
                        isIFrame = YES;
                    }
                    if((ptr[i+3] & 0x1f) == 7) {
                        hasSPS = YES;
                    }
                    if((ptr[i+3] & 0x1f) == 8) {
                        hasPPS = YES;
                    }
                }
                if(hasPPS && hasSPS && isIFrame) {
                    return YES;
                }
                i++;
            }
        }
        }
    }
    return NO;
}

-(BOOL) checkRecording {
    [statusLock lock];
    if([[NSDate date] timeIntervalSinceDate:recordingStart] > 10.0f) {
        NSFileManager* fm = [[NSFileManager alloc] init];
        if([fm fileExistsAtPath:outputFile]) {
            NSError* err = nil;
            NSDictionary* attributes = [fm attributesOfItemAtPath:outputFile error:&err];
            if (attributes && !err) {
                NSLog(@"%f", [[attributes fileModificationDate] timeIntervalSinceNow]);
                if([[attributes fileModificationDate] timeIntervalSinceNow] > -5.0f) {
                    [self setIsConfirmedRecording:YES];
                } else {
                    [self setIsConfirmedRecording:NO];
                }
            } else {
                [self setIsConfirmedRecording: NO];
            }
        } else {
            [self setIsConfirmedRecording:NO];
        }
    }
    [statusLock unlock];
    return [self isConfirmedRecording];
    
}

-(BOOL) oldCheckRecording {
    @autoreleasepool {
        [statusLock lock];
        if([[NSDate date] timeIntervalSinceDate:recordingStart] > 10.0f) {
            NSFileManager* fm = [[NSFileManager alloc] init];
            NSPipe* outputPipe = [NSPipe pipe];
            if([fm fileExistsAtPath:outputFile]) {
                if(outputPipe) {
                    NSTask *streamChecker = [[NSTask alloc] init];
                    [streamChecker setLaunchPath:@"/bin/sh"];
                    [streamChecker setArguments:@[@"-c", [NSString stringWithFormat:@"lsof \"%@\" | sed 1d", outputFile]]];
                    [streamChecker setStandardOutput:outputPipe];
                    @try {
                        [streamChecker launch];
                    }
                    @catch (NSException *exception) {
                        NSLog(@"Caught exception %@ %@", [exception name], [exception description]);
                        [statusLock unlock];
                        return NO;
                    }
                    [streamChecker waitUntilExit];
                    NSString* output = [[[NSString alloc] initWithData:[[[streamChecker standardOutput] fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    
                    if ([output hasPrefix:@"ffmpeg"]) {
                        [self setIsConfirmedRecording:YES];
                    } else {
                        [self setIsConfirmedRecording:NO];
                    }
                } else {
                    NSLog(@"Could not open pipe!");
                    [self setIsConfirmedRecording:NO];
                }
            } else {
                [self setIsConfirmedRecording:NO];
            }
        }
        [statusLock unlock];
    }
    
    return [self isConfirmedRecording];
}

@end
