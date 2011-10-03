//
//  AKTrafficMonitorService.m
//  TrafficBot
//
//  Created by Adam Ko on 27/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import "AKTrafficMonitorService.h"
#import "NSDate+AKCachedDateString.h"
#include <sys/sysctl.h>
#include <netinet/in.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <net/route.h>

#define ALL_NOTIFICATIONS	[NSArray arrayWithObjects: \
							 AKTrafficMonitorNeedsNewFixedPeriodRestartDateNotification, \
							 AKTrafficMonitorStatisticsDidUpdateNotification, \
							 AKTrafficMonitorLogsDidUpdateNotification, \
							 AKTrafficMonitorThresholdDidExceedNotification, nil]

@interface AKTrafficMonitorService ()

- (void)_postNotificationName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo;

- (void)_startMonitoring;
- (void)_stopMonitoring;

- (NSTimeInterval)_timerInterval;
- (void)_reinitialiseIfMonitoring;

- (void)_dispatchUpdateTraffic:(id)info;
- (void)_workerUpdateTraffic;
- (void)_dispatchLogTrafficData:(id)info;
- (void)_workerLogTrafficData;
- (NSDictionary *)_workerReadDataUsage;

- (NSString *)_rollingLogFilePath;
- (NSString *)_fixedLogFilePath;
- (void)_workerScheduleWriteRollingLogToFile;
- (void)_workerScheduleWriteFixedLogToFile;
- (BOOL)_workerWriteRollingLogToFile;
- (BOOL)_workerWriteFixedLogToFile;
- (NSMutableDictionary *)_dictionaryWithFile:(NSString *)filePath;
- (NSString *)_logsPath;

- (void)_setInterfaces:(NSArray *)interfaces;

- (void)_serverDidDie:(NSNotification *)notification;

@end

#pragma mark -
@implementation AKTrafficMonitorService

+ (AKTrafficMonitorService *)sharedService {
	static dispatch_once_t pred;
	static AKTrafficMonitorService *sharedService = nil;
	dispatch_once(&pred, ^{
		sharedService = [[AKTrafficMonitorService alloc] init];
	});
	return sharedService;
}
- (id)init {
	self = [super init];
	if (!self) return nil;
	
	_dispatch_queue = dispatch_queue_create("com.akkloca.TrafficBot.TMS.Monitor", NULL);
    _dispatch_group = dispatch_group_create();

	_lastRec = TMSZeroRec;
	_stashedRec = TMSZeroRec;
	_nowRec = TMSZeroRec;
	_prevNowRec = TMSZeroRec;
	_totalRec = TMSZeroRec;
	_speedRec = TMSZeroRec;
	
    _rollingLog = [[self _dictionaryWithFile:[self _rollingLogFilePath]] retain];
    _fixedLog = [[self _dictionaryWithFile:[self _fixedLogFilePath]] retain];
    _lastRollingLogWriteDate = nil;
    _lastFixedLogWriteDate = nil;

	_lastTotal = 0;
	_thresholds = nil;

    _monitorTimer = nil;
    _logTimer = nil;

    _server = nil;

	_rollingPeriodInterval = 0;
	_fixedPeriodRestartDate = nil;
	_monitoring = NO;
	_monitoringMode = tms_unreachable_mode;

    _interfaces = [[self networkInterfaceNames] retain];
	
    return self;
}
- (void)dealloc {
    [_rollingLog release], _rollingLog = nil;
    [_fixedLog release], _fixedLog = nil;
    [_lastRollingLogWriteDate release], _lastRollingLogWriteDate = nil;
    [_lastFixedLogWriteDate release], _lastFixedLogWriteDate = nil;
	[_fixedPeriodRestartDate release], _fixedPeriodRestartDate = nil;
    [_thresholds release], _thresholds = nil;
	[_monitorTimer release], _monitorTimer = nil;
    [_includeInterfaces release], _includeInterfaces = nil;
    [_interfaces release], _interfaces = nil;
    dispatch_group_wait(_dispatch_group, DISPATCH_TIME_FOREVER);
    dispatch_release(_dispatch_group);
	dispatch_release(_dispatch_queue);
	[super dealloc];
}

