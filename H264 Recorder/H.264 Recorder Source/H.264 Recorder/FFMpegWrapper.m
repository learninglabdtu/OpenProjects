//
//  FFMpegWrapper.m
//  H.264 Recorder
//
//  Created by Filip Sandborg-Olsen on 20/02/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import "FFMpegWrapper.h"

@implementation FFMpegWrapper
-(FFMpegWrapper*) initWithArguments:(NSArray*) args autoRestart:(BOOL) autoRestart label:(NSString *)label {
    
    _autoRestart = autoRestart;
    _args = args;
    _label = label;
    [self setHasStarted:NO];
    
    closeLock = [[NSLock alloc] init];
    
    _totalTime = @"00:00:00";
    
    [self startTask];
    
    return self;
}

-(NSTask*) getFFmpeg {
    return ffmpeg;
}

-(void) startTask {
    
    NSLog(@"Starting FFMpeg");
    ffmpeg = [[NSTask alloc] init];
    NSString *execPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"ffmpeg"];

    [ffmpeg setLaunchPath:execPath];
    [ffmpeg setArguments:_args];
    
    [ffmpeg setStandardInput:[NSPipe pipe]];
    [ffmpeg setStandardOutput: [NSPipe pipe]];
    [ffmpeg setStandardError: [NSPipe pipe]];
    
    if([ffmpeg standardError] && [ffmpeg standardOutput] && [ffmpeg standardInput]) {
        _stderr = [[ffmpeg standardError] fileHandleForReading];
        _stdout = [[ffmpeg standardOutput] fileHandleForReading];
        _stdin = [[ffmpeg standardInput] fileHandleForWriting];
        
        isTerminating = NO;
        @try {
            [ffmpeg launch];
        }
        @catch (NSException* exception) {
            NSLog(@"Caught exception %@ %@", [exception name], [exception description]);
            return;
        }

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readData:) name:NSFileHandleDataAvailableNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminated:) name:NSTaskDidTerminateNotification object:ffmpeg];
        
        [_stderr waitForDataInBackgroundAndNotify];
        [_stdout waitForDataInBackgroundAndNotify];
        
        
        [[NSNotificationCenter defaultCenter] postNotificationName:_label object:@"started"];
    } else {
        NSLog(@"FFMpegWrapper: Could not open pipes!");
        [[NSNotificationCenter defaultCenter] postNotificationName:_label object:@"stopped"];
    }
    
}

-(void) terminated: (NSNotification*) notification {
    [self terminateTask];
    [[NSNotificationCenter defaultCenter] postNotificationName:_label object:@"stopped"];
    
    if(_autoRestart) {
        [self startTask];
    }
}

-(void) readData:(NSNotification*) notification {
    @autoreleasepool {
        NSFileHandle* fh = [notification object];
        
        if([fh isEqual:_stderr]) {
            NSData* data = [fh availableData];
            NSString* output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            if ([output hasPrefix:@"frame"]) {
                NSArray* matches = [[[NSRegularExpression alloc] initWithPattern:@"(frame|fps|q|size|time|bitrate)\\s*?=\\s*?([^ ]+)" options:0 error:nil] matchesInString:output options:0 range:NSMakeRange(0, [output length])];
                
                if (matches && [matches count] == 6) {
                    NSString* time = [output substringWithRange:[[matches objectAtIndex:4] rangeAtIndex:2]];
                    _totalTime = [[time componentsSeparatedByString:@"."] objectAtIndex:0];
                }
               // NSArray *items = [[output stringByReplacingOccurrencesOfString:@"= " withString:@"="] componentsSeparatedByString:@" "];
               // NSLog(@"%@", items);
            } else {
                NSLog(@"Data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            }
        }
        
        if([fh isEqual:_stdout]) { // We don't really care about stdout..
            NSData* data = [fh availableData];
            NSLog(@"Stdout: %@", data);
        }
        
        [[notification object] waitForDataInBackgroundAndNotify];
    }
}

-(void) writeData:(NSData*) data {
    if([ffmpeg isRunning]) { // Should still write if process isTerminating, as a frame could be incomplete
        [self setHasStarted:YES];
        @try {
            [_stdin writeData:data];
        }
        @catch (NSException *exception) {
            // Most likely just a broken pipe, happens when the Task stops.
            //NSLog(@"%@ %@", [exception name],[exception description]);
        }
        @finally {
            
        }
    }
}

-(void) terminateTask {
    _totalTime = @"00:00:00";
    
    [closeLock lock];
    isTerminating = YES;
    if([ffmpeg isRunning]) {
        [ffmpeg interrupt]; // Important that ffmpeg is closed this way
        
        if([self isRunning]){
            NSLog(@"FFMpeg is still running. Waiting for process to quit gracefully...");
            int tries = 0;
            while([self isRunning]) {
                if (tries++ > 10) {
                    [ffmpeg terminate];
                    NSLog(@"FFmpeg did not quit gracefully within 5 seconds, and was terminated. Output is possibly corrupt.");
                    break;
                }
                [NSThread sleepForTimeInterval:0.5f];
            }
            NSLog(@"FFMpeg finished");
            [[NSNotificationCenter defaultCenter] postNotificationName:_label object:@"stopped"];
        }
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_stderr closeFile];
    [_stdout closeFile];
    [_stdin closeFile];
    
    [closeLock unlock];
}

-(BOOL) isRunning {
    return [ffmpeg isRunning];
}
@end
