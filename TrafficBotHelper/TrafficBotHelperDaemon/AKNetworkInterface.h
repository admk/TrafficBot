//
//  AKNetworkInterface.h
//  TrafficBotHelper
//
//  Created by Xitong Gao on 9/18/11.
//  Copyright 2011 AK.Kloca. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <pcap.h>

@interface AKNetworkInterface : NSObject
{
    BOOL _lookedNetAndMask;

    NSString *_name;

    NSMutableArray *_addresses;
    
    in_addr_t _net;
    in_addr_t _mask;
    
    NSString *_netString;
    NSString *_maskString;
}

// you don't create AKNetworkInterface!
// AKPcap can create an NSArray of AKNetworkInterface instances for you
- (id)initWithPcapDevice:(pcap_if_t *)dev;
+ (AKNetworkInterface *)interfaceWithPcapDevice:(pcap_if_t *)dev;

- (BOOL)isConnected;

- (NSString *)name;
- (NSArray *)addresses;

- (in_addr_t)net;
- (in_addr_t)mask;

- (NSString *)netString;
- (NSString *)maskString;
- (NSUInteger)hash;
- (BOOL)isEqual:(id)object;

- (NSString *)description;

@end