#pragma mark -
#pragma mark file management
- (NSMutableDictionary *)rollingLog {
    return _rollingLog;
}
- (NSMutableDictionary *)fixedLog {
    return _fixedLog;
}
- (void)clearStatistics {

    dispatch_async(dispatch_get_main_queue(), ^(void)
    {
        dispatch_group_wait(_dispatch_group, DISPATCH_TIME_FOREVER);
        
        @synchronized(self)
        {
            _totalRec = TMSZeroRec;
            
            [_rollingLog release];
            _rollingLog = [[NSMutableDictionary dictionary] retain];
            [_fixedLog release];
            _fixedLog = [[NSMutableDictionary dictionary] retain];
            
            // delete all log files
            NSInteger tag;
            [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceDestroyOperation source:[[self _logsPath] stringByDeletingLastPathComponent] destination:@"" files:[NSArray arrayWithObject:[[self _logsPath] lastPathComponent]] tag:&tag];
            ZAssert(!tag, @"NSWorkspaceRecycleOperation failed with tag %ld", tag);
        }
        
        // notify
        [self _postNotificationName:AKTrafficMonitorStatisticsDidUpdateNotification object:nil userInfo:nil];
    });
}

#pragma mark -
#pragma mark interfaces
- (NSArray *)networkInterfaceNames {
    NSMutableArray *names = [NSMutableArray array];

    int mib[] = {CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0};
	size_t len;
	if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0)
		fprintf(stderr, "sysctl: %s\n", strerror(errno));
	char *buf = (char *)malloc(len);
	if (sysctl(mib, 6, buf, &len, NULL, 0) < 0)
		fprintf(stderr, "sysctl: %s\n", strerror(errno));
	char *buf_end = buf + len;
	char *next = NULL;
    char name[32];
	for (next = buf; next < buf_end; ) {		
		struct if_msghdr *ifm = (struct if_msghdr *)next;
		next += ifm->ifm_msglen;
		if (ifm->ifm_type == RTM_IFINFO2) {
			struct if_msghdr2 *if2m = (struct if_msghdr2 *)ifm;
            struct sockaddr_dl *sdl = (struct sockaddr_dl *)(if2m + 1);
            strncpy(name, sdl->sdl_data, sdl->sdl_nlen);
            name[sdl->sdl_nlen] = 0;
            NSString *nameStr = [NSString stringWithCString:name encoding:NSASCIIStringEncoding];
            [names addObject:nameStr];
		}
	}
	free(buf);

    return names;
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
- (void)setMonitoring:(BOOL)inBool {
	_monitoring = inBool;
	if (_monitoring) [self _startMonitoring];
	else [self _stopMonitoring];
}
- (void)setIncludeInterfaces:(NSArray *)monitoredInterfaces {
    if (_includeInterfaces == monitoredInterfaces) return;
    [_includeInterfaces release];
    _includeInterfaces = [monitoredInterfaces retain];
    [self _reinitialiseIfMonitoring];
}
- (void)setMonitoringMode:(tms_mode_t)mode {
	if (_monitoringMode == mode) return;
	_monitoringMode = mode;
	[self _reinitialiseIfMonitoring];
}
- (void)setRollingPeriodInterval:(NSTimeInterval)interval {
	_rollingPeriodInterval = interval;
	[self _reinitialiseIfMonitoring];
}
- (void)setExcludingLocal:(BOOL)excludingLocal {
    _excludingLocal = excludingLocal;
    [self _reinitialiseIfMonitoring];
}

