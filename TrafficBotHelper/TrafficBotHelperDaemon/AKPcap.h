//
//  AKPcap.h
//  TrafficBotHelper
//
//  Created by Xitong Gao on 18/09/2011.
//  Copyright 2011 AK.Kloca. All rights reserved.
//

#import <pcap.h>
#import <Foundation/Foundation.h>
#import "AKPcapHandles.h"

#define AKPcapStatisticsDidUpdateNotification @"AKPcapStatisticsDidUpdateNotification"
#define AKPcapInterfaceDidChangeNotification @"AKPcapInterfaceDidChangeNotification"

@class AKNetworkInterface;

@interface AKPcap : NSObject
{
    BOOL _looping;
    NSMutableArray *_openedInterfaces;
	AKPcapHandles *_handles;
}

+ (NSArray *)interfaces;
- (void)openInterfaces:(NSArray *)interfaces;
- (void)closeInterfaces:(NSArray *)interfaces;
- (NSArray *)openedInterfaces;

- (void)addObserver:(NSObject *)observer selector:(SEL)inSelector;
- (void)removeObserver:(NSObject *)observer;

- (void)setInternetFilterForAllInterfaces;
- (void)loop;

@end
