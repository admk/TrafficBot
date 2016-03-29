//
//  Graph_ViewAppDelegate.m
//  Graph View
//
//  Created by Adam Ko on 10/12/2010.
//  Copyright 2010 Imperial College. All rights reserved.
//

#import "Graph_ViewAppDelegate.h"
#import "TBGraphView.h"
#import <FScript/FScript.h>

@implementation Graph_ViewAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:NO ? @"TrafficBot (rolling period).plist" : @"test.plist"];
	NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:path];

	NSMutableDictionary *totalDict = [[NSMutableDictionary alloc] initWithCapacity:[dict count]];
	for (NSString *dateString in [dict allKeys]) {
		NSDictionary *value = [dict objectForKey:dateString];
		double total = [[value objectForKey:@"in"] doubleValue] + [[value objectForKey:@"out"] doubleValue];
		[totalDict setObject:[NSNumber numberWithDouble:total] forKey:[NSDate dateWithString:dateString]];
	}
	[dict release];

	[graphView setDataDict:totalDict];
	[totalDict release];
	[graphView setNeedsDisplay:YES];
	[window setAcceptsMouseMovedEvents:YES];
	[window makeFirstResponder:graphView];
}

@end
