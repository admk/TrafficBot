//
//  AKTMSSMSProtocols.h
//  TrafficBot
//
//  Created by Xitong Gao on 21/09/2011.
//  Copyright 2011 AK.Kloca. All rights reserved.
//


#define TrafficBotHelperServerName @"com.akkloca.TrafficBotHelper"
#define TrafficBotHelperVersionNumber @"1.2.0"

@protocol TrafficBotHelperClient <NSObject>

- (void)ping;

@end


@protocol TrafficBotHelperServer <NSObject>

- (BOOL)isBroken;

- (oneway void)setMonitoredInterfacesByNames:(bycopy NSArray *)names;

- (oneway void)registerClient:(byref id<TrafficBotHelperClient>)client;
- (oneway void)unregisterClient:(byref id<TrafficBotHelperClient>)client;

- (void)start;
- (void)stop;

- (NSDictionary *)statistics;

- (NSString *)version;
- (void)ping;

@end

NSDistantObject<TrafficBotHelperServer> *tbhVendServer(id<TrafficBotHelperClient> client,
                                                       SEL serverDidDieNotificationSelector,
                                                       NSArray *monitoredInterfaceNames);
void tbhDisconnectFromServer(NSDistantObject<TrafficBotHelperServer> *server, id<TrafficBotHelperClient> client);

BOOL tbhServerIsOK();
BOOL tbhIsAlive(id receiver);
