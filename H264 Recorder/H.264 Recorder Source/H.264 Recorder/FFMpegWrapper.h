//
//  FFMpegWrapper.h
//  H.264 Recorder
//
//  Created by Filip Sandborg-Olsen on 20/02/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FFMpegWrapper : NSObject {
    NSTask* ffmpeg;
    
    NSFileHandle* _stdout;
    NSFileHandle* _stderr;
    NSFileHandle* _stdin;
    
    BOOL _autoRestart;
    NSArray* _args;
    NSString* _label;
    BOOL isTerminating;
    NSLock* closeLock;
}

-(void) writeData: (NSData*)data;
-(void) terminateTask;
-(BOOL) isRunning;
-(NSTask*) getFFmpeg;

@property (assign) Boolean hasStarted;

@property (copy) NSString* totalTime;

-(FFMpegWrapper*) initWithArguments:(NSArray*) args autoRestart:(BOOL) autoRestart label:(NSString *)label;
@end
