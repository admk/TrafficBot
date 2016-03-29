//
//  AKAnniversary.h
//  TrafficBot
//
//  Created by Gao Xitong on 10/10/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum
{
    anni_no_repeat = 0,
    anni_daily_repeat = 1,
    anni_weekly_repeat = 2,
    anni_monthly_repeat = 3,
    anni_undef_repeat = -1
} anni_repeat_t;

@interface AKAnniversary : NSObject <NSCoding, NSCopying>
{
    NSDate *_startDate;
    anni_repeat_t _repeat;
}

@property (nonatomic, retain) NSDate *startDate;
@property (nonatomic, assign) anni_repeat_t repeat;

- (id)initWithDate:(NSDate *)date repeat:(anni_repeat_t)repeat;
+ (id)anniversaryWithDate:(NSDate *)date repeat:(anni_repeat_t)repeat;

- (NSDate *)nextDate;

- (NSComparisonResult)compare:(AKAnniversary *)other;

- (BOOL)isEqual:(id)object;
- (NSUInteger)hash;

- (NSString *)humanStringValue;

@end
