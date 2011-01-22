//
//  AKTrafficMonitorService.m
//  TrafficBot
//
//  Created by Adam Ko on 27/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import "AKTrafficMonitorService.h"
#include <sys/sysctl.h>
#include <netinet/in.h>
#include <net/if.h>
#include <net/route.h>

#define ALL_NOTIFICATIONS	[NSArray arrayWithObjects: \
							 AKTrafficMonitorNeedsNewFixedPeriodRestartDateNotification, \
							 AKTrafficMonitorStatisticsDidUpdateNotification, \
							 AKTrafficMonitorThresholdDidExceedNotification, nil]

@interface AKTrafficMonitorService ()

- (void)_startMonitoring;
- (void)_stopMonitoring;

- (NSTimeInterval)_timerInterval;
- (void)_reinitialiseIfMonitoring;

- (void)_updateTraffic:(id)info;
- (void)_logTrafficData:(id)info;
- (NSDictionary *)_readDataUsage;

- (NSString *)_rollingLogFilePath;
- (NSString *)_fixedLogFilePath;
- (BOOL)_writeToRollingLogFile:(NSDictionary *)log;
- (BOOL)_writeToFixedLogFile:(NSDictionary *)log;
- (NSMutableDictionary *)_dictionaryWithFile:(NSString *)filePath;
- (NSString *)_logsPath;

@end

#pragma mark -
@implementation AKTrafficMonitorService

static AKTrafficMonitorService *sharedService = nil;

+ (AKTrafficMonitorService *)sharedService {
	if (sharedService == nil) {
		@synchronized(self) {
			sharedService = [[self alloc] init];
		}
	}
	return sharedService;
}
- (id)init {
	self = [super init];
	if (!self) return nil;
	
	_lastIn = 0;
	_lastOut = 0;
	_diffIn = 0;
	_diffOut = 0;
	_nowIn = 0;
	_nowOut = 0;
	_totalIn = 0;
	_totalOut = 0;
	_lastTotal = 0;
	_rollingPeriodInterval = 0;
	_fixedPeriodRestartDate = nil;
	_monitoring = NO;
	_monitoringMode = tms_unreachable_mode;
	_thresholds = nil;
	
    return self;
}
- (void)dealloc {
	[_fixedPeriodRestartDate release], _fixedPeriodRestartDate = nil;
	[_monitorTimer release], _monitorTimer = nil;
	[super dealloc];
}

#pragma mark -
- (NSMutableDictionary *)rollingLogFile {
	return [self _dictionaryWithFile:[self _rollingLogFilePath]];
}
- (NSMutableDictionary *)fixedLogFile {
	return [self _dictionaryWithFile:[self _fixedLogFilePath]];
}
- (void)clearStatistics {
	_totalIn = 0;
	_totalOut = 0;
	// reset all log files
	NSInteger tag;
	[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceDestroyOperation source:[[self _logsPath] stringByDeletingLastPathComponent] destination:@"" files:[NSArray arrayWithObject:[[self _logsPath] lastPathComponent]] tag:&tag];
	ZAssert(!tag, @"NSWorkspaceRecycleOperation failed with tag %ld", tag);
	// notify
	[[NSNotificationCenter defaultCenter] postNotificationName:AKTrafficMonitorStatisticsDidUpdateNotification object:nil userInfo:nil];
}

#pragma mark -
#pragma mark thresholds
- (void)registerThresholdWithValue:(NSNumber *)value context:(NSString *)context {
	if (!self.thresholds)
		self.thresholds = [NSMutableDictionary dictionary];
	[self.thresholds setObject:value forKey:context];
}
- (void)unregisterAllThresholds {
	self.thresholds = nil;
}

#pragma mark -
#pragma mark setters & getters
- (BOOL)isMonitoring {
	return _monitoring;
}
- (void)setMonitoring:(BOOL)inBool {
	_monitoring = inBool;
	if (_monitoring) [self _startMonitoring];
	else [self _stopMonitoring];
}
- (tms_mode_t)monitoringMode {
	return _monitoringMode;
}
- (void)setMonitoringMode:(tms_mode_t)mode {
	if (_monitoringMode == mode) return;
	_monitoringMode = mode;
	[self _reinitialiseIfMonitoring];
}
- (NSTimeInterval)rollingPeriodInterval {
	return _rollingPeriodInterval;
}
- (void)setRollingPeriodInterval:(NSTimeInterval)interval {
	_rollingPeriodInterval = interval;
	[self _reinitialiseIfMonitoring];
}
- (void)setFixedPeriodRestartDate:(NSDate *)date {
	if ([_fixedPeriodRestartDate isEqualToDate:date]) return;
	[_fixedPeriodRestartDate release];
	_fixedPeriodRestartDate = [date retain];
}
- (NSNumber *)totalIn {
	return NumberFromULL(_totalIn + _diffIn);
}
- (NSNumber *)totalOut {
	return NumberFromULL(_totalOut + _diffOut);
}
- (NSNumber *)total {
	return NumberFromULL(_totalIn + _totalOut + _diffIn + _diffOut);
}

