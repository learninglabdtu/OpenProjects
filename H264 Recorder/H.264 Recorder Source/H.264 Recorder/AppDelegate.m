//
//  AppDelegate.m
//  H.264 Recorder
//
//  Created by Filip Sandborg-Olsen on 20/02/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self setPreferences:[NSUserDefaults standardUserDefaults]];
    userOptions = [[NSMutableDictionary alloc] init];

    BOOL yes = YES;
    
    NSString* rootDir = [NSHomeDirectory() stringByAppendingPathComponent:@"H.264 Recorder"];
    if(![[NSFileManager alloc] fileExistsAtPath:rootDir isDirectory:&yes]) {
        NSError *lal = nil;
        [[NSFileManager alloc] createDirectoryAtPath:rootDir withIntermediateDirectories:NO attributes:nil error:&lal];
        if(lal) {
            NSLog(@"%@", [lal description]);
        }
    }
    
    if(![[self preferences] objectForKey:@"videoBitrate"]) {
        [[self preferences] setObject:@2000 forKey:@"videoBitrate"];
    }
    if(![[self preferences] objectForKey:@"audioBitrate"]) {
        [[self preferences] setObject:@128 forKey:@"audioBitrate"];
    }
    if(![[self preferences] objectForKey:@"H264VideoBitrate"]) {
        [[self preferences] setObject:@5000 forKey:@"H264VideoBitrate"];
    }
    if(![[self preferences] objectForKey:@"x264preset"]) {
        [[self preferences] setObject:@"veryfast" forKey:@"x264preset"];
    }
    if(![[self preferences] objectForKey:@"outputFormat"]) {
        [[self preferences] setObject:@".mp4" forKey:@"outputFormat"];
    }
    if(![[self preferences] objectForKey:@"snapshotsDirectory"]) {
        [[self preferences] setObject:[NSHomeDirectory() stringByAppendingPathComponent:@"H.264 Recorder/Snapshots"] forKey:@"snapshotsDirectory"];
    }
    if(![[self preferences] objectForKey:@"writeToUSB"]) {
        [[self preferences] setBool:false forKey:@"writeToUSB"];
    }
    if(![[self preferences] objectForKey:@"autoSnapshotsDirectory"]) {
        [[self preferences] setObject:[NSHomeDirectory() stringByAppendingPathComponent:@"H.264 Recorder/AutoSnapshots"] forKey:@"autoSnapshotsDirectory"];
    }
    if(![[self preferences] objectForKey:@"recordingDir"]) {
        [[self preferences] setObject:[NSHomeDirectory() stringByAppendingPathComponent:@"H.264 Recorder/Recordings/"] forKey:@"recordingDir"];
    }
    
    if(![[self preferences] objectForKey:@"autoSnapshotsInterval"]) {
        [[self preferences] setObject:@15 forKey:@"autoSnapshotsInterval"];
    }
    
    
    if(![[self preferences] objectForKey:@"tcpInterfacePort"]) {
        [[self preferences] setObject:@9993 forKey:@"tcpInterfacePort"];
    }
    if(![[self preferences] objectForKey:@"crestronInterfacePort"]) {
        [[self preferences] setObject:@9982 forKey:@"crestronInterfacePort"];
    }
    
    if(![[self preferences] objectForKey:@"TSBackupEnabled"]) {
        [[self preferences] setBool:NO forKey:@"TSBackupEnabled"];
    }
    
    if(![[self preferences] objectForKey:@"keyframeInterval"]) {
        [[self preferences] setObject:@0 forKey:@"keyframeInterval"];
    }
    
    if(![[self preferences] objectForKey:@"streamTimeout"]) {
        [[self preferences] setObject:@0 forKey:@"streamTimeout"];
    }
    if(![[self preferences] valueForKey:@"recordTimeout"]) {
        [[self preferences] setObject:@0 forKey:@"recordTimeout"];
    }
    if(![[self preferences] valueForKey:@"autoSnapshotTimeout"]) {
        [[self preferences] setObject:@0 forKey:@"autoSnapshotTimeout"];
    }
    
    [[self preferences] synchronize];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recordingStatus:) name:@"recording" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(streamingStatus:) name:@"streaming" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(snapshotStatus:) name:@"manualSnapshot" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(autosnapshotStatus:) name:@"autoSnapshot" object:nil];
    
    recorder = [[H264Recorder alloc] initwithDelegate:self];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (1) {
            @autoreleasepool {
                [self checkFFmpeg];
                [NSThread sleepForTimeInterval:0.5f];
            }
        }
    });
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (1) {
            @autoreleasepool {
                [self checkStreaming];
                [NSThread sleepForTimeInterval:1.0f];
            }
        }
    });
    
    tcpInterface = [[TCPInterfaceController alloc] initWithPort:[[[self preferences] objectForKey:@"tcpInterfacePort"] integerValue] andRecorder:recorder];
    crestronInterface = [[CrestronInterface alloc] initWithPort:[[[self preferences] objectForKey:@"crestronInterfacePort"] integerValue] andRecorder:recorder];
    
    if ([[self preferences] boolForKey:@"writeToUSB"] == YES) {
        [self startUSBWatcher];
    }
    
}

