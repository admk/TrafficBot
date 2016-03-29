//
//  AKAnniversaryManager.m
//  TrafficBot
//
//  Created by Gao Xitong on 10/10/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import "AKAnniversaryManager.h"
#import "AKAnniversary.h"

@implementation AKAnniversaryManager

- (id)init
{
    self = [super init];
    if (!self) return nil;

    _anniversaries = nil;

    return self;
}
- (void)dealloc
{
    [_anniversaries release], _anniversaries = nil;
    [super dealloc];
}

- (void)setAnniversaries:(NSArray *)anniversaries
{
    @synchronized(self)
    {
        [_anniversaries release];
        _anniversaries = [[anniversaries sortedArrayUsingSelector:@selector(compare:)] retain];
    }
}
- (NSArray *)anniversaries
{
    id returned;
    @synchronized(self)
    {
        returned = [_anniversaries retain];
    }
    return [returned autorelease];
}

- (AKAnniversary *)nextAnniversary
{
    id anni = nil;
    @synchronized(self)
    {
        if ([_anniversaries count])
        {
            anni = [[_anniversaries objectAtIndex:0] retain];
        }
    }
    return [anni autorelease];
}

- (NSDate *)nextDate
{
    id date;
    @synchronized(self)
    {
        date = [[[self nextAnniversary] nextDate] retain];
    }
    return [date autorelease];
}

#pragma mark - debug verbose
#ifdef DEBUG
- (void)setValue:(id)value forKey:(NSString *)key {
	DLog(@"\"%@\" = %@", key, value);
	[super setValue:value forKey:key];
}
#endif

@synthesize anniversaries = _anniversaries;
@end
