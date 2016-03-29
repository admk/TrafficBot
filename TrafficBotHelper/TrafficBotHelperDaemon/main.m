//
//  main.m
//  TrafficBotHelper
//
//  Created by Xitong Gao on 18/09/2011.
//  Copyright 2011 AK.Kloca. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TrafficBotHelper.h"

#define AKTBHAutoreleaseInterval 10

AuthorizationRef gAuth;

int main(int argc, char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [[TrafficBotHelper alloc] init];
    BOOL isRunning;
    do {
        // run the loop!
        NSDate* theNextDate = [NSDate dateWithTimeIntervalSinceNow:AKTBHAutoreleaseInterval]; 
        isRunning = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:theNextDate]; 
        [pool release];
        pool = [[NSAutoreleasePool alloc] init];
    } while(isRunning);
    [pool release];
    return 0;
}
