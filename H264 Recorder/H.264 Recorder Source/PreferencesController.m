//
//  PreferencesController.m
//  H.264 Recorder
//
//  Created by Filip Sandborg-Olsen on 06/03/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import "PreferencesController.h"
#import "AppDelegate.h"

@interface PreferencesController ()

@end

@implementation PreferencesController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {

    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    appDelegate = (AppDelegate*)[[NSApplication sharedApplication] delegate];
    
    if ([[appDelegate preferences] valueForKey:@"streamUrl"]) {
        [[self streamUrl] setStringValue:[[appDelegate preferences] valueForKey:@"streamUrl"]];
    }
    if ([[appDelegate preferences] valueForKey:@"streamKey"]) {
        [[self streamKey] setStringValue:[[appDelegate preferences] valueForKey:@"streamKey"]];
    }
    
    if ([[appDelegate preferences] valueForKey:@"recordingDir"]) {
        [[self recordingDir] setStringValue:[[appDelegate preferences] valueForKey:@"recordingDir"]];
    }
    if ([[appDelegate preferences] valueForKey:@"snapshotsDirectory"]) {
        [[self snapshotDir] setStringValue:[[appDelegate preferences] valueForKey:@"snapshotsDirectory"]];
    }
    if ([[appDelegate preferences] valueForKey:@"autoSnapshotsDirectory"]) {
        [[self autoSnapshotDir] setStringValue:[[appDelegate preferences] valueForKey:@"autoSnapshotsDirectory"]];
    }
    
    if ([[appDelegate preferences] valueForKey:@"streamingPassthrough"]) {
        [[self streamingPassthrough] setState:[[appDelegate preferences] boolForKey:@"streamingPassthrough"]];
    }
    if ([[appDelegate preferences] valueForKey:@"streamAutoRestart"]) {
        [[self streamAutoRestart] setState:[[appDelegate preferences] boolForKey:@"streamAutoRestart"]];
    }
    
    if([[appDelegate preferences] valueForKey:@"writeToUSB"]) {
        [[self writeToUSB] setState:[[appDelegate preferences] boolForKey:@"writeToUSB"]];
    }
    
    if([[appDelegate preferences] valueForKey:@"TSBackupEnabled"]) {
        [[self writeBackups] setState:[[appDelegate preferences] boolForKey:@"TSBackupEnabled"]];
    }
    
    if([[appDelegate preferences] valueForKey:@"outputFormat"]) {
        NSMenuItem* item = [[self formatSelect] itemWithTitle:[[appDelegate preferences] valueForKey:@"outputFormat"]];
        if (item) {
            [[self formatSelect] selectItemWithTitle: [[appDelegate preferences] valueForKey:@"outputFormat"]];
        }
    }
    
    if([[appDelegate preferences] valueForKey:@"TSBackupDir"]) {
        [[self TSBackupDir] setStringValue:[[appDelegate preferences] valueForKey:@"TSBackupDir"]];
    }
    
    if([[appDelegate preferences] valueForKey:@"x264preset"]) {
        NSMenuItem* item = [[self x264preset] itemWithTitle:[[appDelegate preferences] valueForKey:@"x264preset"]];
        if (item) {
            [[self x264preset] selectItemWithTitle: [[appDelegate preferences] valueForKey:@"x264preset"]];
        }
    }
    
    [[self audioBitrate] setStringValue:[[[appDelegate preferences] valueForKey:@"audioBitrate"] stringValue]];
    [[self videoBitrate] setStringValue:[[[appDelegate preferences] valueForKey:@"videoBitrate"] stringValue]];
    [[self H264videoBitrate] setStringValue:[[[appDelegate preferences] valueForKey:@"H264VideoBitrate"] stringValue]];
    [[self H264videoBitrateSlider] setIntegerValue:[[[appDelegate preferences] valueForKey:@"H264VideoBitrate"] integerValue]];
    [[self snapshotInterval] setIntegerValue:[[appDelegate preferences] integerForKey:@"autoSnapshotsInterval"]];
    
    if([[appDelegate preferences] boolForKey:@"streamingPassthrough"] == YES) {
        [[self videoBitrate] setEnabled:NO];
        [[self x264preset] setEnabled:NO];
    } else {
        [[self videoBitrate] setEnabled:YES];
        [[self x264preset] setEnabled:YES];
    }
    
    if([[appDelegate preferences] valueForKey:@"tcpInterfacePort"]) {
        [[self TCPInterfacePort] setStringValue:[[[appDelegate preferences] valueForKey:@"tcpInterfacePort"] stringValue]];
    }
    
    if([[appDelegate preferences] valueForKey:@"crestronInterfacePort"]) {
        [[self CrestronInterfacePort] setStringValue:[[[appDelegate preferences] valueForKey:@"crestronInterfacePort"] stringValue]];
    }
    
    if([[appDelegate preferences] valueForKey:@"streamTimeout"]) {
        [[self StreamTimeout] setStringValue:[[[appDelegate preferences] valueForKey:@"streamTimeout"] stringValue]];
    }
    if([[appDelegate preferences] valueForKey:@"recordTimeout"]) {
        [[self RecordTimeout] setStringValue:[[[appDelegate preferences] valueForKey:@"recordTimeout"] stringValue]];
    }
    if([[appDelegate preferences] valueForKey:@"autoSnapshotTimeout"]) {
        [[self AutoSnapshotTimeout] setStringValue:[[[appDelegate preferences] valueForKey:@"autoSnapshotTimeout"] stringValue]];
    }
}

