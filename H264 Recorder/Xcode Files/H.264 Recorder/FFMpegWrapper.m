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

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readData:) name:NSFileHandleDataAvailableNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminated:) name:NSTaskDidTerminateNotification object:ffmpeg];
        
        isTerminating = NO;
        @try {
        [ffmpeg launch];
        }
        @catch (NSException* exception) {
            NSLog(@"Caught exception %@ %@", [exception name], [exception description]);
            return;
        }
        [_stderr waitForDataInBackgroundAndNotify];
        [_stdout waitForDataInBackgroundAndNotify];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:_label object:@"started"];
    } else {
        NSLog(@"FFMpegWrapper: Could not open pipes!");
        [[NSNotificationCenter defaultCenter] postNotificationName:_label object:@"stopped"];
    }
    
}

-(void) terminated: (NSNotification*) notification {
    [closeLock lock];
    isTerminating = YES;
    [_stderr closeFile];
    [_stdout closeFile];
    [_stdin closeFile];
    [closeLock unlock];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
        NSLog(@"Data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        
        [[notification object] waitForDataInBackgroundAndNotify];
    }
    
    if([fh isEqual:_stdout]) {
        
    }
    }
}

-(void) writeData:(NSData*) data {
    [closeLock lock];
    if([ffmpeg isRunning] && !isTerminating) {
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
    [closeLock unlock];
}

-(void) terminateTask {
    if (!isTerminating) {
        [[NSNotificationCenter defaultCenter] postNotificationName:_label object:@"stopped"];
    }
    [closeLock lock];
    isTerminating = YES;
    if([ffmpeg isRunning]) {
        [ffmpeg terminate];
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [_stderr closeFile];
        [_stdout closeFile];
        [_stdin closeFile];
    }
    [closeLock unlock];
}

-(BOOL) isRunning {
    return [ffmpeg isRunning];
}
@end
