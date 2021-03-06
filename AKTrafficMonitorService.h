//
//  AKTrafficMonitorService.h
//  TrafficBot
//
//  Created by Adam Ko on 27/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TrafficBotHelperConnection.h"

#define AKTrafficMonitorNeedsNewFixedPeriodRestartDateNotification @"AKTrafficMonitorNeedsNewFixedPeriodRestartDateNotification"
#define AKTrafficMonitorStatisticsDidUpdateNotification @"AKTrafficMonitorStatisticsDidUpdateNotification"
#define AKTrafficMonitorLogsDidUpdateNotification @"AKTrafficMonitorLogsDidUpdateNotification"
#define AKTrafficMonitorThresholdDidExceedNotification @"AKTrafficMonitorThresholdDidExceedNotification"

#define TMS_D_T		int64_t
#define NumberFromTMSDT(ll)	( (NSNumber *)[NSNumber numberWithLongLong:((TMS_D_T)(ll))] )
#define TMSDTFromNumber(number)	( (TMS_D_T)[((NSNumber *)(number)) longLongValue] )

#define TMSZeroRec				((tms_rec_t){0,0})
#define TMSTotal(rec)			((rec).kin + (rec).kout)
#define TMSRecIsZero(rec)		((rec).kin == 0 && (rec).kout == 0)

typedef enum {
	tms_rolling_mode = 0,
	tms_fixed_mode = 1,
	tms_indefinite_mode = 2,
    tms_anniversary_mode = 3,
	tms_unreachable_mode = -1
} tms_mode_t;

typedef struct {
	TMS_D_T kin;
	TMS_D_T kout;
} tms_rec_t;

@interface AKTrafficMonitorService : NSObject<TrafficBotHelperClient>
{
@private

	dispatch_queue_t _dispatch_queue;
    dispatch_group_t _dispatch_group;
	BOOL			_monitoring;
	
    NSArray         *_includeInterfaces;
	tms_mode_t		_monitoringMode;
	NSTimeInterval	_rollingPeriodInterval;
	NSDate			*_fixedPeriodRestartDate;
	NSMutableDictionary	*_thresholds;
	
	__weak NSTimer	*_monitorTimer;
	__weak NSTimer	*_logTimer;
	
    BOOL            _excludingLocal;
    NSDistantObject<TrafficBotHelperServer> *_server;

	tms_rec_t		_lastRec;
	tms_rec_t		_stashedRec;
	tms_rec_t		_nowRec;
	tms_rec_t		_prevNowRec;
	tms_rec_t		_totalRec;
	tms_rec_t		_speedRec;
    tms_rec_t       _nlpfSpeedRec;
	TMS_D_T			_lastTotal;

    NSMutableDictionary *_rollingLog;
    NSMutableDictionary *_fixedLog;
    NSDate          *_lastRollingLogWriteDate;
    NSDate          *_lastFixedLogWriteDate;
	
    NSArray         *_interfaces;
}

// toggle monitoring by setting it
@property (assign, nonatomic, getter=isMonitoring) BOOL monitoring;

// monitoring interface
// nil monitors all interfaces
@property (copy, nonatomic) NSArray *includeInterfaces;

// network interfaces
@property (readonly, nonatomic) NSArray *interfaces;

// should it exclude local traffic
@property (assign, nonatomic, getter = isExcludingLocal) BOOL excludingLocal;

// modes:
// tms_rolling_mode:	a rolling period - traffic in the last x hours/days
// tms_fixed_mode:		a fixed period - or monitor one fixed period, say, until midnight tomorrow?
// tms_indefinite_mode: an indefinite period
@property (assign, nonatomic) tms_mode_t monitoringMode;

// time interval for rolling period
// log total from now-rollingPeriodInterval to now
@property (assign, nonatomic) NSTimeInterval rollingPeriodInterval;

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
@property (readonly) NSNumber *inSpeed;
@property (readonly) NSNumber *outSpeed;
@property (readonly) NSNumber *totalSpeed;

// dictionary representation of log files
@property (readonly) NSMutableDictionary *rollingLog;
@property (readonly) NSMutableDictionary *fixedLog;

+ (AKTrafficMonitorService *)sharedService;

// notifications
- (void)addObserver:(id)inObserver selector:(SEL)inSelector;
- (void)removeObserver:(id)inObserver;

// thresholds
- (void)registerThresholdWithValue:(NSNumber *)value context:(NSString *)context;
- (void)unregisterAllThresholds;

// all names of network interfaces
- (NSArray *)networkInterfaceNames;

// tbh server
- (NSDistantObject<TrafficBotHelperServer> *)server;

- (void)clearStatistics;

@end