-(IBAction) recordingFolderDialog:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setCanCreateDirectories:YES];
    
    if([panel runModal] == NSOKButton) {
        NSLog(@"OK Button was pressed! URL: %@", [[panel URL] path]);
        [[self recordingDir] setStringValue:[[panel URL] path]];
    }
}

-(IBAction) snapshotFolderDialog:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setCanCreateDirectories:YES];
    
    if([panel runModal] == NSOKButton) {
        NSLog(@"OK Button was pressed! URL: %@", [[panel URL] path]);
        [[self snapshotDir] setStringValue:[[panel URL] path]];
    }
}

-(IBAction) autoSnapshotFolderDialog:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setCanCreateDirectories:YES];
    
    if([panel runModal] == NSOKButton) {
        NSLog(@"OK Button was pressed! URL: %@", [[panel URL] path]);
        [[self autoSnapshotDir] setStringValue:[[panel URL] path]];
    }
}

-(IBAction) TSBackupDirDialog:(id) sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setCanCreateDirectories:YES];
    
    if([panel runModal] == NSOKButton) {
        NSLog(@"OK Button was pressed! URL: %@", [[panel URL] path]);
        [[self TSBackupDir] setStringValue:[[panel URL] path]];
    }
}

-(IBAction) passthroughToggled: (id) sender {
    if([[self streamingPassthrough] state] == YES) {
        [[self videoBitrate] setEnabled:NO];
        [[self x264preset] setEnabled:NO];
    } else {
        [[self videoBitrate] setEnabled:YES];
        [[self x264preset] setEnabled:YES];
    }
}

-(IBAction) closeWindow:(id)sender {
    [self close];
}

-(IBAction) applyChanges:(id)sender {
    [[appDelegate preferences] setObject:[[self streamUrl] stringValue] forKey:@"streamUrl"];
    [[appDelegate preferences] setObject:[[self streamKey] stringValue] forKey:@"streamKey"];
    
    [[appDelegate preferences] setObject:[[self recordingDir] stringValue] forKey:@"recordingDir"];
    [[appDelegate preferences] setObject:[[self snapshotDir] stringValue] forKey:@"snapshotsDirectory"];
    [[appDelegate preferences] setObject:[[self autoSnapshotDir] stringValue] forKey:@"autoSnapshotsDirectory"];
    
    [[appDelegate preferences] setBool:[[self streamingPassthrough] state] forKey:@"streamingPassthrough"];
    [[appDelegate preferences] setBool:[[self streamAutoRestart] state] forKey:@"streamAutoRestart"];
    [[appDelegate preferences] setBool:[[self writeToUSB] state] forKey:@"writeToUSB"];
    [[appDelegate preferences] setObject:[NSNumber numberWithInteger:[[[self audioBitrate] stringValue] integerValue]] forKey:@"audioBitrate"];
    [[appDelegate preferences] setObject:[NSNumber numberWithInteger:[[[self videoBitrate] stringValue] integerValue]] forKey:@"videoBitrate"];
    [[appDelegate preferences] setObject:[NSNumber numberWithInteger:[[self H264videoBitrate] integerValue]] forKey:@"H264VideoBitrate"];
    [[appDelegate preferences] setObject:[[self x264preset] titleOfSelectedItem] forKey:@"x264preset"];
    [[appDelegate preferences] setObject:[[self formatSelect] titleOfSelectedItem] forKey:@"outputFormat"];
    [[appDelegate preferences] setObject:[NSNumber numberWithInteger:[[self snapshotInterval] integerValue]] forKey:@"autoSnapshotsInterval"];
    
    [[appDelegate preferences] setObject:[NSNumber numberWithInteger:[[[self TCPInterfacePort] stringValue] integerValue]] forKey:@"tcpInterfacePort"];
    [[appDelegate preferences] setObject:[NSNumber numberWithInteger:[[[self CrestronInterfacePort] stringValue] integerValue]] forKey:@"crestronInterfacePort"];
    
    [[appDelegate preferences] setBool:[[self writeBackups] state] forKey:@"TSBackupEnabled"];
    [[appDelegate preferences] setObject:[[self TSBackupDir] stringValue] forKey:@"TSBackupDir"];
    
    [[appDelegate preferences] setObject:[NSNumber numberWithInteger:[[[self StreamTimeout] stringValue] integerValue]] forKey:@"streamTimeout"];
    [[appDelegate preferences] setObject:[NSNumber numberWithInteger:[[[self RecordTimeout] stringValue] integerValue]] forKey:@"recordTimeout"];
    [[appDelegate preferences] setObject:[NSNumber numberWithInteger:[[[self AutoSnapshotTimeout] stringValue] integerValue]] forKey:@"autoSnapshotTimeout"];
    
    [[appDelegate preferences] synchronize];
    
    [appDelegate settingsChanged];
    
    [self close];
}

-(IBAction)sliderDidMove:(id)sender {
    [[self H264videoBitrate] setStringValue:[[self H264videoBitrateSlider] stringValue]];
}

//-(IBAction)autoSnapshotChanged:(id)sender {
//    sender = [self autoSnapshots];
//    if ([sender state] == NSOffState) {
//        [[self autoSnapshotDir] setEnabled:NO];
//        [[self snapshotInterval] setEnabled:NO];
//        [[self autoSnapshotDialogButton] setEnabled:NO];
//    } else {
//        [[self autoSnapshotDir] setEnabled:YES];
//        [[self snapshotInterval] setEnabled:YES];
//        [[self autoSnapshotDialogButton] setEnabled:YES];
//    }
//}

@end