- (NSDistantObject<TrafficBotHelperServer> *)server
{
    return _server;
}
- (NSNumber *)totalIn {
	return NumberFromTMSDT(_totalRec.kin + _stashedRec.kin);
}
- (NSNumber *)totalOut {
	return NumberFromTMSDT(_totalRec.kout + _stashedRec.kout);
}
- (NSNumber *)total {
	return NumberFromTMSDT(TMSTotal(_totalRec) + TMSTotal(_stashedRec));
}
- (NSNumber *)inSpeed {
	return NumberFromTMSDT(_speedRec.kin);
}
- (NSNumber *)outSpeed {
	return NumberFromTMSDT(_speedRec.kout);
}
- (NSNumber *)totalSpeed {
	return NumberFromTMSDT(TMSTotal(_speedRec));
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
- (void)_postNotificationName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo
{
    if ([NSThread isMainThread])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:aName
                                                            object:anObject
                                                          userInfo:aUserInfo];
        return;
    }
    // async
    dispatch_async
        (dispatch_get_main_queue(),
         ^(void) {
             [[NSNotificationCenter defaultCenter] postNotificationName:aName
                                                                 object:anObject
                                                               userInfo:aUserInfo];
         });
}

#pragma mark -
#pragma mark private

#pragma mark -
#pragma mark monitoring
#if DEBUG
#define TMS_MONITOR_INTERVAL .2
#else
#define TMS_MONITOR_INTERVAL 1
#endif
- (void)_startMonitoring {

	ZAssert([NSThread isMainThread], @"must be called from main thread.");
	dispatch_group_wait(_dispatch_group, DISPATCH_TIME_FOREVER);
    @synchronized(self) {

	// empty checking
	ZAssert(self.monitoringMode != tms_rolling_mode || self.rollingPeriodInterval, @"must specify time interval for rolling period monitoring.");
	ZAssert(self.monitoringMode == tms_rolling_mode || !IsEmpty(self.fixedPeriodRestartDate), @"must specify fresh start date for fixed period monitoring.");

    // set up connection with AKSMS
    if ([self isExcludingLocal])
        _server = tbhVendServer(self, @selector(_serverDidDie:), [self includeInterfaces]);

	// initialise readings
	NSDictionary *initReading = [self _workerReadDataUsage];
	_lastRec.kin = TMSDTFromNumber([initReading objectForKey:@"in"]);
	_lastRec.kout = TMSDTFromNumber([initReading objectForKey:@"out"]);
	_prevNowRec = _nowRec = _lastRec;
	
	// initialise results
	_totalRec = TMSZeroRec;
	
	switch (self.monitoringMode) {

		case tms_rolling_mode: {
			for (NSString *dateString in [_rollingLog allKeys]) {
				AKScopeAutoreleased();
                NSDate *date = [NSDate ak_cachedDateWithString:dateString];
				// remove expired entries
				if ([date timeIntervalSinceNow] < -self.rollingPeriodInterval)
                {
					[_rollingLog removeObjectForKey:dateString];
                    [NSDate ak_removeCachedDateString:dateString];
                }
				else {
					_totalRec.kin += TMSDTFromNumber([[_rollingLog objectForKey:dateString] objectForKey:@"in"]);
					_totalRec.kout += TMSDTFromNumber([[_rollingLog objectForKey:dateString] objectForKey:@"out"]);
				}
			}
			[self _workerScheduleWriteRollingLogToFile];
		} break;

		case tms_fixed_mode: {
			if ([self.fixedPeriodRestartDate timeIntervalSinceNow] > 0) {
				NSString *dateString = [[_fixedLog allKeys] objectAtIndex:0];
				NSDictionary *entry = [_fixedLog objectForKey:dateString];
				_totalRec.kin = TMSDTFromNumber([entry objectForKey:@"in"]);
				_totalRec.kout = TMSDTFromNumber([entry objectForKey:@"out"]);
			}
			else {
				DLog(@"fixed period monitor date expired.");
				_totalRec = TMSZeroRec;
				[self _postNotificationName:AKTrafficMonitorNeedsNewFixedPeriodRestartDateNotification object:nil userInfo:nil];
			}
		} break;
			
		case tms_indefinite_mode: {
            NSArray *dateKeys = [_fixedLog allKeys];
            if ([dateKeys count])
            {
                NSDictionary *entry = [_fixedLog objectForKey:[dateKeys objectAtIndex:0]];
                _totalRec.kin = TMSDTFromNumber([entry objectForKey:@"in"]);
                _totalRec.kout = TMSDTFromNumber([entry objectForKey:@"out"]);
            }
		} break;

		default: ALog(@"unrecognised mode"); break;
	}
	
	[self _postNotificationName:AKTrafficMonitorStatisticsDidUpdateNotification object:nil userInfo:nil];
	
	// threshold update
	_lastTotal = _totalRec.kin + _totalRec.kout;
	
	// timer
	if (!_monitorTimer)
		_monitorTimer = [NSTimer scheduledTimerWithTimeInterval:TMS_MONITOR_INTERVAL target:self selector:@selector(_dispatchUpdateTraffic:) userInfo:nil repeats:YES];
	if (!_logTimer)
		_logTimer = [NSTimer scheduledTimerWithTimeInterval:[self _timerInterval] target:self selector:@selector(_dispatchLogTrafficData:) userInfo:nil repeats:YES];
    }
	[_monitorTimer fire];
	[_logTimer fire];
}
- (void)_stopMonitoring {
	ZAssert([NSThread isMainThread], @"must be called from main thread.");
    dispatch_group_wait(_dispatch_group, DISPATCH_TIME_FOREVER);
    @synchronized(self) {
        tbhDisconnectFromServer(_server, self), _server = nil;
        [_logTimer invalidate], _logTimer = nil;
        [_monitorTimer invalidate], _monitorTimer = nil;
    }
}

