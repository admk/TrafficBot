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
- (BOOL)_workerWriteToRollingLogFile:(NSDictionary *)log;
- (BOOL)_workerWriteToFixedLogFile:(NSDictionary *)log;
- (NSMutableDictionary *)_dictionaryWithFile:(NSString *)filePath;
- (NSString *)_logsPath;

- (void)_setInterfaces:(NSArray *)interfaces;

@end

#pragma mark -
@implementation AKTrafficMonitorService

static AKTrafficMonitorService *sharedService = nil;

+ (AKTrafficMonitorService *)sharedService {
	if (!sharedService) {
		@synchronized(self) {
			sharedService = [[self alloc] init];
		}
	}
	return sharedService;
}
- (id)init {
	self = [super init];
	if (!self) return nil;
	
    _dispatch_group = dispatch_group_create();

	_lastRec = TMSZeroRec;
	_stashedRec = TMSZeroRec;
	_nowRec = TMSZeroRec;
	_prevNowRec = TMSZeroRec;
	_totalRec = TMSZeroRec;
	_speedRec = TMSZeroRec;
	
	_lastTotal = 0;
	_thresholds = nil;

	_rollingPeriodInterval = 0;
	_fixedPeriodRestartDate = nil;
	_monitoring = NO;
	_monitoringMode = tms_unreachable_mode;

    _interfaces = [[self networkInterfaceNames] retain];
	
    return self;
}
- (void)dealloc {
	[_fixedPeriodRestartDate release], _fixedPeriodRestartDate = nil;
	[_monitorTimer release], _monitorTimer = nil;
    [_includeInterfaces release], _includeInterfaces = nil;
    [_interfaces release], _interfaces = nil;
    dispatch_group_wait(_dispatch_group, DISPATCH_TIME_FOREVER);
    dispatch_release(_dispatch_group);
	[super dealloc];
}

