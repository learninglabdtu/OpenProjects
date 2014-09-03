//
//  CrestronInterface.h
//  H.264 Recorder
//
//  Created by Filip Sandborg-Olsen on 28/08/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

@class AppDelegate;
@class H264Recorder;

@interface CrestronInterface : NSObject <GCDAsyncSocketDelegate> {
    GCDAsyncSocket* socket;
    dispatch_queue_t queue;
    NSMutableArray* clientList;
    AppDelegate* appDelegate;
    H264Recorder* _recorder;
}

-(CrestronInterface*) initWithPort:(uint16_t)port andRecorder:(H264Recorder*)recorder;
@end