-(void) startUSBWatcher {
    if(!_usbDriveWatcher) {
        _usbDriveWatcher = [[USBDriveWatcher alloc] init];
    }
}

-(void) stopUSBWatcher {
    _usbDriveWatcher = nil;
}

-(IBAction) togglePreview:(id)sender {
    if([recorder isPreviewing]) {
        [recorder stopPreview];
    } else {
        if(![[NSFileManager alloc] fileExistsAtPath:@"/Applications/VLC.app/Contents/MacOS/VLC" isDirectory:nil]) {
            [self showNotification:@"Could not start preview" withDescription:@"Please install VLC Player to show the video preview." tag:nil];
        } else {
            [recorder performSelectorInBackground:@selector(videoPreview) withObject:nil];
        }
    }
}

-(void) applicationWillTerminate:(NSNotification *)notification {
    [recorder terminate];
}

-(IBAction) startAutoSnapshots: (id) sender {
    if(![recorder isConnected]) {
        [self showNotification:@"No recording device" withDescription:@"Please connect an H.264 Pro Recorder or ATEM TVS to this computer." tag:nil];
    } else if(![recorder isEncoding]) {
        [self showNotification:@"Device not encoding" withDescription:@"Please make sure that a compatible input source is connected to the recording device." tag:nil];
    } else {
        if (![[recorder autoSnapshot] isValid]) {
            [recorder startAutoSnapshots];
        } else {
            [recorder stopAutoSnapshots];
        }
    }
}


-(void) streamingStatus:(NSNotification*) n {
    NSString* state = [n object];
    if ([state isEqualToString:@"stopped"]) {
        [[self streamingButton] setTitle:@"Start Streaming"];
    } else if([state isEqualToString:@"started"]) {
        [[self streamingButton] setTitle:@"Stop Streaming"];
    }
}

-(void) recordingStatus:(NSNotification*) n {
    NSString* state = [n object];
    if ([state isEqualToString:@"stopped"]) {
        [[self recordButton] setTitle:@"Start Recording"];
    } else if([state isEqualToString:@"started"]) {
        [[self recordButton] setTitle:@"Stop Recording"];
    }
}

-(void) snapshotStatus:(NSNotification*) n {
    NSString* state = [n object];
    if ([state isEqualToString:@"stopped"]) {
        [[self snapshotProgress] setHidden:YES];
        [[self snapshotProgress] stopAnimation:self];
    } else if([state isEqualToString:@"started"]) {
        [[self snapshotProgress] setHidden:NO];
        [[self snapshotProgress] startAnimation:self];
    }
}

-(void) autosnapshotStatus:(NSNotification*) n {
    NSString* state = [n object];
    if ([state isEqualToString:@"stopped"]) {
        [[self autosnapshotButton] setTitle:@"Start AutoSnapshots"];
    } else if([state isEqualToString:@"started"]) {
        [[self autosnapshotButton] setTitle:@"Stop AutoSnapshots"];
    }
}

