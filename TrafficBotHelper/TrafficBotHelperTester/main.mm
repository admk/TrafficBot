//
//  main.m
//  TrafficBotHelperTester
//
//  Created by Xitong Gao on 9/24/11.
//  Copyright 2011 AK.Kloca. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TrafficBotHelperTester.h"

#ifdef DEBUG
#undef DEBUG
#endif

int main (int argc, const char * argv[])
{

    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    [[TrafficBotHelperTester alloc] init];

    [pool drain];
    return 0;
}

