//
//  StatusItemController.m
//  Serenitas
//
//  Created by Adam Ko on 11/08/2010.
//  Copyright (c) 2010 Loca Apps. All rights reserved.
//

#ifdef DEBUG
#import <FScript/FScript.h>
#endif
#import "TBStatusItemController.h"

@implementation TBStatusItemController

#pragma mark -
#pragma mark init & dealloc
- (id)init {
	self = [super init];
    if (!self) return nil;
	
    return self;
}
- (void)showStatusItem {
	float width = 30.0;
    float height = [[NSStatusBar systemStatusBar] thickness];
    NSRect viewFrame = NSMakeRect(0, 0, width, height);
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:width] retain];
	self.statusItemView = [[[TBStatusItemView alloc] initWithFrame:viewFrame controller:self] autorelease];
    [statusItem setView:statusItemView];
}
- (void)dealloc {
	[statusItemView release], statusItemView = nil;
	[statusItem release], statusItem = nil;
	[super dealloc];
}

#pragma mark -
#pragma mark UI methods
- (void)showMenu:(id)sender {
	
#ifdef DEBUG
	static FScriptMenuItem *fsMenuItem = nil;
	if (!fsMenuItem)
	{
		fsMenuItem = [[FScriptMenuItem alloc] init];
		FSInterpreter *interpreter = [[fsMenuItem interpreterView] interpreter];
		[interpreter setObject:[NSApp delegate] forIdentifier:@"controller"];
		[menu addItem:fsMenuItem];
		[fsMenuItem release];
	}
#endif // DEBUG
	
	[statusItem popUpStatusItemMenu:menu];
}
- (IBAction)about:(id)sender {
	[[NSApplication sharedApplication] orderFrontStandardAboutPanel:sender];
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}
- (void)dismissHighlight:(id)sender {
	[self.statusItemView dismissHighlight:sender];
}

@synthesize statusItemView;
@end
