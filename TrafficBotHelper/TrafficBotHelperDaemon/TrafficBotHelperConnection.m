//
//  TrafficBotHelperConnection.cpp
//  TrafficBotHelper
//
//  Created by Xitong Gao on 21/09/2011.
//  Copyright 2011 AK.Kloca. All rights reserved.
//

#import "TrafficBotHelperConnection.h"
#import <Foundation/Foundation.h>
#import <pthread.h>

static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

NSDistantObject<TrafficBotHelperServer> *tbhVendServer(id<TrafficBotHelperClient> client,
                                                       SEL serverDidDieNotificationSelector,
                                                       NSArray *monitoredInterfaceNames)
{
    pthread_mutex_lock(&mutex);

    NSDistantObject<TrafficBotHelperServer> *server;
    NS_DURING
    {
        DLog(@"starting connection to server");
        // set up connection with AKSMS
        server = (NSDistantObject<TrafficBotHelperServer> *)
            [NSConnection rootProxyForConnectionWithRegisteredName:@"com.akkloca.TrafficBotHelper" host:nil];

        [[NSNotificationCenter defaultCenter] addObserver:client
                                                 selector:serverDidDieNotificationSelector
                                                     name:NSConnectionDidDieNotification
                                                   object:[server connectionForProxy]];
        [server setProtocolForProxy:@protocol(TrafficBotHelperServer)];
        [server setMonitoredInterfacesByNames:monitoredInterfaceNames];
        [server registerClient:client];
        [server start];
    }
    NS_HANDLER
    {
        server = nil;
    }
    NS_ENDHANDLER

    pthread_mutex_unlock(&mutex);
    
#ifdef DEBUG
    if (!server)
    {
        AKPollingIntervalOptimize(10) DLog(@"server not found");
    }
#endif

    return server;
}

void tbhDisconnectFromServer(NSDistantObject<TrafficBotHelperServer> *server, id<TrafficBotHelperClient> client)
{
    NS_DURING
    {
        DLog(@"disconnecting from server");
        [server stop];
        [server unregisterClient:client];
    }
    NS_HANDLER
    {
        DLog(@"failed to disconnect");
    }
    NS_ENDHANDLER
}

BOOL tbhServerIsOK()
{
    BOOL ok = YES;
    NSDistantObject<TrafficBotHelperServer> *server;
    NS_DURING
    {
        server = (NSDistantObject<TrafficBotHelperServer> *)
            [NSConnection rootProxyForConnectionWithRegisteredName:@"com.akkloca.TrafficBotHelper" host:nil];
        ok = nil != server;
        ok &= ![server isBroken];
    }
    NS_HANDLER
    {
        ok = NO;
    }
    NS_ENDHANDLER
    return ok;
}

BOOL tbhIsAlive(id receiver)
{
    if (!receiver) return NO;

    NS_DURING
    {
        [receiver ping];
    }
    NS_HANDLER
    {
        return NO;
    }
    NS_ENDHANDLER

    return YES;
}
