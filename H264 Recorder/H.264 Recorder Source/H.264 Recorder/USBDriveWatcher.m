//
//  USBDriveWatcher.m
//  H.264 Recorder
//
//  Created by Filip Sandborg-Olsen on 10/09/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import "USBDriveWatcher.h"

@implementation USBDriveWatcher

- (id) init {
    
    _disks = [[NSMutableArray alloc] init];
    
    _diskLock = [[NSLock alloc] init];
    
    [self performSelectorInBackground:@selector(detectUSB:) withObject:self];
    
    return self;
}

-(NSMutableArray*) getDisks {
    NSMutableArray* copy;
    [_diskLock lock];
        copy = [_disks copy];
    [_diskLock unlock];
    return copy;
}

NSDictionary* get_disk_dict(DADiskRef disk) {
    CFDictionaryRef description = DADiskCopyDescription(disk);
    NSString* bsdName = [NSString stringWithCString:DADiskGetBSDName(disk) encoding:NSUTF8StringEncoding];
    
    
    NSURL *volumeURL = (__bridge NSURL*) CFDictionaryGetValue(description, kDADiskDescriptionVolumePathKey);
    if (!volumeURL) {
        volumeURL = [NSURL URLWithString:@""];
    }
    
    NSFileManager* fm = [NSFileManager alloc];
    NSNumber* diskSize = @0;
    NSNumber* freeSpace = @0;
    
    NSNumber* writable = @false;
    if (volumeURL.path) {
        if([fm isWritableFileAtPath:volumeURL.path]) {
            writable = @true;
        }
        NSDictionary* attributes = [fm attributesOfFileSystemForPath: volumeURL.path error:nil];
        
        if(attributes) {
            diskSize = [attributes objectForKey:NSFileSystemSize];
            freeSpace = [attributes objectForKey:NSFileSystemFreeSize];
        }
        NSLog(@"New USB Disk %s is mounted at %@", DADiskGetBSDName(disk), volumeURL.path);
    } else {
        NSLog(@"Disk is NOT mounted");
    }
    

    NSDictionary* diskRecord = @{
                                 @"bsdName": bsdName,
                                 @"volumeURL": volumeURL,
                                 @"path": (volumeURL.path?volumeURL.path:@""),
                                 @"mounted": (volumeURL.path?@true:@false),
                                 @"writable": writable,
                                 @"diskSize": diskSize,
                                 @"freeSpace": freeSpace};
    
    CFRelease(description);
    
    return diskRecord;
}

void disk_did_appear(DADiskRef disk, void* context) {
    
    USBDriveWatcher* watcher = (__bridge USBDriveWatcher*) context;
    
    NSDictionary* diskRecord = get_disk_dict(disk);
    
    [watcher.diskLock lock];
        [watcher.disks addObject:diskRecord];
    [watcher.diskLock unlock];
    
    //Mount new disk, in case it is not already mounted..
    DADiskMount(disk, NULL, 0, NULL, NULL);
    DADiskUnmount(disk, 0, NULL, NULL);
    
    if ([diskRecord objectForKey:@"writable"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"writableDiskArrived" object:nil];
    }
    
    NSLog(@"A total of %lu USB drives now present", (unsigned long)[watcher.disks count]);
}

void disk_params_changed(DADiskRef disk, CFArrayRef keys, void * context) {
    CFDictionaryRef description = DADiskCopyDescription(disk);
    USBDriveWatcher* watcher = (__bridge USBDriveWatcher*) context;
    NSString* bsdName = [NSString stringWithCString:DADiskGetBSDName(disk) encoding:NSUTF8StringEncoding];
    
    NSDictionary* diskRecord = get_disk_dict(disk);
    
    for (int i = 0; i < CFArrayGetCount(keys); i++) {
        
        if (CFStringCompare(CFArrayGetValueAtIndex(keys, i), kDADiskDescriptionVolumePathKey, 0) == kCFCompareEqualTo) {
            NSURL *volumeURL = (__bridge NSURL*) CFDictionaryGetValue(description, kDADiskDescriptionVolumePathKey);
            NSLog(@"Volume Path %@", volumeURL);
            if (volumeURL) {
                [watcher.diskLock lock];
                    for (NSDictionary* disk in [watcher disks]) {
                        if ([[disk objectForKey:@"bsdName"] isEqualToString:bsdName]) {
                            [[watcher disks] setObject:diskRecord atIndexedSubscript:[[watcher disks] indexOfObject:disk]];
                            break;
                        }
                    }
                [watcher.diskLock unlock];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"writableDiskArrived" object:nil];
            }
        }
    }
    CFRelease(description);
}

