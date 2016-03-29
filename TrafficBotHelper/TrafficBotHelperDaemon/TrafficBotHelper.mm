//
//  TrafficBotHelper.m
//  TrafficBotHelper
//
//  Created by Xitong Gao on 21/09/2011.
//  Copyright 2011 AK.Kloca. All rights reserved.
//

#import <libkern/OSAtomic.h>
#import "TrafficBotHelper.h"
#import "AKPcap.h"

@interface TrafficBotHelper ()
- (void)_startServer;
- (void)_didReceiveNotificationFromPcap:(NSNotification *)notification;
@end

@implementation TrafficBotHelper

#pragma mark - init & dealloc
- (id)init
{
    self = [super init];
    if (!self) return nil;

    _pcap = nil;
    _conn = nil;
    _monitoredInterfaceNames = nil;
    _stashedIn = _stashedOut = 0;

    _lastRetrieveDate = nil;
    _paused = YES;

    [self _startServer];
    return self;
}
- (void)dealloc
{
    [_pcap closeInterfaces:[_pcap openedInterfaces]];
    [_pcap release], _pcap = nil;
    [_conn release], _conn = nil;
    [_monitoredInterfaceNames release], _monitoredInterfaceNames = nil;
    [super dealloc];
}

#pragma mark - server protocol
- (BOOL)isBroken
{
    return getuid() != 0;
}
- (NSString *)version
{
    return TrafficBotHelperVersionNumber;
}
- (oneway void)registerClient:(byref id<TrafficBotHelperClient>)client
{
    _client = client;
}
- (oneway void)unregisterClient:(byref id<TrafficBotHelperClient>)client
{
    _client = nil;
}
- (void)start
{
    [_lastRetrieveDate release];
    _lastRetrieveDate = [[NSDate date] retain];
    _paused = NO;

    if (!_pcap)
    {
        _pcap = [[AKPcap alloc] init];
        NSArray *interfaces = [AKPcap interfaces];
        [_pcap openInterfaces:interfaces];
        [_pcap addObserver:self selector:@selector(_didReceiveNotificationFromPcap:)];
        [_pcap loop];
    }

    [_pcap setInternetFilterForAllInterfaces];
}
- (void)stop
{
    DLog(@"FIXME: not stopped, multiple readings on restart.");  // FIXME multiple readings
    return;

    _paused = YES;
    [_pcap closeInterfaces:[_pcap openedInterfaces]];
    [_pcap release], _pcap = nil;
}
- (oneway void)setMonitoredInterfacesByNames:(bycopy NSArray *)names
{
    DLog(@"%@", names);
    if ([_monitoredInterfaceNames isEqualToArray:names]) return;
    [_monitoredInterfaceNames release];
    _monitoredInterfaceNames = [[NSArray alloc] initWithArray:names];
}
- (NSDictionary *)statistics
{
    [_lastRetrieveDate release];
    _lastRetrieveDate = [[NSDate date] retain];

    if (_paused)
    {
        [self start];
        DLog(@"resumed updates");
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithLongLong:_stashedIn], @"in",
            [NSNumber numberWithLongLong:_stashedOut], @"out", nil];
}
- (void)ping
{
    // do nothing, just a synchronous call to make sure
    // the helper is still alive.
}
- (void)_startServer
{
    if (_conn) return;

    _conn = [NSConnection new];
    [_conn setRootObject:self];
    if (![_conn registerName:TrafficBotHelperServerName])
    {
        DLog(@"Failed to register server %@", TrafficBotHelperServerName);
    }
    [_conn setDelegate:self];
}

#pragma mark - pcap
#define AKSMS_STATISTICS_UPDATE_INTERVAL .5
#define AKTBH_PAUSE_UPDATE_INTERVAL 60
- (void)_didReceiveNotificationFromPcap:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:AKPcapStatisticsDidUpdateNotification])
    {
        NSDictionary *info = [notification userInfo];
        int64_t length = [[info objectForKey:@"length"] longLongValue];
        ZAssert(length > 0, @"length must be greater than zero");
        if (!length) return;

        if (_monitoredInterfaceNames &&
            ![_monitoredInterfaceNames containsObject:[info objectForKey:@"dev"]])
            return;

        NSString *type = [info objectForKey:@"type"];
        if ([type isEqualToString:@"in"])
            OSAtomicAdd64Barrier(length, &_stashedIn);
        else if ([type isEqualToString:@"out"])
            OSAtomicAdd64Barrier(length, &_stashedOut);
        else
            ZAssert(0, @"unrecognized type.");
    }

    if ([_lastRetrieveDate timeIntervalSinceNow] < -AKTBH_PAUSE_UPDATE_INTERVAL)
    {
        [self stop];
        DLog(@"paused updates");
    }
}

@end
