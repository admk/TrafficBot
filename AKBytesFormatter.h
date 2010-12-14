//
//  AKBytesFormatter.h
//  TrafficBot
//
//  Created by Adam Ko on 12/12/2010.
//  Copyright 2010 Imperial College. All rights reserved.
//

#import <Cocoa/Cocoa.h>


typedef enum {
	AKBytesFormatterBytesUnit		= 1,
	AKBytesFormatterKiloBytesUnit	= 1024,
	AKBytesFormatterMegaBytesUnit	= 1048576,
	AKBytesFormatterGigaBytesUnit	= 1073741824
} AKBytesFormatterUnit;

@interface AKBytesFormatter : NSObject

+ (NSString *)convertBytesWithNumber:(NSNumber *)number;
+ (NSString *)convertBytesWithNumber:(NSNumber *)number toUnit:(AKBytesFormatterUnit)unit;
+ (AKBytesFormatterUnit)bestUnitForNumber:(NSNumber *)number;

@end
