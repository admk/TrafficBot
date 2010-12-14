//
//  AKBytesFormatter.m
//  TrafficBot
//
//  Created by Adam Ko on 12/12/2010.
//  Copyright 2010 Imperial College. All rights reserved.
//

#import "AKBytesFormatter.h"


@implementation AKBytesFormatter

#pragma mark convertion
+ (NSString *)convertBytesWithNumber:(NSNumber *)number {
	return [self convertBytesWithNumber:number toUnit:[self bestUnitForNumber:number]];
}
+ (NSString *)convertBytesWithNumber:(NSNumber *)number toUnit:(AKBytesFormatterUnit)unit {
	u_int64_t ullNum = [number unsignedLongLongValue];
	ullNum /= unit;
	NSNumber *numWithUnit = [NSNumber numberWithFloat:ullNum];
	switch (unit) {
		case AKBytesFormatterBytesUnit:		return [NSString stringWithFormat:@"%@ B",  numWithUnit];
		case AKBytesFormatterKiloBytesUnit: return [NSString stringWithFormat:@"%@ KB", numWithUnit];
		case AKBytesFormatterMegaBytesUnit: return [NSString stringWithFormat:@"%@ MB", numWithUnit];
		case AKBytesFormatterGigaBytesUnit: return [NSString stringWithFormat:@"%@ GB", numWithUnit];
		default: ALog(@"unrecognised unit: %l", unit); return nil;
	}
}
+ (AKBytesFormatterUnit)bestUnitForNumber:(NSNumber *)number {
	switch ([number unsignedLongLongValue]) {
		case 0							   ... AKBytesFormatterKiloBytesUnit-1: return AKBytesFormatterBytesUnit;
		case AKBytesFormatterKiloBytesUnit ... AKBytesFormatterMegaBytesUnit-1: return AKBytesFormatterKiloBytesUnit;
		case AKBytesFormatterMegaBytesUnit ... AKBytesFormatterGigaBytesUnit-1: return AKBytesFormatterMegaBytesUnit;
		default /* > AKBytesFormatterGigaBytesUnit ... */ :						return AKBytesFormatterGigaBytesUnit; 
	}
}


@end
