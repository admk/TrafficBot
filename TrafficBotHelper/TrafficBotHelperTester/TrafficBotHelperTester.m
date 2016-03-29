//
//  TrafficBotHelperTester.m
//  TrafficBotHelper
//
//  Created by System Administrator on 9/24/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "TrafficBotHelperTester.h"
#import "TrafficBotHelperConnection.h"
#import "TrafficBotHelper.h"

@implementation TrafficBotHelperTester

- (id)init
{
    self = [super init];

    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group,
                         dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
                         ^{
                             [[TrafficBotHelper alloc] init];
                             [[NSRunLoop currentRunLoop] run];
                         });
    sleep(1);

    id server = tbhVendServer(nil, @selector(die:), [NSArray arrayWithObjects:@"en0", @"en1", nil]);
    SEL selectors[4] = {
        @selector(version),
        @selector(start),
        @selector(stop),
        @selector(statistics)
    };
    for (int i = 0; i < 1000; i++)
    {
        SEL sel = selectors[rand() % 4];
        DLog(@"%d %@", i, NSStringFromSelector(sel));
        [server performSelector:sel];
    }
    
    return self;
}

- (void)die:(NSNotification *)note
{
    DLog(@"die");
}

@end
