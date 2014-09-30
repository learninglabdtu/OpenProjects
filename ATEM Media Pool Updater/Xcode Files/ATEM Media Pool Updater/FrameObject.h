//
//  FrameObject.h
//  ATEM Media Pool Updater
//
//  Created by Filip Sandborg-Olsen on 30/01/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BMDSwitcherAPI.h"

@interface FrameObject : NSObject {
    NSData* frameData;
    uint32_t frameHeight;
    uint32_t frameWidth;
    BMDSwitcherPixelFormat pixfmt;
}


- (FrameObject*) initWithFrame: (IBMDSwitcherFrame*) f andIndex: (uint32_t) index;
@property NSData* frameData;
@property uint32_t frameHeight;
@property uint32_t  frameWidth;
@property BMDSwitcherPixelFormat pixfmt;

@end
