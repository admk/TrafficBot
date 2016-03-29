//
//  AKAnniversary.m
//  TrafficBot
//
//  Created by Gao Xitong on 10/10/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import "AKAnniversary.h"
#import "TTTOrdinalNumberFormatter.h"

@implementation AKAnniversary

#pragma mark - ctor & dtor
- (id)initWithDate:(NSDate *)date repeat:(anni_repeat_t)repeat
{
    self = [super init];
    if (!self) return nil;

    _startDate = [date retain];
    _repeat = repeat;

    return self;
}
- (void)dealloc
{
    [_startDate release], _startDate = nil;
    [super dealloc];
}
+ (id)anniversaryWithDate:(NSDate *)date repeat:(anni_repeat_t)repeat
{
    return [[[[self class] alloc] initWithDate:date repeat:repeat] autorelease];
}

#pragma mark - proper stuff
- (NSDate *)nextDate
{    
    if ([self.startDate timeIntervalSinceNow] > 0) return self.startDate;

    static NSCalendar *gregorian = nil;
    if (!gregorian)
        gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [[[NSDateComponents alloc] init] autorelease];
    switch (self.repeat)
    {
        case anni_no_repeat: return nil; // in the past but still here
        case anni_daily_repeat: components.day = 1; break;
        case anni_weekly_repeat: components.week = 1; break;
        case anni_monthly_repeat: components.month = 1; break;
        case anni_undef_repeat: 
        default: ZAssert(0, @"Undefined repeat mode"); return nil;;
    }
    return [gregorian dateByAddingComponents:components toDate:self.startDate options:0]; 
}

#pragma mark - NSCoding
- (id)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithDate:[aDecoder decodeObjectForKey:Property(date)]
                       repeat:[[aDecoder decodeObjectForKey:Property(repeat)] intValue]];
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.startDate forKey:Property(date)];
    [aCoder encodeObject:[NSNumber numberWithInt:self.repeat] forKey:Property(repeat)];
}

#pragma mark - compare
- (NSComparisonResult)compare:(AKAnniversary *)other
{
    return [self.nextDate compare:other.nextDate];
}

#pragma mark - NSCopying
- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithDate:[[self.startDate copy] autorelease] repeat:self.repeat];
}

#pragma mark - equality & hashing
- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[self class]])
    {
        if (![_startDate isEqualToDate:[(AKAnniversary *)object startDate]]) return NO;
        if (_repeat != [(AKAnniversary *)object repeat]) return NO;
        return YES;
    }
    if (![_startDate isEqualToDate:[object valueForKey:Property(startDate)]]) return NO;
    if (_repeat != [[object valueForKey:Property(repeat)] intValue]) return NO;
    return YES;
}
- (NSUInteger)hash
{
    return _repeat ^ [_startDate hash];
}

#pragma mark - description
- (NSString *)description
{
    NSString *repeatString;
    switch (self.repeat)
    {
        case anni_no_repeat: repeatString = @"Once"; break;
        case anni_daily_repeat: repeatString = @"Every day"; break;
        case anni_weekly_repeat: repeatString = @"Every week"; break;
        case anni_monthly_repeat: repeatString = @"Every month"; break;
        case anni_undef_repeat: ZAssert(0, @"Unrecognized repeat mode"); break;
        default: break;
    }
    NSDateFormatter *fmt = [[[NSDateFormatter alloc] init] autorelease];
    [fmt setDateStyle:NSDateFormatterMediumStyle];
    [fmt setTimeStyle:NSDateFormatterMediumStyle];
    return [NSString stringWithFormat:@"%@: %@, starting from %@",
            [self class],
            NSLocalizedString(repeatString, @"repeat"),
            [fmt stringFromDate:self.startDate]];
}

- (NSString *)humanStringValue
{
    NSDateFormatter *fmt = [[[NSDateFormatter alloc] init] autorelease];

    NSString *string = nil;
    switch (self.repeat)
    {
        case anni_no_repeat:
        {
            [fmt setDateFormat:@"MM-dd HH:mm"];
            string = [fmt stringFromDate:self.startDate];
        } break;
        case anni_daily_repeat:
        {
            [fmt setDateFormat:@"HH:mm"];
            NSString *timeString = [fmt stringFromDate:self.startDate];
            string = [NSString stringWithFormat:NSLocalizedString(@"%@ Every day", @"every day"), timeString];
        } break;
        case anni_weekly_repeat:
        {
            [fmt setDateFormat:@"EEEE"];
            NSString *weekDay = [fmt stringFromDate:self.startDate];
            [fmt setDateFormat:@"HH:mm"];
            NSString *timeString = [fmt stringFromDate:self.startDate];
            string = [NSString stringWithFormat:NSLocalizedString(@"%@ Every %@", @"every day in a week"), timeString, weekDay];
        } break;
        case anni_monthly_repeat:
        {
            [fmt setDateFormat:@"dd"];
            NSInteger dateNumber = [[fmt stringFromDate:self.startDate] integerValue];

            TTTOrdinalNumberFormatter *numFmt = [[TTTOrdinalNumberFormatter alloc] init];
            [numFmt setLocale:[NSLocale currentLocale]];
            [numFmt setGrammaticalGender:TTTOrdinalNumberFormatterMaleGender];
            NSString *dateString = [numFmt stringFromNumber:[NSNumber numberWithInteger:dateNumber]];
            string = [NSString stringWithFormat:NSLocalizedString(@"%@ Every month", @"a day of every month"), dateString];
        } break;
        case anni_undef_repeat:
        default: ZAssert(0, @"Unrecognized repeat mode"); break;
    }
    if (string && [self.startDate timeIntervalSinceNow] > 0)
    {
        [fmt setDateFormat:@"MM/dd HH:mm"];
        string = [string stringByAppendingFormat:@"\nfrom %@", [fmt stringFromDate:self.startDate]];
    }
    return string;
}

@synthesize startDate = _startDate;
@synthesize repeat = _repeat;
@end