-(IBAction)startStreaming:(id)sender {
    if([recorder isStreaming]) {
        [recorder stopStreaming];
        [[self streamingButton] setTitle:@"Start Streaming"];
    } else if(![recorder isConnected]) {
        [self showNotification:@"No recording device" withDescription:@"Please connect an H.264 Pro Recorder or ATEM TVS to this computer." tag:nil];
    } else if(![recorder isEncoding]) {
        [self showNotification:@"Device not encoding" withDescription:@"Please make sure that a compatible input source is connected to the recording device." tag:nil];
    } else {
        if(![recorder startStreaming]) {
            [self showNotification:@"Could not start stream" withDescription:@"Please set a UStream stream URL/Key pair in the preferences dialog before starting streaming." tag:nil];
        }
    }
}
-(IBAction) startRecording: (id) sender {
    [self changedSubdir:nil];
    if([recorder isRecording]) {
        [recorder stopRecording];
    } else if(![recorder isConnected]) {
        [self showNotification:@"No recording device" withDescription:@"Please connect an H.264 Pro Recorder or ATEM TVS to this computer." tag:nil];
    } else if(![recorder isEncoding]) {
        [self showNotification:@"Device not encoding" withDescription:@"Please make sure that a compatible input source is connected to the recording device." tag:nil];
    } else {
        if(![recorder startRecording]) {
            [self showNotification:@"Could not start recording" withDescription:@"Please set a valid and writable recording directory in the preferences dialog before recording." tag:nil];
        }
    }
}

-(void) showNotification:(NSString *)title withDescription: (NSString*) desc tag:(NSString*) tag {
    dispatch_async(dispatch_get_main_queue(), ^(){
        if (notificationTag != tag || tag == nil) {
            notification = [NSAlert alertWithMessageText:title
                                              defaultButton:@"OK"
                                            alternateButton:nil
                                                otherButton:nil
                                  informativeTextWithFormat:@"%@", desc];
            notificationTag = tag;
            [notification beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(notificationDidEnd) contextInfo:nil];
        }
    });
}

-(void) notificationDidEnd {
    notificationTag = nil;
}

-(void) dismissNotificationIfTagName: (NSString*) tag {
    dispatch_async(dispatch_get_main_queue(), ^(){
        if([notificationTag isEqualToString:tag] && notification) {
            [[notification window] close];
            notificationTag = nil;
        }
    });
}

-(void) stateUpdate:(NSDictionary *)state {
    NSString* newDeviceState = [state objectForKey:@"deviceState"];
    if(![newDeviceState isEqualToString:[[self deviceState] stringValue]]) {
        if([newDeviceState isEqualToString:@"Unknown"]) {
            [self showNotification:@"Error" withDescription:@"The recording device is in 'Unknown' state. Please unplug and replug the USB cable." tag:@"unknownState"];
        } else if([newDeviceState isEqualToString:@"firmware"]) {
            [self showNotification:@"Error" withDescription:@"Device firmware is being updated by the BMD Utility. Please wait until that process has finished." tag:@"firmwareUpdate"];
        }
    }
    
    if ([state objectForKey:@"deviceName"]) {
        [[self deviceName] setStringValue:[state objectForKey:@"deviceName"]];
    }
    if ([state objectForKey:@"deviceState"]) {
        [[self deviceState] setStringValue:[state objectForKey:@"deviceState"]];
    }
    if ([state objectForKey:@"deviceInput"]) {
        [[self deviceInput] setStringValue:[state objectForKey:@"deviceInput"]];
    }
    if ([state objectForKey:@"deviceDisplayMode"]) {
        [[self deviceDisplayMode] setStringValue:[state objectForKey:@"deviceDisplayMode"]];
    }
}

-(void) stoppedRecording {
    [[self recordButton] setStringValue:@"Start Recording"];
}

-(void) stoppedStreaming {
    [[self streamingButton] setStringValue:@"Start Streaming"];
}

