//
//  TBSummaryGenerator.m
//  TrafficBot
//
//  Created by Adam Ko on 22/01/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import "TBSummaryGenerator.h"
#import "AKBytesFormatter.h"


@interface TBSummaryGenerator ()

- (void)_updateSummaryString;
- (NSString *)_monitoringString;
- (NSString *)_notificationString;

@end


@implementation TBSummaryGenerator

- (id)init
{
	self = [super init];
	if (!self) return nil;
	
	_monitoring = 0;
	_monitoringMode = tms_unreachable_mode;
	_rollingPeriodFactor = 0;
	_rollingPeriodMultiplier = 0;
	_fixedPeriodInterval = 0;
	_shouldNotify = NO;
	_criticalPercentage = 100;
	
	return self;
}


#pragma mark -
#pragma mark private

- (void)_updateSummaryString
{	
	if (!self.monitoring)
	{
		self.summaryString = NSLocalizedString(@"TrafficBot is not monitoring.", @"not monitoring");;
		return;
	}
	
	NSString *paddingString = @"    ";
	
	NSString *string = [paddingString stringByAppendingString:[self _monitoringString]];
	
	if (self.shouldNotify)
	{
		string = [string stringByAppendingFormat:@"\n%@", paddingString];
		string = [string stringByAppendingString:[self _notificationString]];
	}
	
	self.summaryString = string;
}


- (NSString *)_monitoringString
{
	// monitoring specific detail
	switch (self.monitoringMode)
	{
		case tms_rolling_mode:
		{
			NSString *unitString = nil;
			if (self.rollingPeriodMultiplier == 3600)
			{
				if (self.rollingPeriodFactor <= 1) unitString = NSLocalizedString(@"hour", @"hour");
				else unitString = NSLocalizedString(@"hours", @"hours");
			}
			else if (self.rollingPeriodMultiplier == 86400)
			{
				if (self.rollingPeriodFactor <= 1) unitString = NSLocalizedString(@"day", @"day");
				else unitString = NSLocalizedString(@"days", @"days");
			}
			
			float decimalDiff = roundf(self.rollingPeriodFactor) - self.rollingPeriodFactor;
			NSString *timeString = nil;
			if (-0.05f <= decimalDiff && decimalDiff <= 0.05f)
				timeString = [NSString stringWithFormat:@"%.0f %@", self.rollingPeriodFactor, unitString];
			else
				timeString = [NSString stringWithFormat:@"%.1f %@", self.rollingPeriodFactor, unitString];
			
			return [NSString stringWithFormat:
								NSLocalizedString(@"I'm monitoring your total usage from\n"
												  @"the last %@ to now.", @"rolling"), timeString];
		}
		case tms_fixed_mode:
		{
			NSString *unitString = nil;
			switch (self.fixedPeriodInterval)
			{
				case 3600:		unitString = NSLocalizedString(@"next hour", @"next hour");		break;
				case 86400:		unitString = NSLocalizedString(@"tomorrow", @"tomorrow");		break;
				case 2592000:	unitString = NSLocalizedString(@"next month", @"next month");	break;
				default:		unitString = @"next Mars calendar year"; break;
			}
			return [NSString stringWithFormat:
								NSLocalizedString(@"I'm monitoring your total usage\n"
												  @"until %@.", @"fixed"), unitString];
		}
		case tms_indefinite_mode:
			return NSLocalizedString(@"I'm monitoring indefinitely\n"
												 @"until manual reset.", @"indefinite");
			
		default:
			return @"Oops. Something went wrong.";		
	}	
}

- (NSString *)_notificationString
{
	NSString *limitString = [AKBytesFormatter convertBytesWithNumber:self.limit floatingDecimalsWithLength:4];
	return [NSString stringWithFormat:
			NSLocalizedString(@"I will inform you when usage exceeds\n"
							  @"%.0f%% of your %@ limit.", @"notification"),
			self.criticalPercentage, limitString];
}


#pragma mark -
#pragma mark property accessor
- (void)setValue:(id)value forKey:(NSString *)key
{
	[super setValue:value forKey:key];
	[self _updateSummaryString];
}

#pragma mark -
#pragma mark boilerplate

@synthesize monitoring=_monitoring, monitoringMode=_monitoringMode;
@synthesize rollingPeriodFactor=_rollingPeriodFactor, rollingPeriodMultiplier=_rollingPeriodMultiplier, fixedPeriodInterval=_fixedPeriodInterval;
@synthesize shouldNotify=_shouldNotify, criticalPercentage=_criticalPercentage, limit=_limit;
@synthesize summaryString=_summaryString;

@end
