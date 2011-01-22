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

#define TMS_D_T		int64_t
#define NumberFromTMSDT(ull)	( (NSNumber *)[NSNumber numberWithLongLong:((TMS_D_T)(ull))] )
#define TMSDTFromNumber(number)	( (TMS_D_T)[((NSNumber *)(number)) longLongValue] )

#define TMSZeroRec				((tms_rec_t){0,0})
#define TMSTotal(rec)			((rec).kin + (rec).kout)
#define TMSRecIsZero(rec)		((rec).kin == 0 && (rec).kout == 0)

typedef enum {
	tms_rolling_mode = 0,
	tms_fixed_mode = 1,
	tms_indefinite_mode = 2,
	tms_unreachable_mode = -1
} tms_mode_t;

typedef struct {
	TMS_D_T kin;
	TMS_D_T kout;
} tms_rec_t;

@interface AKTrafficMonitorService : NSObject {
	
@private

	BOOL			_monitoring;
	
	tms_mode_t		_monitoringMode;
	NSTimeInterval	_rollingPeriodInterval;
	NSDate			*_fixedPeriodRestartDate;
	NSMutableDictionary	*_thresholds;
	
	NSTimer			*_monitorTimer;
	NSTimer			*_logTimer;
	
	tms_rec_t		_lastRec;
	tms_rec_t		_stashedRec;
	tms_rec_t		_nowRec;
	tms_rec_t		_totalRec;
	TMS_D_T			_lastTotal;
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