#pragma mark -
#pragma mark notification
- (void)addObserver:(id)inObserver selector:(SEL)inSelector {
	for (NSString *notificationName in ALL_NOTIFICATIONS)
		[[NSNotificationCenter defaultCenter] addObserver:inObserver selector:inSelector name:notificationName object:nil];
}
- (void)removeObserver:(id)inObserver {
	for (NSString *notificationName in ALL_NOTIFICATIONS)
		[[NSNotificationCenter defaultCenter] removeObserver:inObserver name:notificationName object:nil];
}

#pragma mark -
#pragma mark private

#pragma mark -
#pragma mark monitoring
- (void)_startMonitoring {

	// empty checking
	ZAssert(self.monitoringMode != tms_rolling_mode || self.rollingPeriodInterval, @"must specify time interval for rolling period monitoring.");
	ZAssert(self.monitoringMode == tms_rolling_mode || !IsEmpty(self.fixedPeriodRestartDate), @"must specify fresh start date for fixed period monitoring.");
	
	// initialise readings
	NSDictionary *initReading = [self _readDataUsage];
	_lastIn = ULLFromNumber([initReading objectForKey:@"in"]);
	_lastOut = ULLFromNumber([initReading objectForKey:@"out"]);
	
	// initialise results
	_totalIn = 0;
	_totalOut = 0;
	
	switch (self.monitoringMode) {
			
		case tms_rolling_mode: {
			NSMutableDictionary *tLog = [self rollingLogFile];
			for (NSString *dateString in [tLog allKeys]) {
				AKScopeAutoreleased();
				NSDate *date = [NSDate dateWithString:dateString];
				// remove expired entries
				if ([date timeIntervalSinceNow] < -self.rollingPeriodInterval)
					[tLog removeObjectForKey:dateString];
				else {
					_totalIn += ULLFromNumber([[tLog objectForKey:dateString] objectForKey:@"in"]);
					_totalOut += ULLFromNumber([[tLog objectForKey:dateString] objectForKey:@"out"]);
				}
			}
			[self _writeToRollingLogFile:tLog];
		} break;
			
		case tms_fixed_mode: {
			NSMutableDictionary *tLog = [self fixedLogFile];
			if ([self.fixedPeriodRestartDate timeIntervalSinceNow] > 0) {
				NSString *dateString = [[tLog allKeys] objectAtIndex:0];
				NSDictionary *entry = [tLog objectForKey:dateString];
				_totalIn = ULLFromNumber([entry objectForKey:@"in"]);
				_totalOut = ULLFromNumber([entry objectForKey:@"out"]);
			}
			else {
				DLog(@"fixed period monitor date expired.");
				_totalIn = 0;
				_totalOut = 0;
				[[NSNotificationCenter defaultCenter] postNotificationName:AKTrafficMonitorNeedsNewFixedPeriodRestartDateNotification object:nil userInfo:nil];
			}
		} break;
			
		case tms_indefinite_mode: {
			NSMutableDictionary *tLog = [self fixedLogFile];
			NSString *dateString = [[tLog allKeys] objectAtIndex:0];
			NSDictionary *entry = [tLog objectForKey:dateString];
			_totalIn = ULLFromNumber([entry objectForKey:@"in"]);
			_totalOut = ULLFromNumber([entry objectForKey:@"out"]);			
		} break;

		default: ALog(@"unrecognised mode"); break;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AKTrafficMonitorStatisticsDidUpdateNotification object:nil userInfo:nil];
	
	// threshold update
	_lastTotal = _totalIn + _totalOut;
	
	// timer
	if (!_monitorTimer)
		_monitorTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(_updateTraffic:) userInfo:nil repeats:YES];
	if (!_logTimer)
		_logTimer = [NSTimer scheduledTimerWithTimeInterval:[self _timerInterval] target:self selector:@selector(_logTrafficData:) userInfo:nil repeats:YES];
	[_logTimer fire];
	[_monitorTimer fire];
}
- (void)_stopMonitoring {
	[_logTimer invalidate], _logTimer = nil;
	[_monitorTimer invalidate], _monitorTimer = nil;
}

