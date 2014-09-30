//
//  main.m
//  H.264 Recorder
//
//  Created by Filip Sandborg-Olsen on 20/02/14.
//  Copyright (c) 2014 Learninglab DTU. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <signal.h>

void sigpipeHandler(int s) {
    //NSLog(@"Caught SIGPIPE...");
}

int main(int argc, const char * argv[])
{
    signal(SIGPIPE, sigpipeHandler);
    return NSApplicationMain(argc, argv);
}
