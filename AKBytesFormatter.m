//
//  AKBytesFormatter.m
//  TrafficBot
//
//  Created by Adam Ko on 12/12/2010.
//  Copyright 2010 Imperial College. All rights reserved.
//

#import "AKBytesFormatter.h"


@implementation AKBytesFormatter

#pragma mark -
#pragma mark auto unit
+ (NSString *)convertBytesWithNumber:(NSNumber *)number {
	return [self convertBytesWithNumber:number toUnit:[self bestUnitForNumber:number] decimals:YES];
}
+ (NSString *)convertBytesWithNumber:(NSNumber *)number decimals:(BOOL)decimals {
	return [self convertBytesWithNumber:number toUnit:[self bestUnitForNumber:number] decimals:decimals];
}
+ (NSString *)convertBytesWithNumber:(NSNumber *)number floatingDecimalsWithLength:(int)length {
	return [self convertBytesWithNumber:number toUnit:[self bestUnitForNumber:number] floatingDecimalsWithLength:length];
}
#pragma mark -
#pragma mark custom unit
+ (NSString *)convertBytesWithNumber:(NSNumber *)number toUnit:(AKBytesFormatterUnit)unit floatingDecimalsWithLength:(int)length {
	float floatValue = [number floatValue];
	floatValue /= (float)unit;
	NSString *string = [NSString stringWithFormat:@"%.0f", floatValue];
	switch (length - [string length]) {
		case 1:
			string = [NSString stringWithFormat:@"%.1f", floatValue];
			break;
		case 2 ... INT32_MAX:
			string = [NSString stringWithFormat:@"%.2f", floatValue];
			break;
		default: break;
	}
	NSString *unitString = [self stringForUnit:unit];
	return [string stringByAppendingFormat:@" %@", unitString];
}
+ (NSString *)convertBytesWithNumber:(NSNumber *)number toUnit:(AKBytesFormatterUnit)unit decimals:(BOOL)decimals {
	float floatValue = [number floatValue];
	floatValue /= (float)unit;
	NSString *string = [NSString stringWithFormat:decimals? @"%.2f":@"%.0f", floatValue];
	NSString *unitString = [self stringForUnit:unit];
	return [string stringByAppendingFormat:@" %@", unitString];
}
#pragma mark -
#pragma mark unit
+ (AKBytesFormatterUnit)bestUnitForNumber:(NSNumber *)number {
	switch ([number unsignedLongLongValue]) {
		case 0							   ... AKBytesFormatterKiloBytesUnit-1: return AKBytesFormatterBytesUnit;
		case AKBytesFormatterKiloBytesUnit ... AKBytesFormatterMegaBytesUnit-1: return AKBytesFormatterKiloBytesUnit;
		case AKBytesFormatterMegaBytesUnit ... AKBytesFormatterGigaBytesUnit-1: return AKBytesFormatterMegaBytesUnit;
		default /* > AKBytesFormatterGigaBytesUnit ... */ :						return AKBytesFormatterGigaBytesUnit; 
	}
}
+ (NSString *)stringForUnit:(AKBytesFormatterUnit)unit {
	switch (unit) {
		case AKBytesFormatterBytesUnit:		return @"B";  break;
		case AKBytesFormatterKiloBytesUnit: return @"KB"; break;
		case AKBytesFormatterMegaBytesUnit: return @"MB"; break;
		case AKBytesFormatterGigaBytesUnit:	return @"GB"; break;
		default: ALog(@"bad unit: %l", unit); return nil; break;
	}
}
@end