#pragma mark -
#pragma mark constants
#define TMS_MAX_NO_OF_LOG_ENTRIES 1440
#define TMS_SHORTEST_UPDATE_INTERVAL 20
- (NSTimeInterval)_timerInterval {
#if DEBUG
	return 5;
#else
	if (self.monitoringMode == tms_rolling_mode) {
		NSTimeInterval proposedInterval = self.rollingPeriodInterval/TMS_MAX_NO_OF_LOG_ENTRIES;
		if (proposedInterval > TMS_SHORTEST_UPDATE_INTERVAL) return proposedInterval;
		else return TMS_SHORTEST_UPDATE_INTERVAL;
	}
	else
		return TMS_SHORTEST_UPDATE_INTERVAL;
#endif
}

#pragma mark -
#pragma mark settings changed
- (void)_reinitialiseIfMonitoring {
	if (!_monitoring) return;
	[self _stopMonitoring];
	[self _startMonitoring];
}

#pragma mark -
#pragma mark traffic data
- (void)_updateTraffic:(id)info {
	
	NSDictionary *reading = [self _readDataUsage];
	_nowIn = ULLFromNumber([reading objectForKey:@"in"]);
	_nowOut = ULLFromNumber([reading objectForKey:@"out"]);

	_diffIn = _nowIn - _lastIn;
	_diffOut = _nowOut - _lastOut;
	
	// should not notify if no change
	if (_diffIn == 0 && _diffOut == 0) return;
	
	// notify
	[[NSNotificationCenter defaultCenter] postNotificationName:AKTrafficMonitorStatisticsDidUpdateNotification object:nil userInfo:nil];
}
- (void)_logTrafficData:(id)info {
	
	// accumulate the differences
	_totalIn += _diffIn;
	_totalOut += _diffOut;
	
	// rolling log
	NSMutableDictionary *rollingLog = [self rollingLogFile];
	for (NSString *dateString in [rollingLog allKeys]) {
		AKScopeAutoreleased();
		NSDate *date = [NSDate dateWithString:dateString];
		if ([date timeIntervalSinceNow] < -self.rollingPeriodInterval) {
			// rolling total needs to minus expired entries
			if (self.monitoringMode == tms_rolling_mode) {
				_totalIn -= ULLFromNumber([[rollingLog objectForKey:dateString] objectForKey:@"in"]);
				_totalIn -= ULLFromNumber([[rollingLog objectForKey:dateString] objectForKey:@"out"]);
			}
			// remove deprecated log entry
			[rollingLog removeObjectForKey:dateString];
		}
	}
	
	switch (self.monitoringMode) {
			
		case tms_rolling_mode: {
			// should not log if no change
			if (_diffIn == 0 && _diffOut == 0) return;
			// log current entry for rolling log
			NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:
								   NumberFromULL(_diffIn), @"in", 
								   NumberFromULL(_diffOut), @"out", nil];
			[rollingLog setObject:entry forKey:[[NSDate date] description]];
			[self _writeToRollingLogFile:rollingLog];
		} break;
			
		case tms_fixed_mode: {
			if ([self.fixedPeriodRestartDate timeIntervalSinceNow] > 0) {
				// log only total
				NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:
									   NumberFromULL(_totalIn), @"in", 
									   NumberFromULL(_totalOut), @"out", nil];
				NSDictionary *tLog = [NSDictionary dictionaryWithObject:entry forKey:[[NSDate date] description]];
				[self _writeToFixedLogFile:tLog];
			}
			else {
				[self clearStatistics];
				DLog(@"fixed period monitor date expired.");
				[[NSNotificationCenter defaultCenter] postNotificationName:AKTrafficMonitorNeedsNewFixedPeriodRestartDateNotification object:nil userInfo:nil];
				return;
			}			
		} break;
			
		case tms_indefinite_mode: {
			// log only total
			NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:
								   NumberFromULL(_totalIn), @"in", 
								   NumberFromULL(_totalOut), @"out", nil];
			NSDictionary *tLog = [NSDictionary dictionaryWithObject:entry forKey:[[NSDate date] description]];
			[self _writeToFixedLogFile:tLog];
		} break;

		default: ALog(@"unrecognised mode"); break;
	}
	
	
	// no negative total values
	if (_totalIn < 0) _totalIn = 0;
	if (_totalOut < 0) _totalOut = 0;
	
	// notify
	[[NSNotificationCenter defaultCenter] postNotificationName:AKTrafficMonitorStatisticsDidUpdateNotification object:nil userInfo:nil];
	
	// thresholds
	if (self.thresholds) {
		TMS_ULL_T cTotal = _totalIn + _totalOut;
		for (NSString *thresholdKey in [self.thresholds allKeys]) {
			NSNumber *tNumber = [self.thresholds objectForKey:thresholdKey];
			TMS_ULL_T threshold = ULLFromNumber(tNumber);
			if (_lastTotal <= threshold && threshold <= cTotal) {
				NSDictionary *infoDict = [NSDictionary dictionaryWithObject:tNumber forKey:thresholdKey];
				[[NSNotificationCenter defaultCenter] postNotificationName:AKTrafficMonitorThresholdDidExceedNotification object:nil userInfo:infoDict];
			}
		}
		_lastTotal = cTotal;
	}
	
	// reset differences
	_diffIn = 0;
	_diffOut = 0;
	
	// updates last readings
	_lastIn = _nowIn;
	_lastOut = _nowOut;
}

