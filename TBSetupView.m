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
    if (!self) return nil;
    return self;
}

- (void)dealloc {
	[_setupButton release], _setupButton = nil;
	self.infoString = nil;
	[super dealloc];
}

- (void)viewWillMoveToSuperview:(NSView *)newSuperview {
	if (_setupButton)
		[_setupButton release];
	_setupButton = [[NSButton alloc] init];
	[_setupButton setButtonType:NSMomentaryChangeButton];
	[_setupButton setBordered:NO];
	[_setupButton setBezelStyle:NO];
	[_setupButton setBezelStyle:NSRegularSquareBezelStyle];
	NSImage *image = [NSImage imageNamed:@"Set Up Button.png"];
	[_setupButton setImage:image];
	[_setupButton setAlternateImage:[NSImage imageNamed:@"Set Up Button Pressed.png"]];
	NSRect bFrame = NSMakeRect((int)(self.bounds.size.width / 2 - image.size.width / 2),
							   (int)(self.bounds.size.height / 2 - image.size.height / 2) - 15, 
							   image.size.width, image.size.height);
	[_setupButton setFrame:bFrame];
	[_setupButton setTarget:[NSApp delegate]];
	[_setupButton setAction:@selector(showPreferencesWindow:)];
	[self addSubview:_setupButton];
}

- (void)mouseDown:(NSEvent *)theEvent {
	// blocks interactions under itself
}

- (void)drawRect:(NSRect)dirtyRect {
	
    // background
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:5 yRadius:5];
	if (!self.backgroundColor) {
		NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:[NSColor clearColor], 0.0f, [NSColor blackColor], .3f, nil];
		[gradient drawInBezierPath:path angle:-90];
	}
	else {
		[self.backgroundColor set];
		[path fill];
	}
	
	// string
	if (!self.infoString) {
		self.infoString = @"Set up info goes here...";
	}
	NSBezierPath *psPath = [self.infoString bezierWithFont:[NSFont fontWithName:@"Helvetica Neue Bold" size:15]];
	NSAffineTransform *xform = [NSAffineTransform transform];
	// fill path
	[xform translateXBy:(self.bounds.size.width / 2 - psPath.bounds.size.width / 2)
					yBy:(self.bounds.size.height / 2 - psPath.bounds.size.height / 2 + 20)];
	[xform concat];
	[[NSColor whiteColor] set];
	[psPath fill];
}

#pragma mark -
#pragma mark setters & getters
- (void)setBackgroundColor:(NSColor *)color {
	if (_backgroundColor == color) return;
	[_backgroundColor release];
	_backgroundColor = [color retain];
	[self setNeedsDisplay:YES];
}
- (void)setInfoString:(NSString *)string {
	if (_infoString == string) return;
	[_infoString release];
	_infoString = [string retain];
	[self setNeedsDisplay:YES];
}

@synthesize infoString = _infoString;
@synthesize backgroundColor = _backgroundColor;
@end
