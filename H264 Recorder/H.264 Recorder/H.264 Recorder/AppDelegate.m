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
    if(![[self preferences] objectForKey:@"autoSnapshotsDirectory"]) {
        [[self preferences] setObject:[NSHomeDirectory() stringByAppendingPathComponent:@"H.264 Recorder/AutoSnapshots"] forKey:@"autoSnapshotsDirectory"];
    }
    if(![[self preferences] objectForKey:@"recordingDir"]) {
        [[self preferences] setObject:[NSHomeDirectory() stringByAppendingPathComponent:@"H.264 Recorder/Recordings/"] forKey:@"recordingDir"];
    }
    
    if([[self preferences] objectForKey:@"autoSnapshotsEnabled"] == nil) {
        [[self preferences] setBool:NO forKey:@"autoSnapshotsEnabled"];
    }
    
    if(![[self preferences] objectForKey:@"autoSnapshotsInterval"]) {
        [[self preferences] setObject:@15 forKey:@"autoSnapshotsInterval"];
    }
    
    [[self preferences] synchronize];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recordingStatus:) name:@"recording" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(streamingStatus:) name:@"streaming" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(snapshotStatus:) name:@"manualSnapshot" object:nil];
    
    recorder = [[H264Recorder alloc] initwithDelegate:self];
    
    //[self performSelectorInBackground:@selector(checkStreaming) withObject:nil];
    [self setCheckTimer:[NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(checkStreaming) userInfo:nil repeats:YES]];
    [[self checkTimer] fire];
    
    tcpInterface = [[TCPInterfaceController alloc] initWithPort:9993 andRecorder:recorder];
    crestronInterface = [[CrestronInterface alloc] initWithPort:9992 andRecorder:recorder];
    
    if ([[self preferences] boolForKey:@"autoSnapshotsEnabled"] == YES) {
        [recorder startAutoSnapshots];
    }
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

-(void) streamingStatus:(NSNotification*) n {
    NSString* state = [n object];
    if ([state isEqualToString:@"stopped"]) {
        [[self streamingProgress] setHidden:YES];
        [[self streamingProgress] stopAnimation:self];
        [[self streamingButton] setTitle:@"Start Streaming"];
    } else if([state isEqualToString:@"started"]) {
        [[self streamingProgress] setHidden:NO];
        [[self streamingProgress] startAnimation:self];
        [[self streamingButton] setTitle:@"Stop Streaming"];
    }
}

-(void) recordingStatus:(NSNotification*) n {
    NSString* state = [n object];
    if ([state isEqualToString:@"stopped"]) {
        [[self recordingProgress] setHidden:YES];
        [[self recordingProgress] stopAnimation:self];
        [[self recordButton] setTitle:@"Start Recording"];
    } else if([state isEqualToString:@"started"]) {
        [[self recordingProgress] setHidden:NO];
        [[self recordingProgress] startAnimation:self];
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

-(IBAction)startStreaming:(id)sender {
    if([recorder isStreaming]) {
        [recorder stopStreaming];
        [[self streamingButton] setTitle:@"Start Streaming"];
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
    } else {
        if(![recorder startRecording]) {
            [self showNotification:@"Could not start recording" withDescription:@"Please set a valid and writable recording directory in the preferences dialog before recording." tag:nil];
        }
    }
}

-(void) showNotification:(NSString *)title withDescription: (NSString*) desc tag:(NSString*) tag {
    notification = [NSAlert alertWithMessageText:title
                                      defaultButton:@"OK"
                                    alternateButton:nil
                                        otherButton:nil
                          informativeTextWithFormat:@"%@", desc];
    notificationTag = tag;
    [notification beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

-(void) notificationDidEnd {
    notificationTag = nil;
}

-(void) dismissNotificationIfTagName: (NSString*) tag {
    if([notificationTag isEqualToString:tag] && notification) {
        [[notification window] close];
        notificationTag = nil;
    }
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
    [[self deviceName] setStringValue:[state objectForKey:@"deviceName"]];
    [[self deviceState] setStringValue:[state objectForKey:@"deviceState"]];
    [[self deviceInput] setStringValue:[state objectForKey:@"deviceInput"]];
    [[self deviceDisplayMode] setStringValue:[state objectForKey:@"deviceDisplayMode"]];
}

-(void) stoppedRecording {
    [[self recordButton] setStringValue:@"Start Recording"];
}

-(void) stoppedStreaming {
    [[self streamingButton] setStringValue:@"Start Streaming"];
}

-(void) checkStreaming {
    @autoreleasepool {
        if([recorder checkStreaming]) {
            [[self streamingState] setImage:[NSImage imageNamed:@"red"]];
        } else {
            [[self streamingState] setImage:[NSImage imageNamed:@"gray"]];
        }
        if([recorder checkRecording]) {
            [[self recordingState] setImage:[NSImage imageNamed:@"red"]];
        } else {
            [[self recordingState] setImage:[NSImage imageNamed:@"gray"]];
        }
        sleep(1);
    }
}

-(void) settingsChanged {
    if([[self preferences] boolForKey:@"autoSnapshotsEnabled"] == YES) {
        [recorder startAutoSnapshots];
    } else {
        [recorder stopAutoSnapshots];
    }
}

-(IBAction) takeSnapshot:(id)sender {
    [self changedSubdir:nil];
    if(![recorder takeSnapshot]){
        if([recorder isManualSnapshot]) {

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
    [self updateMetadata];
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
        
        if([key isEqualToString:@"username"]) {
            [[self recordingSubdir] setStringValue: option];
        }
    }
}

-(NSString*) getUserOption: (NSString*) key {
    return [userOptions objectForKey:key];
}
@end
