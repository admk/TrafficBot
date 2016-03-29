//
//  AKAnniversaryManager.h
//  TrafficBot
//
//  Created by Gao Xitong on 10/10/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AKAnniversary;

@interface AKAnniversaryManager : NSObject
{
    NSArray *_anniversaries;
}

@property (retain) NSArray *anniversaries;

- (AKAnniversary *)nextAnniversary;
- (NSDate *)nextDate;

@end