#pragma mark -
#pragma mark file management
- (NSMutableDictionary *)rollingLogFile {
	return [self _dictionaryWithFile:[self _rollingLogFilePath]];
}
- (NSMutableDictionary *)fixedLogFile {
	return [self _dictionaryWithFile:[self _fixedLogFilePath]];
}
- (void)clearStatistics {

    dispatch_group_wait(_dispatch_group, DISPATCH_TIME_FOREVER);

    @synchronized(self)
    {
        _totalRec = TMSZeroRec;
        
        // delete all log files
        NSInteger tag;
        [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceDestroyOperation source:[[self _logsPath] stringByDeletingLastPathComponent] destination:@"" files:[NSArray arrayWithObject:[[self _logsPath] lastPathComponent]] tag:&tag];
        ZAssert(!tag, @"NSWorkspaceRecycleOperation failed with tag %ld", tag);
    }

	// notify
	[self _postNotificationName:AKTrafficMonitorStatisticsDidUpdateNotification object:nil userInfo:nil];
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
    dispatch_group_async
        (_dispatch_group, dispatch_get_main_queue(),
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

    @synchronized(self) {

	// empty checking
	ZAssert(self.monitoringMode != tms_rolling_mode || self.rollingPeriodInterval, @"must specify time interval for rolling period monitoring.");
	ZAssert(self.monitoringMode == tms_rolling_mode || !IsEmpty(self.fixedPeriodRestartDate), @"must specify fresh start date for fixed period monitoring.");
	
	// initialise readings
	NSDictionary *initReading = [self _workerReadDataUsage];
	_lastRec.kin = TMSDTFromNumber([initReading objectForKey:@"in"]);
	_lastRec.kout = TMSDTFromNumber([initReading objectForKey:@"out"]);
	_prevNowRec = _nowRec = _lastRec;
	
	// initialise results
	_totalRec = TMSZeroRec;
	
	switch (self.monitoringMode) {

		case tms_rolling_mode: {
			NSMutableDictionary *tLog = [self rollingLogFile];
			for (NSString *dateString in [tLog allKeys]) {
				AKScopeAutoreleased();
                NSDate *date = [NSDate ak_cachedDateWithString:dateString];
				// remove expired entries
				if ([date timeIntervalSinceNow] < -self.rollingPeriodInterval)
                {
					[tLog removeObjectForKey:dateString];
                    [NSDate ak_removeCachedDateString:dateString];
                }
				else {
					_totalRec.kin += TMSDTFromNumber([[tLog objectForKey:dateString] objectForKey:@"in"]);
					_totalRec.kout += TMSDTFromNumber([[tLog objectForKey:dateString] objectForKey:@"out"]);
				}
			}
			[self _workerWriteToRollingLogFile:tLog];
		} break;

		case tms_fixed_mode: {
			NSMutableDictionary *tLog = [self fixedLogFile];
			if ([self.fixedPeriodRestartDate timeIntervalSinceNow] > 0) {
				NSString *dateString = [[tLog allKeys] objectAtIndex:0];
				NSDictionary *entry = [tLog objectForKey:dateString];
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
			NSMutableDictionary *tLog = [self fixedLogFile];
			NSString *dateString = [[tLog allKeys] objectAtIndex:0];
			NSDictionary *entry = [tLog objectForKey:dateString];
			_totalRec.kin = TMSDTFromNumber([entry objectForKey:@"in"]);
			_totalRec.kout = TMSDTFromNumber([entry objectForKey:@"out"]);			
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
	[_monitorTimer fire];
	[_logTimer fire];

    }
}
- (void)_stopMonitoring {

    dispatch_group_wait(_dispatch_group, DISPATCH_TIME_FOREVER);

    @synchronized(self) {
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
#if DEBUG
	return 2;
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
    DLog(@"reinitialised.");
}

#pragma mark -
#pragma mark traffic data
- (void)_dispatchUpdateTraffic:(id)info {
    dispatch_group_async
        (_dispatch_group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
         ^(void) {
             [self _workerUpdateTraffic];
         });
}
- (void)_workerUpdateTraffic {
    @synchronized(self) {

        _prevNowRec = _nowRec;
        NSDictionary *reading = [self _workerReadDataUsage];
        _nowRec.kin = TMSDTFromNumber([reading objectForKey:@"in"]);
        _nowRec.kout = TMSDTFromNumber([reading objectForKey:@"out"]);
        
        _speedRec.kin = (_nowRec.kin - _prevNowRec.kin) / TMS_MONITOR_INTERVAL;
        _speedRec.kout = (_nowRec.kout - _prevNowRec.kout) / TMS_MONITOR_INTERVAL;
        
        _stashedRec.kin = _nowRec.kin - _lastRec.kin;
        _stashedRec.kout = _nowRec.kout - _lastRec.kout;
        
        // should not notify if no change
        if (TMSRecIsZero(_stashedRec)) return;
        
        [self _postNotificationName:AKTrafficMonitorStatisticsDidUpdateNotification
                             object:nil
                           userInfo:nil];
    }
}
- (void)_dispatchLogTrafficData:(id)info {
    dispatch_group_async
        (_dispatch_group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
         ^(void) {
             [self _workerLogTrafficData];
         });
}
- (void)_workerLogTrafficData {

    @synchronized(self) {
        
        // accumulate the differences
        _totalRec.kin += _stashedRec.kin;
        _totalRec.kout += _stashedRec.kout;
        
        // rolling log
        NSMutableDictionary *rollingLog = [self rollingLogFile];
        // log current entry for rolling log
        if (!TMSRecIsZero(_stashedRec)) {
            NSDictionary *rollingEntry = [NSDictionary dictionaryWithObjectsAndKeys:
                                          NumberFromTMSDT(_stashedRec.kin), @"in", 
                                          NumberFromTMSDT(_stashedRec.kout), @"out", nil];
            [rollingLog setObject:rollingEntry forKey:[[NSDate date] description]];
        }
        // rolling elimination
        for (NSString *dateString in [rollingLog allKeys]) {
            AKScopeAutoreleased();
            NSDate *date = [NSDate ak_cachedDateWithString:dateString];
            if ([date timeIntervalSinceNow] < -self.rollingPeriodInterval) {
                // rolling total needs to minus expired entries
                if (self.monitoringMode == tms_rolling_mode) {
                    _totalRec.kin -= TMSDTFromNumber([[rollingLog objectForKey:dateString] objectForKey:@"in"]);
                    _totalRec.kout -= TMSDTFromNumber([[rollingLog objectForKey:dateString] objectForKey:@"out"]);
                }
                // remove deprecated log entry
                [rollingLog removeObjectForKey:dateString];
                [NSDate ak_removeCachedDateString:dateString];
            }
        }
        [self _workerWriteToRollingLogFile:rollingLog];
        
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
                    NSDictionary *tLog = [NSDictionary dictionaryWithObject:entry forKey:[[NSDate date] description]];
                    [self _workerWriteToFixedLogFile:tLog];
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
                NSDictionary *tLog = [NSDictionary dictionaryWithObject:entry forKey:[[NSDate date] description]];
                [self _workerWriteToFixedLogFile:tLog];
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

- (NSDictionary *)_workerReadDataUsage {

    // reinitialise if interfaces changed
    NSArray *interfaces = [self networkInterfaceNames];
    if (![self.interfaces isEqualToArray:interfaces])
    {
		[self _setInterfaces:interfaces];
        [self _reinitialiseIfMonitoring];
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
- (BOOL)_workerWriteToRollingLogFile:(NSDictionary *)tLog {

    BOOL success = NO;
    @synchronized(self) {
        // save log file
        success = [tLog writeToFile:[self _rollingLogFilePath] atomically:YES];
    }

    ZAssert(success, @"failed to write log");
    return success;
}
- (BOOL)_workerWriteToFixedLogFile:(NSDictionary *)tLog {

    BOOL success = NO;
    ZAssert([[tLog allKeys] count] == 1, @"log file must have exactly one entry for a fixed period monitoring");

    @synchronized(self) {
        // save log file
        success = [tLog writeToFile:[self _fixedLogFilePath] atomically:YES];
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
	[_interfaces release];
	_interfaces = [interfaces retain];
}

#pragma mark -
#pragma mark boilerplate
#pragma mark property synthesize
@synthesize monitoring = _monitoring;
@synthesize includeInterfaces = _includeInterfaces, monitoringMode = _monitoringMode;
@synthesize thresholds = _thresholds;
@synthesize rollingPeriodInterval = _rollingPeriodInterval;
@synthesize fixedPeriodRestartDate = _fixedPeriodRestartDate;
@synthesize interfaces = _interfaces;

@end
