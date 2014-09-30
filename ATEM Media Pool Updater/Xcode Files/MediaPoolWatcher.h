//
//  MediaPoolWatcher.h
//  ATEM Media Pool Updater
//
//  Created by Filip Sandborg-Olsen on 31/01/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CallbackMonitors.h"
#import "BMDSwitcherAPI.h"


@class SwitcherMediaPoolAppDelegate;

@interface MediaPoolWatcher : NSObject {
    NSString* mIP;
    NSString* mPath;
    
    IBMDSwitcherDiscovery* switcherDiscovery;
    IBMDSwitcher* switcher;
    IBMDSwitcherMediaPool* mediaPool;
    IBMDSwitcherStills* stills;
    SwitcherMonitor* switcherMonitor;
    StillsMonitor* stillsMonitor;
    
    SwitcherMonitor* monitor;
    LockCallback* lockCallback;
    
    NSString* downloadPath;
    
    uint32_t currentIndex;
    uint32_t stillsCount;
    
    NSString* JSONFile;
    
    NSMutableDictionary* JSONData;
    
    NSMutableArray* updateList;
    
    SwitcherMediaPoolAppDelegate* mUIDelegate;
    
    NSString* statusString;
    
    bool terminating;
    bool connected;
}

-(MediaPoolWatcher*) initWithIP:(NSString*) ip andBaseDir: (NSString*) path withDelegate:(SwitcherMediaPoolAppDelegate*) uiDelegate;

-(void) onStillsLockObtained;
-(void) onStillsTransferEnded: (NSDictionary*) data;
-(void) switcherDisconnected;
-(void) pullStills;
-(void) pushStills;
-(void) connectToSwitcher;
-(void) isTerminating;
-(bool) isBusy;
-(void) autoUpdateStills;
-(bool) stillsAreValid;
-(bool) isConnected;
-(void) cleanupConnection;
-(bool) localStillsExist;

@property (retain) NSString* mIP;
@property (retain) NSString* mPath;
@property bool terminating;

@end
