//
//  AKTrafficMonitorService.h
//  TrafficBot
//
//  Created by Adam Ko on 27/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define AKTrafficMonitorNeedsNewFixedPeriodRestartDateNotification @"AKTrafficMonitorNeedsNewFixedPeriodRestartDateNotification"
#define AKTrafficMonitorStatisticsDidUpdateNotification @"AKTrafficMonitorStatisticsDidUpdateNotification"

#define TMS_ULL_T				u_int64_t
#define NumberFromULL(ull)		( (NSNumber *)[NSNumber numberWithUnsignedLongLong:((TMS_ULL_T)(ull))] )
#define ULLFromNumber(number)	( (TMS_ULL_T)[((NSNumber *)(number)) unsignedLongLongValue] )

typedef enum {
	tms_rolling_mode = 0,
	tms_fixed_mode = 1,
	tms_indefinite_mode = 2,
	tms_unreachable_mode = -1
} tms_mode_t;

@interface AKTrafficMonitorService : NSObject {
	
@private

	BOOL			_monitoring;
	
	tms_mode_t		_monitoringMode;
	NSTimeInterval	_rollingPeriodInterval;
	NSDate			*_fixedPeriodRestartDate;

	TMS_ULL_T		_totalIn;
	TMS_ULL_T		_totalOut;
	TMS_ULL_T		_lastIn;
	TMS_ULL_T		_lastOut;
	
	NSTimer			*_monitorTimer;
}

// toggle monitoring by setting it
@property (assign, getter=isMonitoring) BOOL monitoring;

// modes:
// 1: a rolling period - traffic in the last x hours/days
// 2: a fixed period - or monitor one fixed period, say, until midnight tomorrow?
// 3: an indefinite period
@property (assign) tms_mode_t monitoringMode;

// time interval for rolling period
// log total from now-rollingPeriodInterval to now
@property (assign) NSTimeInterval rollingPeriodInterval;

// start date for fixed period
// log cumulative total until fresh start
@property (nonatomic, retain) NSDate *fixedPeriodRestartDate;

// stats
@property (readonly) NSNumber *totalIn;
@property (readonly) NSNumber *totalOut;

+ (AKTrafficMonitorService *)sharedService;

- (void)addObserver:(id)inObserver selector:(SEL)inSelector;
- (void)removeObserver:(id)inObserver;

- (NSMutableDictionary *)rollingLogFile;
- (NSMutableDictionary *)fixedLogFile;

- (void)clearStatistics;

@end
