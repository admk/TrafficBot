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
	return [self convertBytesWithNumber:number toUnit:[self bestUnitForNumber:number] decimals:YES];
}
+ (NSString *)convertBytesWithNumber:(NSNumber *)number decimals:(BOOL)decimals {
	return [self convertBytesWithNumber:number toUnit:[self bestUnitForNumber:number] decimals:decimals];
}
+ (NSString *)convertBytesWithNumber:(NSNumber *)number toUnit:(AKBytesFormatterUnit)unit decimals:(BOOL)decimals {	float floatValue = [number floatValue];
	floatValue /= (float)unit;
	NSString *string = [NSString stringWithFormat:decimals? @"%.2f":@"%.0f", floatValue];
	NSString *unitString = nil;
	switch (unit) {
		case AKBytesFormatterBytesUnit:		unitString = @"B";  break; 
		case AKBytesFormatterKiloBytesUnit: unitString = @"KB"; break;
		case AKBytesFormatterMegaBytesUnit: unitString = @"MB"; break;
		case AKBytesFormatterGigaBytesUnit: unitString = @"GB"; break;
		default: ALog(@"unrecognised unit: %l", unit); break;
	}
	return [string stringByAppendingFormat:@" %@", unitString];
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
