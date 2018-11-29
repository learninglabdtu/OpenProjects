//
//  MediaPoolWatcher.m
//  ATEM Media Pool Updater
//
//  Created by Filip Sandborg-Olsen on 31/01/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import "MediaPoolWatcher.h"
#import "SwitcherMediaPoolAppDelegate.h"

@implementation MediaPoolWatcher
@synthesize terminating;
@synthesize stillsCount;
@synthesize mIP = _mIP;
@synthesize mPath = _mPath;

-(void) downloadStill:(uint32_t)index {
    currentIndex = index;
    [self updateNextStill];
}


-(NSString*) hexHash: (uint8_t*) hash {
    NSMutableString *str = [[NSMutableString alloc] init];
    for (int i = 0; i<16; i++) {
        [str appendFormat:@"%02x",hash[i]];
    }
    return str;
}


-(void) pullStills {
    NSFileManager *fm = [[NSFileManager alloc] init];
    JSONData = [[NSMutableDictionary alloc] init];
    [self updateJSON];
    
    NSLog(@"Deleting existing local stills..");
    NSString* stillPath;
    for(int i = 0; i<stillsCount; i++) {
        stillPath = [_mPath stringByAppendingPathComponent:[NSString stringWithFormat:@"IMAGE_%d", i]];
        [fm removeItemAtPath:stillPath error:nil];
    }
    
    NSLog(@"Pulling stills from switcher..");
    for (int i = 0; i<stillsCount; i++) {
        BMDSwitcherHash hash;
        stills->GetHash(i, &hash);
        if ([[self hexHash:hash.data] isEqualToString:@"00000000000000000000000000000000"]) {
            continue;
        }
        CFStringRef name = (__bridge CFStringRef) @"";
        stills->GetName(i, &name);
        [updateList addObject:@{
                                    @"index": [NSNumber numberWithInt:i],
                                    @"reason":@"NOT_IN_JSON",
                                    @"hash": [self hexHash:hash.data],
                                    @"title": (__bridge NSString*) name
                                    }];
    }
    [self updateNextStill];
}

-(bool) localStillsExist {
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString* localPath;
    for (int i = 0; i<stillsCount; i++) {
        localPath = [_mPath stringByAppendingPathComponent:[NSString stringWithFormat:@"IMAGE_%d", i]];
        if ([fm fileExistsAtPath:localPath]) {
            return true;
        }
    }
    return false;
}

-(void) pushStills {
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString* stillPath;
    
    mediaPool->Clear();
    
    NSLog(@"Pushing stills to switcher..");
    for (int i = 0; i<stillsCount; i++) {
        stillPath = [_mPath stringByAppendingPathComponent:[NSString stringWithFormat:@"IMAGE_%d", i]];
        if ([fm fileExistsAtPath:stillPath]) {
            BMDSwitcherHash hash;
            stills->GetHash(i, &hash);
            CFStringRef name = (__bridge CFStringRef) @"";
            stills->GetName(i, &name);
            [updateList addObject:@{
                                    @"index": [NSNumber numberWithInt:i],
                                    @"reason":@"HASH_MISMATCH",
                                    @"hash": [self hexHash:hash.data],
                                    @"title": (__bridge NSString*) name
                                    }];
        }
    }
    [self updateNextStill];
}

-(bool) stillsAreValid {
    bool valid = true;
    for (int i = 0; i<stillsCount; i++) {
        NSDictionary* element = [JSONData objectForKey:[[NSNumber numberWithInt:i] stringValue]];
        BMDSwitcherHash hash;
        stills->GetHash(i, &hash);
        CFStringRef name = (__bridge CFStringRef) @"";
        stills->GetName(i, &name);
        if (element != nil) {
            if (![[element objectForKey:@"hash"] isEqualToString:[self hexHash:hash.data]]) {
                NSLog(@"Hash mismatch on still %d on %@", i, _mIP);
                valid = false;
            }
        } else if(element == nil && ![[self hexHash:hash.data] isEqualToString:@"00000000000000000000000000000000"]) {
            valid = false;
            NSLog(@"Additional still %d on %@", i, _mIP);
        }
    }
    
    return valid;
}