#pragma mark -
#pragma mark constants
#define TMS_MAX_NO_OF_LOG_ENTRIES 2880
#define TMS_SHORTEST_UPDATE_INTERVAL 10
- (NSTimeInterval)_timerInterval {
    // logging timer interval should never be < 1 sec
	if (self.monitoringMode == tms_rolling_mode) {
		NSTimeInterval proposedInterval = self.rollingPeriodInterval/TMS_MAX_NO_OF_LOG_ENTRIES;
		if (proposedInterval > TMS_SHORTEST_UPDATE_INTERVAL) return proposedInterval;
		else return TMS_SHORTEST_UPDATE_INTERVAL;
	}
	else
		return TMS_SHORTEST_UPDATE_INTERVAL;
}

#pragma mark -
#pragma mark settings changed
- (void)_reinitialiseIfMonitoring {
	if (!_monitoring) return;
	dispatch_async
		(dispatch_get_main_queue(), ^{
			[self _stopMonitoring];
			[self _startMonitoring];
			DLog(@"reinitialised.");
		});
}

#pragma mark -
#pragma mark traffic data
- (void)_dispatchUpdateTraffic:(id)info {
	ZAssert([NSThread isMainThread], @"must be called from main thread.");
	dispatch_group_wait(_dispatch_group, DISPATCH_TIME_FOREVER);
    dispatch_group_async
        (_dispatch_group, _dispatch_queue,
         ^(void) {
             [self _workerUpdateTraffic];
         });
}
#define kSpeedLowPassFiltering 0.8f
- (void)_workerUpdateTraffic {
    @synchronized(self) {

        NSDictionary *reading = [self _workerReadDataUsage];
        if (!reading) return;
        _nowRec.kin = TMSDTFromNumber([reading objectForKey:@"in"]);
        _nowRec.kout = TMSDTFromNumber([reading objectForKey:@"out"]);
        
        _stashedRec.kin = _nowRec.kin - _lastRec.kin;
        _stashedRec.kout = _nowRec.kout - _lastRec.kout;
        
        // speed
        _nlpfSpeedRec.kin = (_nowRec.kin - _prevNowRec.kin) / TMS_MONITOR_INTERVAL;
        _nlpfSpeedRec.kout = (_nowRec.kout - _prevNowRec.kout) / TMS_MONITOR_INTERVAL;
        _prevNowRec = _nowRec;
        _speedRec.kin = _speedRec.kin * kSpeedLowPassFiltering + _nlpfSpeedRec.kin * (1 - kSpeedLowPassFiltering);
        _speedRec.kout = _speedRec.kout * kSpeedLowPassFiltering + _nlpfSpeedRec.kout * (1 - kSpeedLowPassFiltering);

        // should not notify if no change
        if (TMSRecIsZero(_stashedRec)) return;
        
        [self _postNotificationName:AKTrafficMonitorStatisticsDidUpdateNotification
                             object:nil
                           userInfo:nil];
    }
}
- (void)_dispatchLogTrafficData:(id)info {
	ZAssert([NSThread isMainThread], @"must be called from main thread.");
	dispatch_group_wait(_dispatch_group, DISPATCH_TIME_FOREVER);
    dispatch_group_async
        (_dispatch_group, _dispatch_queue,
         ^(void) {
             [self _workerLogTrafficData];
         });
}
#define k12Hours (12 * 60 * 60)
- (void)_workerLogTrafficData {

	// reinitialise if interfaces changed
    NSArray *interfaces = [self networkInterfaceNames];
    if (![self.interfaces isEqualToArray:interfaces])
    {
		[self _setInterfaces:interfaces];
        [self _reinitialiseIfMonitoring];
    }

    // pending addition
    if (_stashedRec.kin < 0 || _stashedRec.kout < 0) return;

    @synchronized(self) {
        
        // accumulate the differences
        _totalRec.kin += _stashedRec.kin;
        _totalRec.kout += _stashedRec.kout;
        
        // rolling log
        // log current entry for rolling log
        if (!TMSRecIsZero(_stashedRec)) {
            NSDictionary *rollingEntry = [NSDictionary dictionaryWithObjectsAndKeys:
                                          NumberFromTMSDT(_stashedRec.kin), @"in", 
                                          NumberFromTMSDT(_stashedRec.kout), @"out", nil];
            [_rollingLog setObject:rollingEntry forKey:[[NSDate date] description]];
        }
        // rolling elimination
        NSTimeInterval interval = (self.monitoringMode == tms_rolling_mode) ? self.rollingPeriodInterval : k12Hours;
        for (NSString *dateString in [_rollingLog allKeys]) {
            AKScopeAutoreleased();
            NSDate *date = [NSDate ak_cachedDateWithString:dateString];
            if ([date timeIntervalSinceNow] < -interval) {
                // rolling total needs to minus expired entries
                if (self.monitoringMode == tms_rolling_mode) {
                    _totalRec.kin -= TMSDTFromNumber([[_rollingLog objectForKey:dateString] objectForKey:@"in"]);
                    _totalRec.kout -= TMSDTFromNumber([[_rollingLog objectForKey:dateString] objectForKey:@"out"]);
                }
                // remove deprecated log entry
                [_rollingLog removeObjectForKey:dateString];
                [NSDate ak_removeCachedDateString:dateString];
            }
        }
        [self _workerScheduleWriteRollingLogToFile];
        
        switch (self.monitoringMode) {
                
            case tms_rolling_mode: {
                // should not log if no change
                if (TMSRecIsZero(_stashedRec)) return;
            } break;
                
            case tms_fixed_mode: {
                if ([self.fixedPeriodRestartDate timeIntervalSinceNow] > 0) {
                    // log only total
                    NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:
                                           NumberFromTMSDT(_totalRec.kin), @"in", 
                                           NumberFromTMSDT(_totalRec.kout), @"out", nil];
                    [_fixedLog release];
                    _fixedLog = [[NSMutableDictionary dictionaryWithObject:entry forKey:[[NSDate date] description]] retain];
                    [self _workerScheduleWriteFixedLogToFile];
                }
                else {
                    [self clearStatistics];
                    DLog(@"fixed period monitor date expired.");
                    [self _postNotificationName:AKTrafficMonitorNeedsNewFixedPeriodRestartDateNotification object:nil userInfo:nil];
                    return;
                }			
            } break;
                
            case tms_indefinite_mode: {
                // log only total
                NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:
                                       NumberFromTMSDT(_totalRec.kin), @"in", 
                                       NumberFromTMSDT(_totalRec.kout), @"out", nil];
                [_fixedLog release];
                _fixedLog = [[NSMutableDictionary dictionaryWithObject:entry forKey:[[NSDate date] description]] retain];
                [self _workerScheduleWriteFixedLogToFile];
            } break;
                
            default: ALog(@"unrecognised mode"); break;
        }
        
        // no negative total values
        ZAssert(_totalRec.kin >= 0 && _totalRec.kout >= 0, @"_totalRec values should be greater than zero.");
        if (_totalRec.kin < 0) _totalRec.kin = 0;
        if (_totalRec.kout < 0) _totalRec.kout = 0;
        
        _stashedRec = TMSZeroRec; // reset differences
        _lastRec = _nowRec; // updates last readings
        
        // notify
        [self _postNotificationName:AKTrafficMonitorLogsDidUpdateNotification object:nil userInfo:nil];
        
        // thresholds
        if (self.thresholds) {
            TMS_D_T cTotal = TMSTotal(_totalRec);
            for (NSString *thresholdKey in [self.thresholds allKeys]) {
                NSNumber *tNumber = [self.thresholds objectForKey:thresholdKey];
                TMS_D_T threshold = TMSDTFromNumber(tNumber);
                if (_lastTotal <= threshold && threshold <= cTotal) {
                    NSDictionary *infoDict = [NSDictionary dictionaryWithObject:tNumber forKey:thresholdKey];
                    [self _postNotificationName:AKTrafficMonitorThresholdDidExceedNotification object:nil userInfo:infoDict];
                }
            }
            _lastTotal = cTotal;
        }
    } // @synchronized(self)
}

