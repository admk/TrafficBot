//
//  AKLocation.h
//  TrafficBot
//
//  Created by Adam Ko on 10/07/2011.
//  Copyright 2011 AK.Kloca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreLocation/CoreLocation.h>

@interface AKLandmark : NSObject <NSCoding, NSCopying>
{
@private
	CLLocation *_location;
	NSString *_name;
}

@property (retain, nonatomic) CLLocation *location;
@property (retain, nonatomic) NSString *name;
@property (readonly) NSURL *imageURL;

- (id)initWithLandmark:(AKLandmark *)landmark;
// designated initialiser
- (id)initWithName:(NSString *)name location:(CLLocation *)location;

+ (AKLandmark *)landmark;
+ (AKLandmark *)landmarkWithLandmark:(AKLandmark *)landmark;
+ (AKLandmark *)landmarkWithName:(NSString *)name location:(CLLocation *)location;

- (BOOL)nearby:(AKLandmark *)landmark;

- (BOOL)isEqual:(id)object;
- (NSUInteger)hash;

@end
