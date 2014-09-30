//
//  USBDriveWatcher.h
//  H.264 Recorder
//
//  Created by Filip Sandborg-Olsen on 10/09/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <DiskArbitration/DiskArbitration.h>

@interface USBDriveWatcher : NSObject {
    NSMutableArray* _disks;
}

- (id) init;
- (NSMutableArray*) getDisks;
- (void) unmountDrives;
- (void) mountDrives;

@property (copy) NSMutableArray* disks;
@property NSLock* diskLock;
@end