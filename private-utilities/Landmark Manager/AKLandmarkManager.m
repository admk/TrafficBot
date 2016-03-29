//
//  AKLocationManager.m
//  TrafficBot
//
//  Created by Xitong Gao on 08/07/2011.
//  Copyright 2011 AK.Kloca. All rights reserved.
//

#import "AKLandmarkManager.h"

#define ALL_NOTIFICATIONS	[NSArray arrayWithObjects: \
                             AKLandmarkManagerDidGetNewLandmarkNotification, \
                             AKLandmarkManagerDidFailNotification, nil]

@interface AKLandmarkManager ()

- (void)_setLandmark:(AKLandmark *)landmark;
- (void)_timedOut:(NSTimer *)timer;

@end


@implementation AKLandmarkManager

static AKLandmarkManager *sharedManager = nil;

+ (AKLandmarkManager *)sharedManager
{
    if (!sharedManager)
    {
		@synchronized(self)
        {
			sharedManager = [[self alloc] init];
		}
	}
	return sharedManager;
}

- (id)init
{
    self = [super init];
    if (!self) return nil;
    
    _tracking = NO;
    _landmarks = nil;

    return self;
}

- (void)dealloc
{
    [_locationManager release], _locationManager = nil;
    [_landmarks release], _landmarks = nil;
    [_landmark release], _landmark = nil;

    [super dealloc];
}

#pragma mark - setters & getters
- (AKLandmark *)landmark
{
	if (!_landmark) return nil;
	// if (_landmark.name) return _landmark;

    _landmark.name = NSLocalizedString(@"Unknown", @"landmark manager");

	for (AKLandmark *curLandmark in self.landmarks)
	{
		if ([curLandmark nearby:_landmark])
		{
			_landmark.name = curLandmark.name;
			break;
		}
	}
	return [[_landmark retain] autorelease];
}

- (void)setTracking:(BOOL)tracking
{
    _tracking = tracking;

    if (tracking)
    {
        if (!_locationManager)
        {
            _locationManager = [[CLLocationManager alloc] init];
            _locationManager.delegate = self;
			[self _setLandmark:
             [AKLandmark landmarkWithName:NSLocalizedString(@"Locating...", @"landmark manager")
                                 location:self.landmark.location]];
        }
		if (!_timer)
		{
			_timer = [NSTimer scheduledTimerWithTimeInterval:15
													  target:self
													selector:@selector(_timedOut:)
													userInfo:nil
													 repeats:NO];
		}
        [_locationManager startUpdatingLocation];
        return;
    }
	// not tracking
    [_locationManager stopUpdatingLocation];
    [_locationManager release], _locationManager = nil;
	[_timer invalidate]; _timer = nil;
}
- (void)setLandmarks:(NSArray *)landmarks
{
	if (_landmarks == landmarks) return;

    AKLandmark *prevLandmark = [AKLandmark landmarkWithLandmark:self.landmark];

	[_landmarks release];
	_landmarks = [landmarks retain];

	if (!self.landmark.location) return;
    if ([prevLandmark.name isEqualToString:self.landmark.name]) return;
	[[NSNotificationCenter defaultCenter] postNotificationName:AKLandmarkManagerDidGetNewLandmarkNotification
														object:nil
													  userInfo:nil];
}

#pragma mark - notifications
- (void)addObserver:(id)inObserver selector:(SEL)inSelector
{
	for (NSString *notificationName in ALL_NOTIFICATIONS)
		[[NSNotificationCenter defaultCenter] addObserver:inObserver selector:inSelector name:notificationName object:nil];

	// post right away if has location
	if (!self.landmark.location) return;
	NSNotification *note = [NSNotification notificationWithName:AKLandmarkManagerDidGetNewLandmarkNotification object:nil];
	if (![inObserver respondsToSelector:inSelector]) return;
	[inObserver performSelector:inSelector withObject:note];
}
- (void)removeObserver:(id)inObserver
{
	for (NSString *notificationName in ALL_NOTIFICATIONS)
		[[NSNotificationCenter defaultCenter] removeObserver:inObserver name:notificationName object:nil];
}

#pragma mark - nearby landmarks
- (NSArray *)nearbyLandmarks
{
    NSMutableArray *landmarks = [NSMutableArray array];
    for (AKLandmark *aLandmark in self.landmarks)
    {
        if ([aLandmark nearby:self.landmark])
		{
			[landmarks addObject:aLandmark];
		}
    }
    return landmarks;
}
- (BOOL)hasNearbyLandmarks
{
	return ([[self nearbyLandmarks] count] > 0);
}

#pragma mark - CLLocationManagerDelegate methods
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
	[_timer invalidate]; _timer = nil;

	// Ignore updates where nothing we care about changed
	if (newLocation.coordinate.longitude == oldLocation.coordinate.longitude &&
		newLocation.coordinate.latitude == oldLocation.coordinate.latitude &&
		newLocation.horizontalAccuracy == oldLocation.horizontalAccuracy)
	{
		return;
	}

    // set location
	AKLandmark *newLandmark = [[[AKLandmark alloc] initWithName:nil location:newLocation] autorelease];
    [self _setLandmark:newLandmark];

    DLog(@"new location, %@", self.landmark.name);
}
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
	[_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:15
                                              target:self
                                            selector:@selector(_timedOut:)
                                            userInfo:nil
                                             repeats:NO];

    // retry...
    [_locationManager stopUpdatingLocation];
    [_locationManager startUpdatingLocation];

    DLog(@"failed, restarting...");
}

#pragma mark - private
- (void)_setLandmark:(AKLandmark *)landmark
{
    if (_landmark == landmark) return;
	if ([_landmark nearby:landmark]) return; // close enough

    [_landmark release];
    _landmark = [landmark retain];

    // post notification
	if (!landmark || !landmark.location) 
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:AKLandmarkManagerDidFailNotification
															object:nil
														  userInfo:nil];
		return;
	}
    [[NSNotificationCenter defaultCenter] postNotificationName:AKLandmarkManagerDidGetNewLandmarkNotification
                                                        object:nil
                                                      userInfo:nil];
}

- (void)_timedOut:(NSTimer *)timer
{
	[_timer invalidate]; _timer = nil;

	AKLandmark *landmark = [AKLandmark landmarkWithName:NSLocalizedString(@"Failed", @"landmark manager")
											   location:nil];
	[self _setLandmark:landmark];
}

@synthesize tracking=_tracking;
@synthesize landmark=_landmark;
@synthesize landmarks=_landmarks;
@end