- (NSDictionary *)_readDataUsage {
	int mib[] = {CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0};
	size_t len;
	if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0)
		fprintf(stderr, "sysctl: %s\n", strerror(errno));
	char *buf = (char *)malloc(len);
	if (sysctl(mib, 6, buf, &len, NULL, 0) < 0)
		fprintf(stderr, "sysctl: %s\n", strerror(errno));
	char *buf_end = buf + len;
	char *next = NULL;
	TMS_ULL_T totalibytes = 0;
	TMS_ULL_T totalobytes = 0;
	for (next = buf; next < buf_end; ) {		
		struct if_msghdr *ifm = (struct if_msghdr *)next;
		next += ifm->ifm_msglen;
		if (ifm->ifm_type == RTM_IFINFO2) {
			struct if_msghdr2 *if2m = (struct if_msghdr2 *)ifm;
			totalibytes += if2m->ifm_data.ifi_ibytes;
			totalobytes += if2m->ifm_data.ifi_obytes;
		}
	}
	free(buf);
	return [NSDictionary dictionaryWithObjectsAndKeys:
			NumberFromULL(totalibytes), @"in", 
			NumberFromULL(totalobytes), @"out", nil];
}

#pragma mark -
#pragma mark file management
- (BOOL)_writeToRollingLogFile:(NSDictionary *)tLog {
	// save log file
	BOOL success = [tLog writeToFile:[self _rollingLogFilePath] atomically:YES];
	ZAssert(success, @"failed to write log");
	return success;
}
- (BOOL)_writeToFixedLogFile:(NSDictionary *)tLog {
	ZAssert([[tLog allKeys] count] == 1, @"log file must have exactly one entry for a fixed period monitoring");
	// save log file
	BOOL success = [tLog writeToFile:[self _fixedLogFilePath] atomically:YES];
	ZAssert(success, @"failed to write log");
	return success;
}

- (NSMutableDictionary *)_dictionaryWithFile:(NSString *)filePath {
	if ([[NSFileManager defaultManager] fileExistsAtPath:filePath])
		return [[[NSMutableDictionary alloc] initWithContentsOfFile:filePath] autorelease];
	
	NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:
						   NumberFromULL(0), @"in", 
						   NumberFromULL(0), @"out", nil];
	return [NSMutableDictionary dictionaryWithObject:entry forKey:[[NSDate date] description]];
}
- (NSString *)_rollingLogFilePath {
	return [[self _logsPath] stringByAppendingPathComponent:@"TrafficBot (rolling period).plist"];
}
- (NSString *)_fixedLogFilePath {
	return [[self _logsPath] stringByAppendingPathComponent:@"TrafficBot (fixed period).plist"];	
}
- (NSString *)_logsPath {
	NSString *folder = [@"~/Library/Application Support/TrafficBot/Logs/" stringByExpandingTildeInPath];
	
	NSError *error = nil;
	if (![[NSFileManager defaultManager] fileExistsAtPath:folder])
		[[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:&error];
	ZAssert(!error, @"%@ an error occurred when creating directory at path \"%@\": %@", folder, error);
	
	return folder;
}
#pragma mark -
#pragma mark property accessors
- (void)setValue:(id)value forKey:(NSString *)key {
	DLog(@"\"%@\" = %@", key, value);
	[super setValue:value forKey:key];
}

#pragma mark -
#pragma mark boilerplate
#pragma mark property synthesize
@synthesize monitoring = _monitoring, monitoringMode = _monitoringMode;
@synthesize thresholds = _thresholds;
@synthesize rollingPeriodInterval = _rollingPeriodInterval;
@synthesize fixedPeriodRestartDate = _fixedPeriodRestartDate;

@end
