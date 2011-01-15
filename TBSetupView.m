//
//  TBSetupView.m
//  TrafficBot
//
//  Created by Adam Ko on 15/01/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import "TBSetupView.h"
#import "TrafficBotAppDelegate.h"
#import "APDrawingCategories.h"

@implementation TBSetupView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)dealloc {
	[_setupButton release], _setupButton = nil;
	self.infoString = nil;
	[super dealloc];
}

- (void)viewDidUnhide {
	if (!_setupButton) {
		_setupButton = [[NSButton alloc] init];
		[_setupButton setButtonType:NSMomentaryChangeButton];
		[_setupButton setBordered:NO];
		[_setupButton setBezelStyle:NO];
		[_setupButton setBezelStyle:NSRegularSquareBezelStyle];
		NSImage *image = [NSImage imageNamed:@"Set Up Button.png"];
		[_setupButton setImage:image];
		[_setupButton setAlternateImage:[NSImage imageNamed:@"Set Up Button Pressed.png"]];
		NSRect frame = NSMakeRect(self.bounds.size.width / 2 - image.size.width,
								  self.bounds.size.height / 2 - image.size.height, 
								  image.size.width, image.size.height);
		[_setupButton setFrame:frame];
		[_setupButton setTarget:[NSApp delegate]];
		[_setupButton setAction:@selector(showPreferencesWindow:)];
		[self addSubview:_setupButton];
	}
}

- (void)drawRect:(NSRect)dirtyRect {
	
    // background
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:5 yRadius:5];
	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:[NSColor clearColor], 0.0f, [NSColor blackColor], .2f, nil];
	[gradient drawInBezierPath:path angle:-90];
	
	// string
	if (!self.infoString) {
		self.infoString = @"Set up info goes here...";
	}
	NSBezierPath *psPath = [self.infoString bezierWithFont:[NSFont fontWithName:@"Helvetica Neue Bold" size:20]];
	NSAffineTransform *xform = [NSAffineTransform transform];
	// fill path
	[xform translateXBy:(self.bounds.size.width / 2 - psPath.bounds.size.width / 2)
					yBy:(self.bounds.size.height / 2 - psPath.bounds.size.height / 2 + 30)];
	[xform concat];
	[[NSColor whiteColor] set];
	[psPath fill];
}

#pragma mark -
#pragma mark setters & getters
- (void)setInfoString:(NSString *)string {
	if (_infoString == string) return;
	[_infoString release];
	_infoString = [string retain];
	[self setNeedsDisplay:YES];
}

@synthesize infoString = _infoString;
@end