-(void) autoUpdateStills {
    for (int i = 0; i<stillsCount; i++) {
        NSDictionary* element = [JSONData objectForKey:[[NSNumber numberWithInt:i] stringValue]];
        BMDSwitcherHash hash;
        stills->GetHash(i, &hash);
        CFStringRef name = (__bridge CFStringRef) @"";
        stills->GetName(i, &name);
        if (element != nil) {
            if ([[element objectForKey:@"hash"] isEqualToString:[self hexHash:hash.data]]) {
                NSLog(@"Index %d matches stored hash", i);
            } else {
                [updateList addObject:@{
                                        @"index": [NSNumber numberWithInt:i],
                                        @"reason":@"HASH_MISMATCH",
                                        @"hash":[self hexHash:hash.data],
                                        @"title": (__bridge NSString*)name
                                    }];
            }
        } else if (element == nil && ![[self hexHash:hash.data] isEqualToString:@"00000000000000000000000000000000"]) {
            stills->SetInvalid(i);
        }
    }
    [self updateNextStill];
}

-(void) updateJSON {
    NSOutputStream *file = [NSOutputStream outputStreamToFileAtPath:JSONFile append:NO];
    [file open];
    [NSJSONSerialization writeJSONObject:JSONData toStream:file options:NSJSONWritingPrettyPrinted error:nil];
    [file close];
}

-(void) connectToSwitcher {
    while (true) {
        if(terminating) {
            return;
        }
        [mUIDelegate performSelectorOnMainThread:@selector(setStatusMsg:) withObject:@{@"ip":_mIP, @"status":@"Trying to connect..."} waitUntilDone:NO];
        BMDSwitcherConnectToFailure failure;
        
        do  {
            switcherDiscovery = CreateBMDSwitcherDiscoveryInstance();
        } while (switcherDiscovery == NULL);
        
        HRESULT hr = switcherDiscovery->ConnectTo((__bridge CFStringRef)_mIP, &switcher, &failure);

        if (SUCCEEDED(hr))
        {
            NSLog(@"Connected to %@", _mIP);
        }
        else
        {
            NSString* reason;
            switch (failure)
            {
                case bmdSwitcherConnectToFailureNoResponse:
                    reason = @"No response from Switcher";
                    break;
                case bmdSwitcherConnectToFailureIncompatibleFirmware:
                    reason = @"Switcher has incompatible firmware";
                    break;
                default:
                    reason = @"Connection failed for unknown reason";
            }
            
            [mUIDelegate performSelectorOnMainThread:@selector(setStatusMsg:) withObject:@{@"ip":_mIP, @"status":reason} waitUntilDone:NO];
            
            sleep(1.0);
            continue;
        }

        CFStringRef ref;
        switcher->GetProductName(&ref);

        if(!terminating) {
            REFIID mediaPollIID = IID_IBMDSwitcherMediaPool;

            hr = switcher->QueryInterface(mediaPollIID, (void**)&mediaPool);
            mediaPool->GetStills(&stills);

            stills->GetCount(&stillsCount);

            

            stillsMonitor->setStills(stills);
            switcherMonitor->setSwitcher(switcher);
            
            [mUIDelegate performSelectorOnMainThread:@selector(switcherConnectionEstablished:) withObject:_mIP waitUntilDone:NO];
            connected = true;
        } else {
            NSLog(@"Aborting connect, we're terminating!");
        }
        return;
    }
}

-(bool) isConnected {
    return connected;
}

-(bool) isBusy {
    if ([updateList count] > 0) {
        return true;
    }
    return false;
}

-(void) cleanupConnection {
    switcherMonitor->setSwitcher(NULL);
    stillsMonitor->setStills(NULL);
    
    if(stills) {
        stills->Release();
        stills = NULL;
    }
    if(mediaPool) {
        mediaPool->Release();
        mediaPool = NULL;
    }
    if(switcher){
        switcher->Release();
        switcher = NULL;
    }
    NSLog(@"Closing connection to %@", _mIP);
}

-(void) isTerminating{
    terminating = true;
}

