//
//  AKPcap.m
//  TrafficBotHelper
//
//  Created by Xitong Gao on 18/09/2011.
//  Copyright 2011 AK.Kloca. All rights reserved.
//

#import "AKPcap.h"
#import "AKNetworkInterface.h"

#define ALL_NOTIFICATIONS   [NSArray arrayWithObjects: \
                             AKPcapStatisticsDidUpdateNotification, \
                             AKPcapInterfaceDidChangeNotification, nil]

void _postNotification(NSString *aName, id anObject, NSDictionary *aUserInfo);
void _pcap_loop_callback(const u_char *user,
                         const struct pcap_pkthdr *header,
                         const u_char *packet);

@interface AKPcap ()

- (BOOL)_isInterfacesInfoUpToDate;
- (void)_reinitialiseIfInLoop;
- (NSString *)_internetFilterStringForInterface:(AKNetworkInterface *)interface inOrOut:(BOOL)inYesOutNo;

- (void)_setFilter:(NSString *)filter forInterface:(AKNetworkInterface *)interface inOrOut:(BOOL)inYesOutNo;

@end

void _postNotification(NSString *aName, id anObject, NSDictionary *aUserInfo)
{
    static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_lock(&mutex);
    [aName retain];
    [anObject retain];
    [aUserInfo retain];
    pthread_mutex_unlock(&mutex);

    dispatch_async
        (dispatch_get_main_queue(),
         ^(void) {
             [[NSNotificationCenter defaultCenter]
              postNotificationName:aName  object:anObject userInfo:aUserInfo];

             pthread_mutex_lock(&mutex);
             [aName release];
             [anObject release];
             [aUserInfo release];
             pthread_mutex_unlock(&mutex);
         });
}

#define AKPCAP_INTERFACES_INFO_UPDATE_INTERVAL 60
void _pcap_loop_callback(const u_char *user,
                         const struct pcap_pkthdr *header,
                         const u_char *packet)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSMutableDictionary *infoDict = [[(NSDictionary *)user mutableCopy] autorelease];
    [infoDict setValue:[NSNumber numberWithInt:header->len] forKey:@"length"];
    _postNotification(AKPcapStatisticsDidUpdateNotification, nil, infoDict);
    static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_lock(&mutex);
    AKPollingIntervalOptimize(AKPCAP_INTERFACES_INFO_UPDATE_INTERVAL)
    {
        AKPcap *pcap = [infoDict objectForKey:@"observer"];
        if (![pcap _isInterfacesInfoUpToDate])
        {
            DLog(@"reinitialising");
            [pcap _reinitialiseIfInLoop];
        }
    }
    pthread_mutex_unlock(&mutex);

    [pool release];
}

@implementation AKPcap

- (id)init
{
    self = [super init];
    if (!self) return nil;

    _looping = NO;
    _openedInterfaces = nil;
	_handles = new AKPcapHandles();

    return self;
}
- (void)dealloc
{
    delete _handles, _handles = NULL;
    [_openedInterfaces release], _openedInterfaces = nil;
    [super dealloc];
}

#pragma mark - interfaces
#define AKInterfacesPollingInterval 2
+ (NSArray *)interfaces
{
    NSArray *(^pollingBlock)(void) = ^ NSArray *
    {
        char errbuf[PCAP_ERRBUF_SIZE];
        pcap_if_t *devs;
        
        if (pcap_findalldevs(&devs, errbuf) == -1)
        {
            DLog(@"pcap_findalldevs: %s", errbuf);
        }
        if (!devs)
        {
            DLog(@"no devs, probably not running with root permission.");
        }
        
        NSMutableArray *array = [NSMutableArray array];
        for (pcap_if_t *dev = devs; dev; dev = dev->next)
        {
            AKNetworkInterface *interface = [AKNetworkInterface interfaceWithPcapDevice:dev];
            [array addObject:interface];
        }
        
        pcap_freealldevs(devs);
        
        return array;
    };

    static NSArray *devArray = nil;
    if (!devArray)
    {
        devArray = [pollingBlock() retain];
    }
    AKPollingIntervalOptimize(AKInterfacesPollingInterval)
    {
        [devArray release];
        devArray = [pollingBlock() retain];
    }
    return devArray;
}
- (void)openInterfaces:(NSArray *)interfaces
{
	for (AKNetworkInterface *dev in interfaces)
	{
        if ([_openedInterfaces containsObject:dev]) continue;
        if (![dev isConnected]) continue;

		BOOL succ = _handles->open(dev);

        if (!_openedInterfaces)
        {
            _openedInterfaces = [[NSMutableArray alloc] init];
        }
        if (succ)
        {
            [_openedInterfaces addObject:dev];
        }
	}
}
- (void)closeInterfaces:(NSArray *)interfaces
{
    for (id dev in interfaces)
	{
        if (![_openedInterfaces containsObject:dev]) continue;
        const char *name = [[dev name] cStringUsingEncoding:NSASCIIStringEncoding];
		_handles->close(name);
	}
    [_openedInterfaces removeObjectsInArray:interfaces];

    _looping &= [_openedInterfaces count] > 0;
}
- (NSArray *)openedInterfaces
{
    return _openedInterfaces;
}
- (BOOL)_isInterfacesInfoUpToDate
{
    static NSArray *prevInterfaces = nil;
    if (!prevInterfaces)
    {
        prevInterfaces = [[[self class] interfaces] retain];
        return YES;
    }
    NSArray *interfaces = [[self class] interfaces];

    BOOL upToDate = YES;
    if ([interfaces count] != [prevInterfaces count])
    {
        upToDate = NO;
    }
    else
    {
        for (AKNetworkInterface *interface in interfaces)
        {
            if (![prevInterfaces containsObject:interface])
            {
                upToDate = NO;
                break;
            }
        }
    }

    [prevInterfaces release];
    prevInterfaces = [interfaces retain];

    return upToDate;
}
- (void)_reinitialiseIfInLoop
{
    if (!_looping) return;
    dispatch_async
        (dispatch_get_main_queue(),
         ^{
             [self openInterfaces:[[self class] interfaces]];
             [self loop];
         });
}
- (void)_updateFilterIfInLoop
{
    if (!_looping) return;
    ZAssert(0, @"not implemented");
}

