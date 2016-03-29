//
//  TrafficBotHelper.h
//  TrafficBotHelper
//
//  Created by Xitong Gao on 21/09/2011.
//  Copyright 2011 AK.Kloca. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TrafficBotHelperConnection.h"

@class AKPcap;

@interface TrafficBotHelper : NSObject<NSConnectionDelegate, TrafficBotHelperServer>
{
    AKPcap *_pcap;
    NSConnection *_conn;
    __weak id<TrafficBotHelperClient> _client;
    NSArray *_monitoredInterfaceNames;
    int64_t _stashedIn;
    int64_t _stashedOut;

    NSDate *_lastRetrieveDate;
    BOOL _paused;
}

@end
