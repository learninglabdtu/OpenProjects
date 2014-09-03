//
//  AppDelegate.h
//  H.264 Recorder
//
//  Created by Filip Sandborg-Olsen on 20/02/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "H264Recorder.h"
#import "PreferencesController.h"
#import <signal.h>
#import "TCPInterfaceController.h"
#import "CrestronInterface.h"

@interface AppDelegate : NSObject <NSApplicationDelegate,H264RecorderDelegate> {
    H264Recorder* recorder;
    PreferencesController* prefWindow;
    TCPInterfaceController* tcpInterface;
    CrestronInterface* crestronInterface;
    NSMutableDictionary* userOptions;
    NSString* notificationTag;
    NSAlert* notification;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextField* deviceName;
@property (assign) IBOutlet NSTextField* deviceInput;
@property (assign) IBOutlet NSTextField* deviceDisplayMode;
@property (assign) IBOutlet NSTextField* deviceState;
@property (assign) IBOutlet NSImageView* streamingState;
@property (assign) IBOutlet NSImageView* recordingState;
@property (retain) NSUserDefaults* preferences;
@property (assign) IBOutlet NSProgressIndicator* snapshotProgress;
@property (assign) IBOutlet NSProgressIndicator* recordingProgress;
@property (assign) IBOutlet NSProgressIndicator* streamingProgress;
@property IBOutlet NSTextField* recordingSubdir;
@property (retain) NSTimer* checkTimer;

@property (assign) IBOutlet NSButton* recordButton;
@property (assign) IBOutlet NSButton* streamingButton;

-(IBAction) startStreaming: (id) sender;
-(IBAction) startRecording: (id) sender;
-(IBAction) takeSnapshot:(id)sender;
-(IBAction) showPreferences:(id)sender;
-(IBAction) togglePreview:(id)sender;
-(IBAction) changedSubdir:(id)sender;

-(void) settingsChanged;
-(void) updateMetadata;
-(void) showNotification: (NSString*) title withDescription:(NSString*) desc tag:(NSString*) tag;

-(void) clearUserOptions;
-(void) setUserOption:(NSString*) option forKey:(NSString*) key;

-(NSString*) getUserOption:(NSString* ) key;

-(void) dismissNotificationIfTagName: (NSString*) tag;



@end