#pragma mark - notification
- (void)addObserver:(NSObject *)observer selector:(SEL)inSelector
{
    for (NSString *notificationName in ALL_NOTIFICATIONS)
		[[NSNotificationCenter defaultCenter] addObserver:observer
                                                 selector:inSelector
                                                     name:notificationName
                                                   object:nil];
}
- (void)removeObserver:(NSObject *)observer
{
    for (NSString *notificationName in ALL_NOTIFICATIONS)
		[[NSNotificationCenter defaultCenter] removeObserver:observer
                                                        name:notificationName
                                                      object:nil];
}
- (void)_postNotificationName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo
{
    _postNotification(aName, anObject, aUserInfo);
}

#pragma mark - main loops
- (void)loop
{
    if (_looping) return;
    _looping = YES;

    NSDictionary *infoDict = [NSDictionary dictionaryWithObject:self forKey:@"observer"];
	_handles->loop(_pcap_loop_callback, &infoDict);
}

#pragma mark - setters & getters


#pragma mark - private
- (NSString *)_internetFilterStringForInterface:(AKNetworkInterface *)interface inOrOut:(BOOL)inYesOutNo
{
    if (![interface net] || ![interface mask] || IsEmpty([interface addresses]))
    {
        return nil;
    }

    NSString *hostType = inYesOutNo ? @"dst" : @"src";
    NSString *host = nil;
    for (NSString *hostComponent in [interface addresses])
    {
        if (IsEmpty(hostComponent)) continue;
        if (!host)
        {
            host = [NSString stringWithFormat:@"(%@ host %@", hostType, hostComponent];
        }
        else
        {
            host = [host stringByAppendingFormat:@" or %@ host %@", hostType, hostComponent];
        }
    }
    host = [host stringByAppendingString:@")"];

    NSString *net = [interface netString];
    net = [net stringByReplacingOccurrencesOfString:@".0" withString:@""];

    NSString *filter = [NSString stringWithFormat:
                        @"ip and (not %@ net %@) and %@",
                        inYesOutNo ? @"src" : @"dst",
                        net, host];
    return filter;
}

#pragma mark - private local filter setters
- (void)setInternetFilterForAllInterfaces
{
    void (^setInternetFilterBlock)(AKNetworkInterface *, BOOL) = ^(AKNetworkInterface *interface, BOOL inYesOutNo)
    {
        NSString *filter = [self _internetFilterStringForInterface:interface inOrOut:inYesOutNo];
        [self _setFilter:filter forInterface:interface inOrOut:inYesOutNo];
    };

    NSArray *interfaces = [[self class] interfaces];
    for (AKNetworkInterface *interface in interfaces)
    {
        const char *name = [[interface name] cStringUsingEncoding:NSASCIIStringEncoding];
        std::vector<std::string> devs = _handles->devices();
        if (std::find(devs.begin(), devs.end(), DeviceInString(name)) != devs.end())
        {
            setInternetFilterBlock(interface, YES);
        }
        if (std::find(devs.begin(), devs.end(), DeviceOutString(name)) != devs.end())
        {
            setInternetFilterBlock(interface, NO);
        }
    }
}
- (void)_setFilter:(NSString *)filter forInterface:(AKNetworkInterface *)interface inOrOut:(BOOL)inYesOutNo
{
    if (nil == filter) return;

    const char *dev = [[interface name] cStringUsingEncoding:NSASCIIStringEncoding];
    const char *ftr = [filter cStringUsingEncoding:NSASCIIStringEncoding];
	_handles->setFilter(dev, inYesOutNo, ftr);
}

@end
