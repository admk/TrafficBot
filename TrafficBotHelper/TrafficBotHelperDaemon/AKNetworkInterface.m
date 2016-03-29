//
//  AKNetworkInterface.m
//  TrafficBotHelper
//
//  Created by Xitong Gao on 9/18/11.
//  Copyright 2011 AK.Kloca. All rights reserved.
//

#import <arpa/inet.h>
#import "AKNetworkInterface.h"


#pragma mark - NSString private


@interface NSString (AKNetworkInterface)
+ (NSString *)ak_stringWithSockAddr:(struct sockaddr *)sa;
+ (NSString *)ak_stringWithAddress:(in_addr_t)address;
@end
@implementation NSString (AKNetworkInterface)
+ (NSString *)ak_stringWithSockAddr:(struct sockaddr *)sa
{
    char s[INET_ADDRSTRLEN];
    char s6[INET6_ADDRSTRLEN];

    switch(sa->sa_family)
    {
        case AF_INET:
            inet_ntop(AF_INET, &(((struct sockaddr_in *)sa)->sin_addr), s, INET_ADDRSTRLEN);
            return [NSString stringWithCString:s encoding:NSASCIIStringEncoding];

        case AF_INET6:
            inet_ntop(AF_INET6, &(((struct sockaddr_in6 *)sa)->sin6_addr), s6, INET6_ADDRSTRLEN);
            return [NSString stringWithCString:s6 encoding:NSASCIIStringEncoding];
    }
    return nil;
}
+ (NSString *)ak_stringWithAddress:(in_addr_t)address
{
    struct in_addr addr;
    addr.s_addr = address;
    const char *str = inet_ntoa(addr);
    return [NSString stringWithCString:str encoding:NSASCIIStringEncoding];
}
@end


#pragma mark -

@interface AKNetworkInterface ()
- (void)_lookIfNecessary;
@end

@implementation AKNetworkInterface

#pragma mark - init & dealloc

- (id)init
{
    ZAssert(0, @"cannot initialise an empty AKNetworkInterface instance.");
    return nil;
}

- (id)initWithPcapDevice:(pcap_if_t *)dev
{
    self = [super init];
    if (!self) return nil;
    
    _lookedNetAndMask = NO;
    _name = [[NSString stringWithCString:dev->name encoding:NSASCIIStringEncoding] retain];
    _addresses = [[NSMutableArray alloc] init];
    for (pcap_addr_t *addr = dev->addresses; addr; addr = addr->next)
    {
        NSString *addressString = [NSString ak_stringWithSockAddr:addr->addr];
        if (!addressString) continue;
        [_addresses addObject:addressString];
    }
    
    return self;
}

+ (AKNetworkInterface *)interfaceWithPcapDevice:(pcap_if_t *)dev
{
    return [[[self alloc] initWithPcapDevice:dev] autorelease];
}

- (void)dealloc
{
    [_addresses release], _addresses = nil;
    [_name release], _name = nil;
    [_netString release], _netString = nil;
    [_maskString release], _maskString = nil;
    [super dealloc];
}

#pragma mark - is connected
- (BOOL)isConnected
{
    return [self net] && [self mask] && !IsEmpty([self addresses]);
}

#pragma mark - getters and setters
- (NSString *)name
{
    return _name;
}
- (NSArray *)addresses
{
    return _addresses;
}
- (in_addr_t)net
{
    [self _lookIfNecessary];
    return _net;
}
- (in_addr_t)mask
{
    [self _lookIfNecessary];
    return _mask;
}
- (NSString *)netString
{
    if (_netString) return _netString;
    [self _lookIfNecessary];
    _netString = [[NSString ak_stringWithAddress:_net] retain];
    return _netString;
}
- (NSString *)maskString
{
    if (_maskString) return _maskString;
    [self _lookIfNecessary];
    _maskString = [[NSString ak_stringWithAddress:_mask] retain];
    return _maskString;
}

#pragma mark - hash & equality
- (NSUInteger)hash
{
    return [self net] ^ [self mask] ^ [[self name] hash] ^ [[self addresses] hash];
}
- (BOOL)isEqual:(id)object
{
    if (![[self name] isEqualToString:[object valueForKey:@"name"]]) return NO;
    if (![[self netString] isEqualToString:[object valueForKey:@"netString"]]) return NO;
    if (![[self maskString] isEqualToString:[object valueForKey:@"maskString"]]) return NO;
    return YES;
}

#pragma mark - description
- (NSString *)description
{
    return [NSString stringWithFormat:@"name: %@, net: %@, mask %@, addr: %@",
            [self name], [self netString], [self maskString], [self addresses]];
}

#pragma mark - private methods
- (void)_lookIfNecessary
{
    if (_lookedNetAndMask) return;
    @synchronized(self)
    {
        char errbuf[PCAP_ERRBUF_SIZE];
        const char *dev = [_name cStringUsingEncoding:NSASCIIStringEncoding];
        if (pcap_lookupnet(dev, &_net, &_mask, errbuf) == -1)
        {
            NSString *err = [NSString stringWithCString:errbuf encoding:NSASCIIStringEncoding];
            if ([err rangeOfString:@"no IPv4 address assigned"].length == 0)
            {
                DLog(@"pcap_lookupnet: %s", errbuf);
            }
            _net = 0;
            _mask = 0;
        }
        _lookedNetAndMask = YES;
    }
}

@end
