//
//  TBSummaryGenerator.h
//  TrafficBot
//
//  Created by Adam Ko on 22/01/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AKTrafficMonitorService.h"


@interface TBSummaryGenerator : NSObject {

@private
	BOOL		_monitoring;
	tms_mode_t	_monitoringMode;
	float		_rollingPeriodFactor;
	int			_rollingPeriodMultiplier;
	int			_fixedPeriodInterval;
	BOOL		_shouldNotify;
	float		_criticalPercentage;
	NSNumber	*_limit;
	
	NSString	*_summaryString;
}

@property (assign) BOOL monitoring;
@property (assign) tms_mode_t monitoringMode;
@property (assign) float rollingPeriodFactor;
@property (assign) int rollingPeriodMultiplier;
@property (assign) int fixedPeriodInterval;
@property (assign) BOOL shouldNotify;
@property (assign) float criticalPercentage;
@property (retain, nonatomic) NSNumber *limit;

@property (retain, nonatomic) NSString *summaryString;

@end
