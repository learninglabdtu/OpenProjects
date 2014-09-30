//
//  AppDelegate.m
//  ATEM Media Pool Updater
//
//  Created by Filip Sandborg-Olsen on 15/01/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import "SwitcherMediaPoolAppDelegate.h"

@implementation SwitcherMediaPoolAppDelegate

NSString* path = [NSHomeDirectory() stringByAppendingPathComponent:@"ATEMUpdater"];

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    lastValidityCheck = [[NSDate alloc] init];
    
    settings = [NSUserDefaults standardUserDefaults];
    
    NSArray* switchers = [settings objectForKey:@"switchers"];
    if (switchers == nil) {
        [settings setObject:@[] forKey:@"switchers"];
    }
    NSDictionary* stdValues = @{@"auto": @false, @"status": @"Idle", @"connected":@false, @"enabled": @true};
    
    for (NSDictionary* el in [settings objectForKey:@"switchers"]) {
        for (NSString* key in stdValues) {
            if ([el objectForKey:key] == nil) {
                [self setParameter:[stdValues objectForKey:key] withKey:key forIP:[el objectForKey:@"ip"]];
            }
        }
    }
    
    if([settings objectForKey:@"updateInterval"] == nil) {
        [settings setObject:@60 forKey:@"updateInterval"];
    }
    [settings synchronize];
    
    [_interval setStringValue:[[settings objectForKey:@"updateInterval"] stringValue]];
    
    [[self tableView] reloadData];
    
    
    NSFileManager* fm = [NSFileManager alloc];
    BOOL isDir = NO;
    
    if (![fm fileExistsAtPath:path isDirectory:&isDir]) {
        NSLog(@"Creating media directory: %@", path);
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:Nil error:nil];
    }
    mediaPoolWatchers = [[NSMutableDictionary alloc] init];
    

    for (NSDictionary* el in [settings objectForKey:@"switchers"]) {
        if ([[el objectForKey:@"enabled"] isEqual:@true]) {
            [self connectToSwitcher:[el objectForKey:@"ip"]];
        }
    }
    
    timer = [NSTimer scheduledTimerWithTimeInterval:[[settings objectForKey:@"updateInterval"] floatValue] target:self selector:@selector(checkValidity) userInfo:nil repeats:YES];
    [timer fire];
    
    [NSTimer scheduledTimerWithTimeInterval:5.0f target:self selector:@selector(updateTimeToNextCheck) userInfo:nil repeats:YES];
}

-(void) updateTimeToNextCheck {
    double updateInterval = [[settings objectForKey:@"updateInterval"] integerValue];
    NSTimeInterval remaining = updateInterval - [[NSDate date] timeIntervalSinceDate:lastValidityCheck];
    NSInteger intVal = [[NSNumber numberWithDouble:remaining] integerValue];
    
    [_userNotification setStringValue:[NSString stringWithFormat:@"Next media bank check in %ld s", (long)intVal]];
}

-(void) connectToSwitcher: (NSString*) ip {
    [self setParameter:@false withKey:@"connected" forIP:ip];
    [self setParameter:@"Not connected" withKey:@"status" forIP:ip];
    
    mediaPoolWatcher = [[MediaPoolWatcher alloc] initWithIP:ip andBaseDir:path withDelegate:self];
    [mediaPoolWatchers setObject:mediaPoolWatcher forKey:ip];
    [mediaPoolWatcher performSelectorInBackground:@selector(connectToSwitcher) withObject:nil];
}

-(void) checkValidity: (MediaPoolWatcher*) mw {
    NSString* ip = [mw mIP];
    
    if([mw isConnected]) {
        if(![mw stillsAreValid]) {
            // Set yellow icon
            if ([mw localStillsExist]) {
                [self setStatusMsg:@{@"ip": ip, @"status":@"Connected, Media Bank Content Mismatch"}];
            } else {
                [self setStatusMsg:@{@"ip": ip, @"status":@"Connected, please press 'pull'"}];
            }
            if(![[mediaPoolWatchers objectForKey:ip] isBusy]) {
                // If auto-update is on, trigger this..
                for (NSDictionary* el in [settings objectForKey:@"switchers"]) {
                    if ([[el objectForKey:@"ip"] isEqualToString:ip]) {
                        if ([[el objectForKey:@"auto"] isEqual: @true]) {
                            if ([mw localStillsExist]) {
                                [[mediaPoolWatchers objectForKey:ip] autoUpdateStills];
                            } else {
                                NSLog(@"No local stills exist for %@. Disabling auto-update", ip);
                                [self setParameter:@false withKey:@"auto" forIP:ip];
                            }
                        }

                    }
                }
            }
        } else {
            // Set green icon
            [self setStatusMsg:@{@"ip": ip, @"status":@"Connected"}];
        }
    }
}

-(void) checkValidity {
    lastValidityCheck = [NSDate date];
    for (NSString* ip in mediaPoolWatchers) {
        MediaPoolWatcher* mw = [mediaPoolWatchers objectForKey:ip];
        [self checkValidity: mw];
    }
}

