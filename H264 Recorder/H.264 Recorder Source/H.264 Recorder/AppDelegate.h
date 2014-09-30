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
#import "USBDriveWatcher.h"

@interface AppDelegate : NSObject <NSApplicationDelegate,H264RecorderDelegate> {
    H264Recorder* recorder;
    PreferencesController* prefWindow;
    TCPInterfaceController* tcpInterface;
    CrestronInterface* crestronInterface;
    NSMutableDictionary* userOptions;
    NSString* notificationTag;
    NSAlert* notification;
    
    dispatch_queue_t queue;
}

@property (assign) IBOutlet NSTextField *recordingTime;
@property (assign) IBOutlet NSTextField *streamingTime;

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextField* deviceName;
@property (assign) IBOutlet NSTextField* deviceInput;
@property (assign) IBOutlet NSTextField* deviceDisplayMode;
@property (assign) IBOutlet NSTextField* deviceState;
@property (assign) IBOutlet NSImageView* streamingState;
@property (assign) IBOutlet NSImageView* recordingState;
@property (assign) IBOutlet NSImageView* autosnapshotState;
@property (assign) IBOutlet NSImageView* usbStorageState;

@property (retain) NSUserDefaults* preferences;
@property (assign) IBOutlet NSProgressIndicator* snapshotProgress;

@property IBOutlet NSTextField* recordingSubdir;
@property (retain) NSTimer* checkTimer;
@property (retain) NSTimer* ffmpegCheck;

@property (assign) IBOutlet NSButton* recordButton;
@property (assign) IBOutlet NSButton* streamingButton;
@property (assign) IBOutlet NSButton* autosnapshotButton;
@property USBDriveWatcher* usbDriveWatcher;

-(IBAction) startStreaming: (id) sender;
-(IBAction) startRecording: (id) sender;
-(IBAction) takeSnapshot:(id)sender;
-(IBAction) showPreferences:(id)sender;
-(IBAction) togglePreview:(id)sender;
-(IBAction) changedSubdir:(id)sender;

-(void) startUSBWatcher;
-(void) stopUSBWatcher;

-(void) settingsChanged;
-(void) updateMetadata;
-(void) showNotification: (NSString*) title withDescription:(NSString*) desc tag:(NSString*) tag;

-(IBAction) startAutoSnapshots: (id) sender;

-(void) clearUserOptions;
-(void) setUserOption:(NSString*) option forKey:(NSString*) key;

-(NSString*) getUserOption:(NSString* ) key;

-(void) dismissNotificationIfTagName: (NSString*) tag;



@end
