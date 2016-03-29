//
//  AKLocation.m
//  TrafficBot
//
//  Created by Adam Ko on 10/07/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "AKLandmark.h"


@interface AKLandmark ()

- (double)_latitudeRangeForLocation:(CLLocation *)aLocation;
- (double)_longitudeRangeForLocation:(CLLocation *)aLocation;

@end


@implementation AKLandmark

#pragma mark - initialisers & dealloc
// designated initialiser
- (id)initWithName:(NSString *)name location:(CLLocation *)location
{
	self = [super init];
	if (!self) return nil;
	
	self.location = location;
	self.name = name;
	
	return self;
}

- (id)initWithLandmark:(AKLandmark *)landmark
{
	return [self initWithName:landmark.name location:landmark.location];
}

- (id)init
{
    return [self initWithName:nil location:nil];
}

+ (AKLandmark *)landmark
{
	return [[[AKLandmark alloc] initWithName:nil location:nil] autorelease];
}

+ (AKLandmark *)landmarkWithLandmark:(AKLandmark *)landmark
{
	return [[[AKLandmark alloc] initWithLandmark:landmark] autorelease];
}

+ (AKLandmark *)landmarkWithName:(NSString *)name location:(CLLocation *)location
{
	return [[[AKLandmark alloc] initWithName:name location:location] autorelease];
}

- (id)copyWithZone:(NSZone *)zone
{
	AKLandmark *landmark = [[AKLandmark allocWithZone:zone] init];
	landmark.name = [[self.name copy] autorelease];
	landmark.location = [[self.location copy] autorelease];
	return landmark;
}

- (void)dealloc
{
	[_location release], _location = nil;
	[_name release], _name = nil;
	[super dealloc];
}

#pragma mark - setters & getters
- (NSURL *)imageURL
{
	if (!self.location)
	{
		return [NSURL URLWithString:
				[@"http://maps.google.com/maps/api/staticmap?&size=400x250&maptype=roadmap&sensor=true"
				 stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	}
	// writes the current location string
    NSString *urlString = [NSString stringWithFormat:
                           @"http://maps.google.com/maps/api/staticmap?center=%f,%f&spn=%f,%f&zoom=14&size=400x250&maptype=terrain&markers=size:small|color:blue|label:A|%f,%f&sensor=false",
						   //@"http://maps.google.com/maps/api/staticmap?center=1+Infinite+Loop&zoom=14&size=400x250&maptype=terrain&markers=size:small%7Ccolor:blue%7Clabel:A%7C%25f,%25f&sensor=false",
                           self.location.coordinate.latitude,
                           self.location.coordinate.longitude,
                           [self _latitudeRangeForLocation:self.location],
                           [self _longitudeRangeForLocation:self.location],
                           self.location.coordinate.latitude,
                           self.location.coordinate.longitude];
    urlString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	return [NSURL URLWithString:urlString];
}

#pragma mark - NSCoding protocols
- (id)initWithCoder:(NSCoder *)aDecoder
{
	return [self initWithName:[aDecoder decodeObjectForKey:Property(name)]
					 location:[aDecoder decodeObjectForKey:Property(location)]];
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:self.location forKey:Property(location)];
	[aCoder encodeObject:self.name forKey:Property(name)];
}

#pragma mark - nearby test
- (BOOL)nearby:(AKLandmark *)landmark
{
	if (!self.location || !landmark.location) return NO;

	double dLat = self.location.coordinate.latitude - landmark.location.coordinate.latitude;
	double dLong = self.location.coordinate.longitude - landmark.location.coordinate.longitude;
	if (dLong > 360)
	{
		dLong -= 360;
	}
	const double radius = 6371 * 1000;
	double dVer = radius * M_PI * dLat / 180;
	double dHor = radius * M_PI * dLong / 180;
	double dist = sqrt(dVer * dVer + dHor * dHor);

	if (dist > 2 * self.location.horizontalAccuracy ||
		dist > 2 * landmark.location.horizontalAccuracy)
		return NO;

	return YES;
}

#pragma mark - equality & hashing
- (BOOL)isEqual:(id)object
{
	if (![object isKindOfClass:[self class]]) return NO;
	if (![_location isEqual:[(AKLandmark *)object location]]) return NO;
	if (![_name isEqualToString:[(AKLandmark *)object name]]) return NO;
	return YES;
}
- (NSUInteger)hash
{
	return [_location hash] ^ [_name hash];
}

#pragma mark - private
- (double)_latitudeRangeForLocation:(CLLocation *)aLocation
{
	const double M = 6367000.0; // approximate average meridional radius of curvature of earth
	const double metersToLatitude = 1.0 / ((M_PI / 180.0) * M);
	const double accuracyToWindowScale = 2.0;
	return aLocation.horizontalAccuracy * metersToLatitude * accuracyToWindowScale;
}
- (double)_longitudeRangeForLocation:(CLLocation *)aLocation
{
	double latitudeRange = [self _latitudeRangeForLocation:aLocation];
	return latitudeRange * cos(aLocation.coordinate.latitude * M_PI / 180.0);
}

#pragma mark - synthesize
@synthesize location = _location, name = _name;
@end
