//
//  H264Recorder.h
//  H.264 Recorder
//
//  Created by Filip Sandborg-Olsen on 20/02/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"
#import "FFMpegWrapper.h"

@protocol H264RecorderDelegate <NSObject>

-(void) stateUpdate:(NSDictionary*)state;
-(void) stoppedRecording;
-(void) stoppedStreaming;

@end

@interface H264Recorder : NSObject <GCDAsyncSocketDelegate> {
    NSConditionLock* isData;
    NSConditionLock* isConnection;
    
    NSFileHandle* USBFile;
    NSString* USBFilePath;
    
    NSFileHandle* TSBackupFile;
    
    NSPipe* pipe;
    
    NSString* outputFile;
    NSString* streamURL;
    
    FFMpegWrapper* recording;
    FFMpegWrapper* streaming;
    FFMpegWrapper* manualSnapshot;
    NSTimer* statusPollTimer;
    NSMutableArray* frames;
    
    NSString* deviceName;
    NSString* deviceInput;
    NSString* deviceDisplayMode;
    NSString* deviceState;
    
    NSString* currentRecordingFormat;
    NSString* currentOutputFile;
    
    NSRunLoop* runloop;
    dispatch_queue_t q;
    
    double dataCount;
    
    id _delegate;
    id appDelegate;
    
    NSString* recordingDir;
    Boolean streamingPassthrough;
    Boolean streamAutoRestart;
    
    NSString* x264preset;
    
    int width;
    int height;
    int framerate;
    Boolean interlaced;
    
    NSLock* stopLock;
    Boolean isTerminating;
    
    NSFileHandle* previewInput;
    
    NSTask* previewTask;
    
    NSDate* recordingStart;
    NSDate* streamingStart;
    NSDate* autoSnapshotStart;
    
    NSLock* statusLock;
}

@property GCDAsyncSocket* cmdSocket;
@property GCDAsyncSocket* dataSocket;
@property NSNumber* recorderID;
@property NSDictionary* lastCommand;
@property Boolean isEncoding;
@property Boolean isStreaming;
@property Boolean isRecording;
@property Boolean isConnected;
@property Boolean isPreviewing;
@property Boolean isManualSnapshot;
@property Boolean isConfirmedRecording;
@property Boolean isConfirmedStreaming;

@property (retain) NSTimer* autoSnapshot;

@property NSTimer* recordTimer;
@property NSTimer* streamTimer;
@property NSTimer* autoSnapshotTimer;

-(BOOL) isUSBFileOpen;
-(BOOL) canRecordToUSB;
-(NSString*) getUSBVolumeName;

-(BOOL) startStreaming;
-(void) stopStreaming;
-(BOOL) startRecording;
-(void) stopRecording;
-(void) terminate;
-(void) videoPreview;
-(void) stopPreview;

-(BOOL) takeSnapshot;
-(BOOL) takeSnapshotWithPrefix: (NSString*) prefix;
-(NSString*) createPathWithFilename:(NSString*)filename inDir: (NSString*) dir;

-(void) startAutoSnapshots;
-(void) stopAutoSnapshots;

- (H264Recorder*) initwithDelegate:(id) delegate;

-(BOOL) checkStreaming;
-(BOOL) checkRecording;

-(NSString*) getRecordingStats;
-(NSString*) getStreamingStats;

-(void) connectToRecorder;

-(void) updateTimers;

@end
