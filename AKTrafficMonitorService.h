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

#define TMS_ULL_T				int64_t
#define NumberFromULL(ull)		( (NSNumber *)[NSNumber numberWithLongLong:((TMS_ULL_T)(ull))] )
#define ULLFromNumber(number)	( (TMS_ULL_T)[((NSNumber *)(number)) longLongValue] )

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
	NSMutableDictionary	*_thresholds;
	
	NSTimer			*_monitorTimer;
	NSTimer			*_logTimer;
	
	TMS_ULL_T		_lastIn;
	TMS_ULL_T		_lastOut;
	TMS_ULL_T		_diffIn;
	TMS_ULL_T		_diffOut;
	TMS_ULL_T		_nowIn;
	TMS_ULL_T		_nowOut;
	TMS_ULL_T		_totalIn;
	TMS_ULL_T		_totalOut;
	TMS_ULL_T		_lastTotal;
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

// thresholds
// objects - {
//		(NSString *) a context for the notification
//			-> (NSNumber *) a threshold value
// if the threshold value is exceeded it will post a AKTrafficMonitorThresholdDidExceedNotification
@property (nonatomic, retain) NSMutableDictionary *thresholds;

// stats
@property (readonly) NSNumber *totalIn;
@property (readonly) NSNumber *totalOut;
@property (readonly) NSNumber *total;

+ (AKTrafficMonitorService *)sharedService;

// notifications
- (void)addObserver:(id)inObserver selector:(SEL)inSelector;
- (void)removeObserver:(id)inObserver;

// thresholds
- (void)registerThresholdWithValue:(NSNumber *)value context:(NSString *)context;
- (void)unregisterAllThresholds;

// dictionary representation of log files
- (NSMutableDictionary *)rollingLogFile;
- (NSMutableDictionary *)fixedLogFile;

- (void)clearStatistics;

@end