-(MediaPoolWatcher*) initWithIP:(NSString *)ip andBaseDir: (NSString*) path withDelegate:(SwitcherMediaPoolAppDelegate*) uiDelegate {
    mUIDelegate = uiDelegate;
    
    connected = false;
    terminating = false;
    updateList = [[NSMutableArray alloc] init];
    downloadPath = nil;
    
    _mIP = ip;
    _mPath = [path stringByAppendingPathComponent:_mIP];
    
    JSONFile = [_mPath stringByAppendingPathComponent:@"metadata.json"];
    NSFileManager* fm = [NSFileManager alloc];
    BOOL isDir = NO;
    
    if (![fm fileExistsAtPath:_mPath isDirectory:&isDir]) {
        NSLog(@"Creating media directory: %@", _mPath);
        [fm createDirectoryAtPath:_mPath withIntermediateDirectories:YES attributes:Nil error:nil];
    }
    
    if(![fm fileExistsAtPath:JSONFile]) {
        NSOutputStream *file = [NSOutputStream outputStreamToFileAtPath:JSONFile append:NO];
        [file open];
        [NSJSONSerialization writeJSONObject:@{} toStream:file options:NSJSONWritingPrettyPrinted error:nil];
        [file close];
    }
    
    JSONData = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:JSONFile] options:NSJSONReadingMutableContainers error:nil];
    
    if (JSONData == nil) {
        JSONData = [[NSMutableDictionary alloc] init];
    }
    
    stillsMonitor = new StillsMonitor(self);
    switcherMonitor = new SwitcherMonitor(self);
    lockCallback = new LockCallback(self);
    
    // Insert code here to initialize your application
    return self;
}

-(void) updateNextStill {
    if (terminating) {
        return;
    }
    
    if ([updateList count] > 0) {
        NSDictionary* element = [updateList firstObject];
        
        //NSLog(@"Updating object %@ for reason %@", [element objectForKey:@"index"], [element objectForKey:@"reason"]);
        
        if (![[element objectForKey:@"reason"] isEqualToString:@"HASH_MISMATCH"]) {
            downloadPath = [_mPath stringByAppendingPathComponent:[NSString stringWithFormat:@"IMAGE_%@", [element objectForKey:@"index"]]];
        }
        NSString *statusStr;
        if (downloadPath==nil) {
            statusStr = [NSString stringWithFormat:@"Uploading still %@", [element objectForKey:@"index"]];
        } else {
            statusStr = [NSString stringWithFormat:@"Downloading still %@", [element objectForKey:@"index"]];
        }
        [mUIDelegate performSelectorOnMainThread:@selector(setStatusMsg:) withObject:@{@"ip":_mIP, @"status":statusStr} waitUntilDone:NO];
        currentIndex = [[element objectForKey:@"index"] integerValue];
        stills->Lock(lockCallback);
    } else {
        [mUIDelegate performSelectorOnMainThread:@selector(switcherActionCompleted:) withObject:_mIP waitUntilDone:NO];
    }
}


