//
//  Summary_ViewAppDelegate.m
//  Summary View
//
//  Created by Adam Ko on 22/01/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import "Summary_ViewAppDelegate.h"
#import "AKSummaryView.h"

@implementation Summary_ViewAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSShadow *vShadow = [[[NSShadow alloc] init] autorelease];
	[vShadow setShadowColor:[NSColor blackColor]];
	[vShadow setShadowBlurRadius:5];
	[vShadow setShadowOffset:NSMakeSize(0, -2)];
	[summaryView setShadow:vShadow];
}

@end