#ifdef DEBUG
#define AKTMSServerConnectionRetryInterval 10.0
#else
#define AKTMSServerConnectionRetryInterval 60.0
#endif
- (NSDictionary *)_workerReadDataUsage {

    if ([self isExcludingLocal])
    {
        AKPollingIntervalOptimize(AKTMSServerConnectionRetryInterval)
        {
            if (!tbhIsAlive(_server))
            {
                _server = tbhVendServer(self, @selector(_serverDidDie:), [self includeInterfaces]);
                [self _reinitialiseIfMonitoring];
            }
        }
        NSDictionary *internet;
        NS_DURING
        {
            internet = [_server statistics];
        }
        NS_HANDLER
        {
            internet = nil;
            _server = nil;
        }
        NS_ENDHANDLER
        return [NSDictionary dictionaryWithDictionary:internet];
    }

    BOOL shouldIncludeAll = (nil == self.includeInterfaces);

	int mib[] = {CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0};
	size_t len;
	if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0)
		fprintf(stderr, "sysctl: %s\n", strerror(errno));
	char *buf = (char *)malloc(len);
	if (sysctl(mib, 6, buf, &len, NULL, 0) < 0)
		fprintf(stderr, "sysctl: %s\n", strerror(errno));
	char *buf_end = buf + len;
	char *next = NULL;
    char name[32];
	TMS_D_T totalibytes = 0;
	TMS_D_T totalobytes = 0;
	for (next = buf; next < buf_end; ) {		
		struct if_msghdr *ifm = (struct if_msghdr *)next;
		next += ifm->ifm_msglen;
		if (ifm->ifm_type == RTM_IFINFO2) {
			struct if_msghdr2 *if2m = (struct if_msghdr2 *)ifm;
            struct sockaddr_dl *sdl = (struct sockaddr_dl *)(if2m + 1);
            strncpy(name, sdl->sdl_data, sdl->sdl_nlen);
            name[sdl->sdl_nlen] = 0;
            if (!shouldIncludeAll) {
                BOOL hasInterface = [self.includeInterfaces containsObject:
                                     [NSString stringWithCString:name
                                                        encoding:NSASCIIStringEncoding]];
                if (!hasInterface) {
                    continue;
                }
            }
			totalibytes += if2m->ifm_data.ifi_ibytes;
			totalobytes += if2m->ifm_data.ifi_obytes;
		}
	}
	free(buf);
	return [NSDictionary dictionaryWithObjectsAndKeys:
			NumberFromTMSDT(totalibytes), @"in", 
			NumberFromTMSDT(totalobytes), @"out", nil];
}