-(void) onStillsLockObtained {
    NSDictionary* element = [updateList firstObject];
    if ([[element objectForKey:@"reason"] isEqualToString:@"HASH_MISMATCH"]) {
        NSDictionary* jsonObj = [JSONData objectForKey:[[element objectForKey:@"index"] stringValue]];
        
        NSLog(@"Uploading still %@ to %@", [element objectForKey:@"index"], _mIP);
                NSData *frame = [NSData dataWithContentsOfFile:[_mPath stringByAppendingPathComponent:[NSString stringWithFormat:@"IMAGE_%@", [element objectForKey:@"index"]]]];

                NSUInteger frameSize = 0;
                NSInteger width = [[jsonObj objectForKey:@"width"] integerValue];
                NSInteger height = [[jsonObj objectForKey:@"height"] integerValue];
                BMDSwitcherPixelFormat pixel_format;
        
                if ([[jsonObj objectForKey:@"pixfmt"] isEqualToString:@"8BitYUV"]) {
                    frameSize = 2 * width * height;
                    pixel_format = bmdSwitcherPixelFormat8BitYUV;
                } else if (![[jsonObj objectForKey:@"pixfmt"] isEqualToString:@""]) {
                    frameSize = 4 * width * height;
                    if ([[jsonObj objectForKey:@"pixfmt"] isEqualToString:@"10BitYUVA"]) {
                        pixel_format = bmdSwitcherPixelFormat10BitYUVA;
                    } else if ([[jsonObj objectForKey:@"pixfmt"] isEqualToString:@"8BitARGB"]) {
                        pixel_format = bmdSwitcherPixelFormat8BitARGB;
                    } else if ([[jsonObj objectForKey:@"pixfmt"] isEqualToString:@"8BitXRGB"]) {
                        pixel_format = bmdSwitcherPixelFormat8BitXRGB;
                    }
                }
        
                if (frameSize == 0) {
                    NSLog(@"Invalid frame size..");
                    return;
                }

                IBMDSwitcherFrame* newFrame = NULL;
                mediaPool->CreateFrame(pixel_format, width, height, &newFrame);
                void *frameData = NULL;
                newFrame->GetBytes(&frameData);
                [frame getBytes:frameData length:frameSize];

                HRESULT result = stills->Upload([[element objectForKey:@"index"] integerValue], (__bridge CFStringRef)[jsonObj objectForKey:@"name"], newFrame);
        
                newFrame->Release();
                newFrame = NULL;
                if (FAILED(result)) {
                    NSLog(@"Upload failed!");
                    [updateList removeObjectAtIndex:0];
                    stills->Unlock(lockCallback);
                    [self updateNextStill];
                }
    } else {
        NSLog(@"Stills lock obtained! Attempting Download of still %d from %@", currentIndex, _mIP);
        setDownloading();
        stills->Download(currentIndex);
    }
}
-(void) onStillsTransferEnded:(FrameObject*)frm {
    NSDictionary* updateElement = [updateList firstObject];
    
    if (frm == nil && downloadPath != nil) {
        NSLog(@"Transfer failed..!");
    } else {
        NSLog(@"Stills transfer %@ was succesful", _mIP);

        if (downloadPath != nil) {
                
            NSString* pix_fmt = @"";
            
            switch ([frm pixfmt]) {
                case bmdSwitcherPixelFormat10BitYUVA:
                    pix_fmt = @"10BitYUVA";
                    break;
                case bmdSwitcherPixelFormat8BitARGB:
                    pix_fmt = @"8BitARGB";
                    break;
                case bmdSwitcherPixelFormat8BitXRGB:
                    pix_fmt = @"8BitXRGB";
                    break;
                case bmdSwitcherPixelFormat8BitYUV:
                    pix_fmt = @"8BitYUV";
                    break;
                default:
                    break;
            }
            [[frm frameData] writeToFile:downloadPath atomically:YES];
            NSDictionary* element = @{
                                      @"hash": [updateElement objectForKey:@"hash"],
                                      @"width": [NSNumber numberWithInt:[frm frameWidth]],
                                      @"height": [NSNumber numberWithInt:[frm frameHeight]],
                                      @"name": [updateElement objectForKey:@"title"],
                                      @"pixfmt": pix_fmt
                                      };
            [JSONData setObject:element forKey:[[updateElement objectForKey:@"index"] stringValue]];
            [self updateJSON];
        } else { // Update hash to reflect the newly uploaded image. Some bug is causing this to change..
            NSString* index = [[updateElement objectForKey:@"index"] stringValue];
            BMDSwitcherHash hash;
            stills->GetHash([index integerValue], &hash);
            NSMutableDictionary* stillObj = [[JSONData objectForKey:index] mutableCopy];
            [stillObj setObject:[self hexHash:hash.data] forKey:@"hash"];
            [JSONData setObject:stillObj forKey:index];
            [self updateJSON];
        }
    }
    downloadPath = nil;
    [updateList removeObjectAtIndex:0];
    stills->Unlock(lockCallback);
    [self updateNextStill];
}


-(void) switcherDisconnected {
    NSLog(@"Switcher %@ disconnected", _mIP);
    [mUIDelegate performSelectorOnMainThread:@selector(switcherConnectionFailed:) withObject:_mIP waitUntilDone:NO];
    connected = false;
    [self cleanupConnection];
}

-(void) dealloc {
    [self cleanupConnection];
}

@end