- (void) switcherActionCompleted:(NSString*) switcherIP {
    [self setParameter:@"Connected" withKey:@"status" forIP:switcherIP];
}

-(void) setParameter:(id) param withKey: (NSString*) key forIP: (NSString*) ip {
    NSMutableArray* copy = [[settings objectForKey:@"switchers"] mutableCopy];
    NSMutableDictionary* settingsCopy;
    NSInteger switcherIndex = -1;
    for (NSDictionary* el in copy) {
        if ([[el objectForKey:@"ip"] isEqualToString:ip]) {
            switcherIndex = [copy indexOfObject:el];
            settingsCopy = [el mutableCopy];
            [settingsCopy setObject:param forKey:key];
            break;
        }
    }
    if(settingsCopy != nil && switcherIndex != -1) {
        [copy replaceObjectAtIndex:switcherIndex withObject: settingsCopy];
        [settings setObject:copy forKey:@"switchers"];
        
        [settings synchronize];

        [[self tableView] reloadData];
    }
}

- (void) switcherConnectionEstablished:(NSString*) switcherIP {
    MediaPoolWatcher* w = [mediaPoolWatchers objectForKey:switcherIP];
    [self setParameter:@"Connected" withKey:@"status" forIP:switcherIP];
    [self setParameter:@true withKey:@"connected" forIP:switcherIP];
    [self checkValidity: w];
}

- (void) switcherConnectionFailed: (NSString*) switcherIP {
    [self setParameter:@false withKey:@"connected" forIP:switcherIP];
    [self setParameter:@"Not connected" withKey:@"status" forIP:switcherIP];
    [[mediaPoolWatchers objectForKey:switcherIP] performSelectorInBackground:@selector(connectToSwitcher) withObject:nil];
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [[settings objectForKey:@"switchers"] count];
}

-(void) setStatusMsg:(NSDictionary*)values {
    [self setParameter:[values objectForKey:@"status"] withKey:@"status" forIP:[values objectForKey:@"ip"]];
}

-(id) tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString* identifier = [tableColumn identifier];
    NSDictionary* element = [[settings objectForKey:@"switchers"] objectAtIndex:row];
    if([identifier isEqualToString:@"ip"]) {
        return [element objectForKey:@"ip"];
    } else if([identifier isEqualToString:@"automode"]) {
        return [element objectForKey:@"auto"];
    } else if([identifier isEqualToString:@"status"]) {
        if ([[element objectForKey:@"enabled"] isEqual: @true]) {
            return [element objectForKey:@"status"];
        } else {
            return @"Disabled";
        }
    } else if([identifier isEqualToString:@"connection_image"]) {
        if ([[element objectForKey:@"enabled"] isEqual: @true]) {
            if([[element objectForKey:@"connected"] isEqual:@true]) {
                return [NSImage imageNamed:@"green"];
            } else {
                return [NSImage imageNamed:@"red"];
            }
        } else {
            return [NSImage imageNamed:@"gray"];
        }
    } else if([element objectForKey:@"enabled"]) {
        return [element objectForKey:@"enabled"];
    } else {
        return nil;
    }
}

-(void) tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString* identifier = [tableColumn identifier];
    NSDictionary* element = [[settings objectForKey:@"switchers"] objectAtIndex:row];
    MediaPoolWatcher* mw = [mediaPoolWatchers objectForKey:[element objectForKey:@"ip"]];
    
    if([identifier isEqualToString:@"automode"]) {
        if ([object isEqual:@true]) {
            if (![mw localStillsExist]) {
                NSBeginAlertSheet(@"Please pull before enabling automode.", @"OK", nil, nil, _window, nil, nil, nil, nil, @"");
                return;
            }
        }
        [self setParameter:object withKey:@"auto" forIP:[element objectForKey:@"ip"]];
    } else if([identifier isEqualToString:@"push"]) {
        if (![mw isBusy] && [mw isConnected]) {
            [mw pushStills];
        }
    } else if([identifier isEqualToString:@"pull"]) {
        if (![mw isBusy] && [mw isConnected]) {
            [mw pullStills];
        }
    } else if([identifier isEqualToString:@"repair"]) {
        if (![mw localStillsExist]) {
            NSBeginAlertSheet(@"Please pull before repairing.", @"OK", nil, nil, _window, nil, nil, nil, nil, @"");
        } else {
            if (![mw isBusy] && [mw isConnected]) {
                [mw autoUpdateStills];
            }
        }
    } else if([identifier isEqualToString:@"enable"]) {
        if ([object isEqual: @true]) {
            if (mw == nil) {
                [self connectToSwitcher:[element objectForKey:@"ip"]];
            }
        } else {
            if (mw != nil) {
                [mw isTerminating];
                [mw cleanupConnection];
                [mediaPoolWatchers removeObjectForKey:[element objectForKey:@"ip"]];
            }
        }
        [self setParameter:object withKey:@"enabled" forIP:[element objectForKey:@"ip"]];
        [[self tableView] reloadData];
    }
}