-(void) checkFFmpeg {
    dispatch_async(dispatch_get_main_queue(), ^{
    [[self recordingTime] setStringValue: [recorder getRecordingStats]];
    [[self streamingTime] setStringValue: [recorder getStreamingStats]];
    });
}

-(void) checkStreaming {
    @autoreleasepool {
        BOOL streaming = [recorder checkStreaming];
        BOOL recording = [recorder checkRecording];
        BOOL autoSnapshot = [[recorder autoSnapshot] isValid];
        BOOL usbRecording =[recorder canRecordToUSB];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(streaming) {
                [[self streamingState] setImage:[NSImage imageNamed:@"red"]];
            } else {
                [[self streamingState] setImage:[NSImage imageNamed:@"gray"]];
            }
            if(recording) {
                [[self recordingState] setImage:[NSImage imageNamed:@"red"]];
            } else {
                [[self recordingState] setImage:[NSImage imageNamed:@"gray"]];
            }
            if(autoSnapshot) {
                [[self autosnapshotState] setImage:[NSImage imageNamed:@"red"]];
            } else {
                [[self autosnapshotState] setImage:[NSImage imageNamed:@"gray"]];
            }
            if (usbRecording) {
                [[self usbStorageState] setImage:[NSImage imageNamed:@"green"]];
            } else {
                [[self usbStorageState] setImage:[NSImage imageNamed:@"gray"]];
            }
        });
    }
}

-(void) settingsChanged {
    if([[self preferences] boolForKey:@"writeToUSB"] == YES) {
        [self startUSBWatcher];
    } else {
        [self stopUSBWatcher];
    }
    
    if([recorder isRecording] || [recorder isStreaming] || [[recorder autoSnapshot] isValid]) {
        [recorder updateTimers];
    }
}

-(IBAction) takeSnapshot:(id)sender {
    [self changedSubdir:nil];
    if(![recorder takeSnapshot]){
        if([recorder isManualSnapshot]) {

        } else if(![recorder isConnected]) {
            [self showNotification:@"No recording device" withDescription:@"Please connect an H.264 Pro Recorder or ATEM TVS to this computer." tag:nil];
        } else {
            [self showNotification:@"Could not take snapshot" withDescription:@"Please set a valid and writable recording directory in the preferences dialog before taking snapshots." tag:nil];
        }
    }
}

-(IBAction) showPreferences:(id)sender {
    prefWindow = [[PreferencesController alloc] initWithWindowNibName:@"PreferencesController"];
    [prefWindow showWindow:self];
}

-(BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

-(IBAction) changedSubdir:(id)sender {
    if(sender == nil) {
        sender = [self recordingSubdir];
    }
    // Should probably do this..
    //[self clearUserOptions];
    
    @synchronized(userOptions){
        [userOptions setObject:[sender stringValue] forKey:@"username"];
    }
    //[self updateMetadata];
}

- (void) updateMetadata {
    NSString* metafile = nil;
    if ([userOptions objectForKey:@"username"]) {
        metafile = [recorder createPathWithFilename:@"notifyUser.json" inDir:[[self preferences] objectForKey:@"recordingDir"]];
        NSOutputStream *file = [NSOutputStream outputStreamToFileAtPath:metafile append:NO];
        if (file) {
            [file open];
            [NSJSONSerialization writeJSONObject:userOptions toStream:file options:NSJSONWritingPrettyPrinted error:nil];
            [file close];
        } else {
            NSLog(@"Failed writing notifyUser.json...");
        }
    }
}

-(void) clearUserOptions {
    @synchronized(userOptions) {
        [userOptions removeAllObjects];
        [[self recordingSubdir] setStringValue: @""];
    }
}

-(void) setUserOption: (NSString*) option forKey:(NSString*) key {
    @synchronized(userOptions) {
        [userOptions setObject:option forKey:key];
        
        if([key isEqualToString:@"username"] && option != nil) {
            [[self recordingSubdir] setStringValue: option];
        }
    }
    [self updateMetadata];
}

-(NSString*) getUserOption: (NSString*) key {
    return [userOptions objectForKey:key];
}
@end
