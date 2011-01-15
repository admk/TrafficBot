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
#define AKTrafficMonitorThresholdDidExceedNotification @"AKTrafficMonitorThresholdDidExceedNotification"

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

	NSTimer			*_monitorTimer;
}

// toggle monitoring by setting it
@property (assign, getter=isMonitoring) BOOL monitoring;

// modes:
// tms_rolling_mode:	a rolling period - traffic in the last x hours/days
// tms_fixed_mode:		a fixed period - or monitor one fixed period, say, until midnight tomorrow?
// tms_indefinite_mode: an indefinite period
@property (assign) tms_mode_t monitoringMode;

// time interval for rolling period
// log total from now-rollingPeriodInterval to now
@property (assign) NSTimeInterval rollingPeriodInterval;

// start date for fixed period
// log cumulative total until fresh start
@property (nonatomic, retain) NSDate *fixedPeriodRestartDate;

// threshold
// if exceeded it will post a AKTrafficMonitorThresholdDidExceedNotification notification
@property (nonatomic, retain) NSNumber *threshold;

// stats
@property (readonly) NSNumber *totalIn;
@property (readonly) NSNumber *totalOut;
@property (readonly) NSNumber *total;

+ (AKTrafficMonitorService *)sharedService;

// notifications
- (void)addObserver:(id)inObserver selector:(SEL)inSelector;
- (void)removeObserver:(id)inObserver;

// dictionary representation of log files
- (NSMutableDictionary *)rollingLogFile;
- (NSMutableDictionary *)fixedLogFile;

- (void)clearStatistics;

@end
