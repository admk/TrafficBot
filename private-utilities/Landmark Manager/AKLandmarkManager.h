//
//  AKLocationManager.h
//  TrafficBot
//
//  Created by Xitong Gao on 08/07/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "AKLandmark.h"
#import <Cocoa/Cocoa.h>
#import <CoreLocation/CoreLocation.h>

#define AKLandmarkManagerDidGetNewLandmarkNotification @"AKLandmarkManagerDidGetNewLandmarkNotification"
#define AKLandmarkManagerDidFailNotification @"AKLandmarkManagerDidFailNotification"

@interface AKLandmarkManager : NSObject <CLLocationManagerDelegate> {
@private
    CLLocationManager *_locationManager;
    AKLandmark *_landmark;
    
	__weak NSTimer *_timer;

    BOOL _tracking;
    NSArray *_landmarks;
}

@property (assign, nonatomic, getter = isTracking) BOOL tracking;
@property (readonly) AKLandmark *landmark;
@property (retain, nonatomic) NSArray *landmarks;

+ (AKLandmarkManager *)sharedManager;

// notifications
- (void)addObserver:(id)inObserver selector:(SEL)inSelector;
- (void)removeObserver:(id)inObserver;

// array of AKLandmark instances
- (NSArray *)nearbyLandmarks;
- (BOOL)hasNearbyLandmarks;

@end