void disk_did_disappear(DADiskRef disk, void* context) {
    USBDriveWatcher* watcher =  (__bridge USBDriveWatcher*)context;
    NSString* name = [NSString stringWithCString:DADiskGetBSDName(disk) encoding:NSUTF8StringEncoding];

    NSLog(@"Disk %@ was removed!", name);
    
    [watcher.diskLock lock];
        NSDictionary* removedDisk;
        for (NSDictionary* disk in watcher.disks) {
            if ([[disk objectForKey:@"bsdName"] isEqualToString:name]) {
                removedDisk = disk;
                goto found;
            }
        }
        NSLog(@"ERROR: Could not find record of removed device!");
    found:
        if(removedDisk){
            [watcher.disks removeObject:removedDisk];
        }
        NSLog(@"A total of %lu USB drives now present", (unsigned long)[watcher.disks count]);
    [watcher.diskLock unlock];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"diskRemoved" object:nil];
}

- (void) unmountDrives {
    DASessionRef session;
    session = DASessionCreate(kCFAllocatorDefault);
    
    [_diskLock lock];
        for (NSDictionary* disk in _disks) {
            const char* bsdName = [[disk objectForKey:@"bsdName"] cStringUsingEncoding:NSUTF8StringEncoding];
            DADiskRef disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName);
            DADiskUnmount(disk, 0, NULL, NULL);
            CFRelease(disk);
        }
    [_diskLock unlock];
    
    CFRelease(session);
}

- (void) mountDrives {
    DASessionRef session;
    session = DASessionCreate(kCFAllocatorDefault);
    
    [_diskLock lock];
        for (NSDictionary* disk in _disks) {
            const char* bsdName = [[disk objectForKey:@"bsdName"] cStringUsingEncoding:NSUTF8StringEncoding];
            DADiskRef disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName);
            DADiskMount(disk, NULL, 0, NULL, NULL);
            CFRelease(disk);
        }
    [_diskLock unlock];
    
    CFRelease(session);
}

DASessionRef _session;

- (void) detectUSB: (USBDriveWatcher*) parent {
    
    _session = DASessionCreate(kCFAllocatorDefault);
    
    CFMutableDictionaryRef keys = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
    CFDictionaryAddValue(keys, kDADiskDescriptionMediaRemovableKey, kCFBooleanTrue);
    CFDictionaryAddValue(keys, kDADiskDescriptionMediaWritableKey, kCFBooleanTrue);
    CFDictionaryAddValue(keys, kDADiskDescriptionVolumeMountableKey, kCFBooleanTrue);
    CFDictionaryAddValue(keys, kDADiskDescriptionDeviceProtocolKey, CFSTR("USB"));
    CFDictionaryAddValue(keys, kDADiskDescriptionDeviceInternalKey, kCFBooleanFalse);
    
    void *context = (__bridge void*) parent;
    
    DARegisterDiskAppearedCallback(_session,keys,disk_did_appear, context);
    DARegisterDiskDisappearedCallback(_session, keys, disk_did_disappear, context);
    DARegisterDiskDescriptionChangedCallback(_session, keys, NULL, disk_params_changed, context);
 
    DASessionScheduleWithRunLoop(_session, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    
    //DASessionSetDispatchQueue(_session, dispatch_get_global_queue(0, 0));
    
    // Is this OK to do here?
    CFRelease(keys);
}

- (void) dealloc {
    [self mountDrives];
    
    DASessionUnscheduleFromRunLoop(_session, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    CFRelease(_session);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"diskRemoved" object:nil];
    NSLog(@"USB Dealloc");
}


@end
