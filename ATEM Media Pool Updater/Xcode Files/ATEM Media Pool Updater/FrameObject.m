//
//  FrameObject.m
//  ATEM Media Pool Updater
//
//  Created by Filip Sandborg-Olsen on 30/01/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import "FrameObject.h"
#import "BMDSwitcherAPI.h"


@implementation FrameObject
@synthesize frameHeight;
@synthesize frameWidth;
@synthesize frameData;
@synthesize pixfmt;

-(FrameObject*) initWithFrame:(IBMDSwitcherFrame *)f andIndex:(uint32_t) idx{
    frameWidth = f->GetWidth();
    frameHeight = f->GetHeight();
    pixfmt = f->GetPixelFormat();
    
    uint32_t frameSize = 0;
    
    switch (f->GetPixelFormat()) {
        case bmdSwitcherPixelFormat10BitYUVA:
        case bmdSwitcherPixelFormat8BitARGB:
        case bmdSwitcherPixelFormat8BitXRGB:
            frameSize = 4 * frameWidth * frameHeight;
            break;
        case bmdSwitcherPixelFormat8BitYUV:
            frameSize = 2 * frameWidth * frameHeight;
            break;
        default:
            NSLog(@"Pixel format not detected!!");
            break;
    }
    
    if (frameSize == 0) {
        return NULL;
    } else {
        void **data = (void**)malloc(frameSize);
        f->GetBytes(data);
        frameData = [[NSData alloc] initWithBytes:*data length:frameSize];
        free(data);
        return self;
    }
}

@end