#pragma mark -
#pragma mark file management
#if DEBUG
#define TMS_SHORTEST_CONSECUTIVE_WRITE_INTERVAL 3
#else
#define TMS_SHORTEST_CONSECUTIVE_WRITE_INTERVAL 60
#endif
- (void)_workerScheduleWriteRollingLogToFile
{
    if (!_lastRollingLogWriteDate)
    {
        @synchronized(self)
        {
            _lastRollingLogWriteDate = [[NSDate distantPast] retain];
        }
    }
    if ([_lastRollingLogWriteDate timeIntervalSinceNow] > -TMS_SHORTEST_CONSECUTIVE_WRITE_INTERVAL)
    {
        return;
    }

    @synchronized(self)
    {
        [self _workerWriteRollingLogToFile];

        [_lastRollingLogWriteDate release];
        _lastRollingLogWriteDate = [[NSDate date] retain];
    }
}
- (void)_workerScheduleWriteFixedLogToFile
{
    if (!_lastFixedLogWriteDate)
    {
        @synchronized(self)
        {
            _lastFixedLogWriteDate = [[NSDate distantPast] retain];
        }
    }
    if ([_lastFixedLogWriteDate timeIntervalSinceNow] > -TMS_SHORTEST_CONSECUTIVE_WRITE_INTERVAL)
    {
        return;
    }
    
    @synchronized(self)
    {
        [self _workerWriteFixedLogToFile];

        [_lastFixedLogWriteDate release];
        _lastFixedLogWriteDate = [[NSDate date] retain];
    }
}
- (BOOL)_workerWriteRollingLogToFile {

    BOOL success = NO;
    @synchronized(self) {
        // save log file
        success = [_rollingLog writeToFile:[self _rollingLogFilePath] atomically:YES];
    }

    ZAssert(success, @"failed to write log");
    return success;
}
- (BOOL)_workerWriteFixedLogToFile {

    BOOL success = NO;
    ZAssert([[_fixedLog allKeys] count] == 1, @"log file must have exactly one entry for a fixed period monitoring");

    @synchronized(self) {
        // save log file
        success = [_fixedLog writeToFile:[self _fixedLogFilePath] atomically:YES];
    }

    ZAssert(success, @"failed to write log");
	return success;
}

