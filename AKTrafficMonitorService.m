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

@property (getter = _lastIn,	setter = _setLastIn:	)	TMS_ULL_T _lastIn;
@property (getter = _lastOut,	setter = _setLastOut:	)	TMS_ULL_T _lastOut;
@property (getter = _totalIn,	setter = _setTotalIn:	)	TMS_ULL_T _totalIn;
@property (getter = _totalOut,	setter = _setTotalOut:	)	TMS_ULL_T _totalOut;

- (void)_startMonitoring;
- (void)_stopMonitoring;

- (NSTimeInterval)_timerInterval;
- (void)_reinitialiseIfMonitoring;

- (void)_shouldLogAndUpdateTrafficData:(id)info;
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
	
	self._lastIn = 0;
	self._lastOut = 0;
	self._totalIn = 0;
	self._totalOut = 0;
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
	self._totalIn = 0;
	self._totalOut = 0;
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
	return NumberFromULL(self._totalIn);
}
- (NSNumber *)totalOut {
	return NumberFromULL(self._totalOut);
}
- (NSNumber *)total {
	return NumberFromULL(self._totalIn + self._totalOut);
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
#pragma mark boilerplate
#pragma mark property synthesize
@synthesize monitoring = _monitoring, monitoringMode = _monitoringMode;
@synthesize thresholds = _thresholds;
@synthesize rollingPeriodInterval = _rollingPeriodInterval;
@synthesize fixedPeriodRestartDate = _fixedPeriodRestartDate;
@synthesize _totalIn, _totalOut, _lastIn, _lastOut;

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
	self._lastIn = ULLFromNumber([initReading objectForKey:@"in"]);
	self._lastOut = ULLFromNumber([initReading objectForKey:@"out"]);
	
	// initialise results
	self._totalIn = 0;
	self._totalOut = 0;
	
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
					self._totalIn += ULLFromNumber([[tLog objectForKey:dateString] objectForKey:@"in"]);
					self._totalOut += ULLFromNumber([[tLog objectForKey:dateString] objectForKey:@"out"]);
				}
			}
			[self _writeToRollingLogFile:tLog];
		} break;
			
		case tms_fixed_mode: {
			NSMutableDictionary *tLog = [self fixedLogFile];
			if ([self.fixedPeriodRestartDate timeIntervalSinceNow] > 0) {
				NSString *dateString = [[tLog allKeys] objectAtIndex:0];
				NSDictionary *entry = [tLog objectForKey:dateString];
				self._totalIn = ULLFromNumber([entry objectForKey:@"in"]);
				self._totalOut = ULLFromNumber([entry objectForKey:@"out"]);
			}
			else {
				DLog(@"fixed period monitor date expired.");
				self._totalIn = 0;
				self._totalOut = 0;
				[[NSNotificationCenter defaultCenter] postNotificationName:AKTrafficMonitorNeedsNewFixedPeriodRestartDateNotification object:nil userInfo:nil];
			}
		} break;
			
		case tms_indefinite_mode: {
			NSMutableDictionary *tLog = [self fixedLogFile];
			NSString *dateString = [[tLog allKeys] objectAtIndex:0];
			NSDictionary *entry = [tLog objectForKey:dateString];
			self._totalIn = ULLFromNumber([entry objectForKey:@"in"]);
			self._totalOut = ULLFromNumber([entry objectForKey:@"out"]);			
		} break;

		default: ALog(@"unrecognised mode"); break;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AKTrafficMonitorStatisticsDidUpdateNotification object:nil userInfo:nil];
	
	// timer
	if (!_monitorTimer)
		_monitorTimer = [NSTimer scheduledTimerWithTimeInterval:[self _timerInterval] target:self selector:@selector(_shouldLogAndUpdateTrafficData:) userInfo:nil repeats:YES];
	[_monitorTimer fire];
}
- (void)_stopMonitoring {
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
- (void)_shouldLogAndUpdateTrafficData:(id)info {
	
	NSDictionary *reading = [self _readDataUsage];
	TMS_ULL_T nowIn = ULLFromNumber([reading objectForKey:@"in"]);
	TMS_ULL_T nowOut = ULLFromNumber([reading objectForKey:@"out"]);
	
	// calculate the differences
	TMS_ULL_T diffIn = nowIn - self._lastIn;
	TMS_ULL_T diffOut = nowOut - self._lastOut;
	
	// updates last readings
	self._lastIn = ULLFromNumber([reading objectForKey:@"in"]);
	self._lastOut = ULLFromNumber([reading objectForKey:@"out"]);
	
	// accumulate the differences
	self._totalIn += diffIn;
	self._totalOut += diffOut;
		
	// rolling log
	NSMutableDictionary *rollingLog = [self rollingLogFile];
	for (NSString *dateString in [rollingLog allKeys]) {
		AKScopeAutoreleased();
		NSDate *date = [NSDate dateWithString:dateString];
		if ([date timeIntervalSinceNow] < -self.rollingPeriodInterval) {
			// rolling total needs to minus expired entries
			if (self.monitoringMode == tms_rolling_mode) {
				self._totalIn -= ULLFromNumber([[rollingLog objectForKey:dateString] objectForKey:@"in"]);
				self._totalIn -= ULLFromNumber([[rollingLog objectForKey:dateString] objectForKey:@"out"]);
			}
			// remove deprecated log entry
			[rollingLog removeObjectForKey:dateString];
		}
	}
	
	switch (self.monitoringMode) {
			
		case tms_rolling_mode: {
			// should not log if no change
			if (diffIn == 0 && diffOut == 0) return;
			// log current entry for rolling log
			NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:
								   NumberFromULL(diffIn), @"in", 
								   NumberFromULL(diffOut), @"out", nil];
			[rollingLog setObject:entry forKey:[[NSDate date] description]];
			[self _writeToRollingLogFile:rollingLog];
		} break;
			
		case tms_fixed_mode: {
			if ([self.fixedPeriodRestartDate timeIntervalSinceNow] > 0) {
				// log only total
				NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:
									   NumberFromULL(self._totalIn), @"in", 
									   NumberFromULL(self._totalOut), @"out", nil];
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
								   NumberFromULL(self._totalIn), @"in", 
								   NumberFromULL(self._totalOut), @"out", nil];
			NSDictionary *tLog = [NSDictionary dictionaryWithObject:entry forKey:[[NSDate date] description]];
			[self _writeToFixedLogFile:tLog];
		} break;

		default: ALog(@"unrecognised mode"); break;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AKTrafficMonitorStatisticsDidUpdateNotification object:nil userInfo:nil];

	// thresholds
	if (self.thresholds) {
		NSNumber *cTotal = NumberFromULL(self._totalIn + self._totalOut);
		for (NSString *thresholdKey in [self.thresholds allKeys]) {
			NSNumber *cThreshold = [self.thresholds objectForKey:thresholdKey];
			if ([cTotal isGreaterThan:cThreshold]) {
				NSDictionary *infoDict = [NSDictionary dictionaryWithObject:cThreshold forKey:thresholdKey];
				[[NSNotificationCenter defaultCenter] postNotificationName:AKTrafficMonitorThresholdDidExceedNotification object:nil userInfo:infoDict];
				[self.thresholds removeObjectForKey:thresholdKey];
			}
		}
	}
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

@end