-(void) tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString* identifier = [tableColumn identifier];
    NSDictionary* element = [[settings objectForKey:@"switchers"] objectAtIndex:row];
    MediaPoolWatcher *mw = [mediaPoolWatchers objectForKey:[element objectForKey:@"ip"]];
    
    if (![identifier isEqualToString:@"enable"]) {
        if ([[element objectForKey:@"connected"] isEqual: @false] || [[element objectForKey:@"enabled"] isEqual: @false]) {
            [cell setEnabled:NO];
        } else {
            [cell setEnabled: YES];
            
            if(mw != nil && ([identifier isEqualToString:@"pull"] || [identifier isEqualToString:@"repair"])) {
                if([mw isBusy]) {
                    [cell setEnabled:NO];
                } else {
                    [cell setEnabled:YES];
                }
            }
        }
    }
    if([identifier isEqualToString:@"enable"]) {
        
    }

}

-(void) tableViewSelectionDidChange:(NSNotification *)notification {
    if ([[self tableView] selectedRow] != -1) {
        [[self removeButton] setEnabled:YES];
    } else {
        [[self removeButton] setEnabled:NO];
    }
}

-(IBAction)removeTableItem:(id) sender{
    NSInteger row = [[self tableView] selectedRow];

    NSMutableArray* copy = [[settings objectForKey:@"switchers"] mutableCopy];
    NSDictionary* switcherConfig = [copy objectAtIndex:row];
    
    MediaPoolWatcher* mw = [mediaPoolWatchers objectForKey:[switcherConfig objectForKey:@"ip"]];
    
    // Ask thread to stop, if it is currently working
    [mw isTerminating];
    
    [mediaPoolWatchers removeObjectForKey:[switcherConfig objectForKey:@"ip"]];

    [copy removeObjectAtIndex:row];
    [settings setObject:copy forKey:@"switchers"];
    [settings synchronize];
    
    [[self tableView] reloadData];
}

-(bool) isSwitcherWithIP: (NSString*) ip {
    for (NSDictionary* el in [settings objectForKey:@"switchers"]) {
        if ([[el objectForKey:@"ip"] isEqualToString:ip]) {
            return true;
        }
    }
    return false;
}
-(NSString*) isValidIP: (NSString*) ip {
    NSArray* parts = [ip componentsSeparatedByString:@"."];
    NSMutableString* sanitizedIP = [[NSMutableString alloc] init];
    if ([parts count] != 4) {
        return nil;
    }
    if([parts[0] integerValue] == 0) {
        return nil;
    }
    for (NSString* part in parts) {
        NSInteger n = [part integerValue];
        if (n < 0 || n >= 255) {
            return nil;
        }
        [sanitizedIP appendFormat:@"%ld.",(long)n];
    }
    return [sanitizedIP substringToIndex:[sanitizedIP length]-1];
}

-(IBAction)addSwitcher:(id) sender {
    NSString* ip = [self isValidIP:[[self ipField] stringValue]];
    
    if (ip != nil) [[self ipField] setStringValue:ip];
    
    if(ip == nil) {
        NSBeginAlertSheet(@"Please enter a valid IP address.", @"OK", nil, nil, _window, nil, nil, nil, nil, @"");
    } else if ([self isSwitcherWithIP:ip]) {
        NSBeginAlertSheet(@"A switcher instance with this address is already registered.", @"OK", nil, nil, _window, nil, nil, nil, nil, @"");
    } else {
        NSMutableArray* copy = [[settings objectForKey:@"switchers"] mutableCopy];
        [copy addObject:@{@"ip":ip, @"auto": @false, @"status": @"Idle", @"connected":@false, @"enabled": @true}];
        [settings setObject:copy forKey:@"switchers"];
        [settings synchronize];
        [[self tableView] reloadData];
        
        mediaPoolWatcher = [[MediaPoolWatcher alloc] initWithIP:ip andBaseDir:path withDelegate:self];
        [mediaPoolWatchers setObject:mediaPoolWatcher forKey:ip];
        
        [mediaPoolWatcher performSelectorInBackground:@selector(connectToSwitcher) withObject:nil];
        [[self ipField] setStringValue:@""];
    }
}

-(BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void) controlTextDidEndEditing:(NSNotification *)obj {
    NSString* newValue = [_interval stringValue];
    if([newValue integerValue] > 10) {
        [settings setObject:[NSNumber numberWithInteger:[newValue integerValue]] forKey:@"updateInterval"];
        [settings synchronize];
        [timer invalidate];
        timer = [NSTimer scheduledTimerWithTimeInterval:[[settings objectForKey:@"updateInterval"] floatValue] target:self selector:@selector(checkValidity) userInfo:nil repeats:YES];
        [timer fire];
    } else {
        NSBeginAlertSheet(@"Please enter an integer value of seconds, greater than 10 seconds.", @"OK", nil, nil, _window, nil, nil, nil, nil, @"");
    }
    [_interval setStringValue:[[settings objectForKey:@"updateInterval"] stringValue]];
}

@end