- (NSMutableDictionary *)_dictionaryWithFile:(NSString *)filePath {
	if ([[NSFileManager defaultManager] fileExistsAtPath:filePath])
		return [[[NSMutableDictionary alloc] initWithContentsOfFile:filePath] autorelease];
	
	NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:
						   NumberFromTMSDT(0), @"in", 
						   NumberFromTMSDT(0), @"out", nil];
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
#pragma mark server connections
- (void)_serverDidDie:(NSNotification *)notification
{
    _server = nil;
}
- (void)ping
{
    // still here!
}

#pragma mark -
#pragma mark property accessors
- (void)setValue:(id)value forKey:(NSString *)key {
	DLog(@"\"%@\" = %@", key, value);
	[super setValue:value forKey:key];
}

#pragma mark -
#pragma mark private setters
- (void)_setInterfaces:(NSArray *)interfaces
{
	if (_interfaces == interfaces) return;
	@synchronized(self)
	{
		[_interfaces release];
		_interfaces = [interfaces retain];
	}
}

#pragma mark -
#pragma mark boilerplate
#pragma mark property synthesize
@synthesize monitoring = _monitoring;
@synthesize includeInterfaces = _includeInterfaces, monitoringMode = _monitoringMode;
@synthesize excludingLocal = _excludingLocal;
@synthesize thresholds = _thresholds;
@synthesize rollingPeriodInterval = _rollingPeriodInterval;
@synthesize fixedPeriodRestartDate = _fixedPeriodRestartDate;
@synthesize interfaces = _interfaces;

@end
