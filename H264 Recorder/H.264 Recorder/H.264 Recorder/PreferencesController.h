//
//  PreferencesController.h
//  H.264 Recorder
//
//  Created by Filip Sandborg-Olsen on 06/03/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PreferencesController : NSWindowController {
    id appDelegate;
}

-(IBAction) recordingFolderDialog:(id)sender;
-(IBAction) snapshotFolderDialog: (id) sender;
-(IBAction) autoSnapshotFolderDialog:(id)sender;
-(IBAction) closeWindow:(id)sender;
-(IBAction) applyChanges:(id)sender;
-(IBAction) passthroughToggled: (id) sender;
-(IBAction) autoSnapshotChanged:(id)sender;

@property (assign) IBOutlet NSTextField* streamUrl;
@property (assign) IBOutlet NSTextField* streamKey;
@property (assign) IBOutlet NSTextField* audioBitrate;
@property (assign) IBOutlet NSTextField* videoBitrate;
@property (assign) IBOutlet NSTextField* recordingDir;
@property (assign) IBOutlet NSTextField* TCPInterfacePort;
@property (assign) IBOutlet NSTextField* CrestronInterfacePort;

@property (assign) IBOutlet NSButton* streamingPassthrough;
@property (assign) IBOutlet NSButton* streamAutoRestart;
@property IBOutlet NSSlider* H264videoBitrateSlider;
@property IBOutlet NSTextField* H264videoBitrate;
@property IBOutlet NSPopUpButton* x264preset;
@property IBOutlet NSPopUpButton* formatSelect;
@property IBOutlet NSButton* autoSnapshotDialogButton;

@property (assign) IBOutlet NSTextField* snapshotDir;
@property (assign) IBOutlet NSTextField* autoSnapshotDir;
@property (assign) IBOutlet NSTextField* snapshotInterval;

@property (assign) IBOutlet NSButton* autoSnapshots;

-(IBAction) sliderDidMove: (id) sender;

@end
