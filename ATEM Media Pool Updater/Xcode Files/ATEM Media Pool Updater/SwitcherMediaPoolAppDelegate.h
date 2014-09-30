//
//  AppDelegate.h
//  ATEM Media Pool Updater
//
//  Created by Filip Sandborg-Olsen on 15/01/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BMDSwitcherAPI.h"
#import "CallbackMonitors.h"
#import <vector>
#import "FrameObject.h"
#import "MediaPoolWatcher.h"

class SwitcherMonitor;

@interface SwitcherMediaPoolAppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate> {
    IBMDSwitcherDiscovery* switcherDiscovery;
    IBMDSwitcher* switcher;
    IBMDSwitcherMediaPool* mediaPool;
    IBMDSwitcherStills* stills;
    SwitcherMonitor* switcherMonitor;
    StillsMonitor* stillsMonitor;
    
    std::vector<IBMDSwitcherClip*> clips;
    
    NSMutableDictionary* mediaPoolWatchers;
    
    SwitcherMonitor* monitor;
    MediaPoolWatcher* mediaPoolWatcher;
    
    NSUserDefaults* settings;
    
    NSTimer* timer;
    NSDate* lastValidityCheck;
}

- (void) switcherActionCompleted:(NSString*) switcherIP;
- (void) switcherConnectionEstablished:(NSString*) switcherIP;
- (void) switcherConnectionFailed:(NSString*) switcherIP;
-(void) setStatusMsg: (NSDictionary*) values;

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextView *logWindow;
@property (assign) IBOutlet NSTableView* tableView;
@property (assign) IBOutlet NSButton* removeButton;
@property (assign) IBOutlet NSTextField* ipField;
@property (assign) IBOutlet NSButton*   ipButton;
@property (assign) IBOutlet NSTextField* interval;
@property (assign) IBOutlet NSTextField* userNotification;

- (IBAction) removeTableItem:(id) sender;
- (IBAction) addSwitcher:(id) sender;

@end