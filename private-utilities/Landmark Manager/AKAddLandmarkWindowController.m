//
//  AKAddLocationWindowController.m
//  TrafficBot
//
//  Created by Adam Ko on 11/07/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "AKAddLandmarkWindowController.h"

void NSImageFromURL(NSURL *URL, void (^imageBlock)(NSImage *image), void (^errorBlock)(void))
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                   ^(void)
                   {
                       NSData *data = [NSData dataWithContentsOfURL:URL];
                       NSImage *image = [[[NSImage alloc] initWithData:data] autorelease];
                       dispatch_async(dispatch_get_main_queue(),
                                      ^(void)
                                      {
                                          if(image)
                                          {
                                              imageBlock(image);
                                              return;
                                          }
                                          errorBlock();
                                      });
                   });
}

@interface AKAddLandmarkWindowController ()

- (void)_refreshWindow;
- (void)_didReceiveNotificationFromLocationManager:(NSNotification *)notification;

@end

@implementation AKAddLandmarkWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (!self) return nil;

	_mode = AKUndefinedLocationMode;
	_landmark = nil;
    _hasLocation = NO;
    _locationFail = NO;

    return self;
}

- (void)dealloc
{
    [[AKLandmarkManager sharedManager] removeObserver:self];

	[_landmark release], _landmark = nil;
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.window.delegate = self;
}

#pragma mark - window handling
- (void)windowDidBecomeKey:(NSNotification *)notification
{
    // refresh if has landmark
    if (!self.landmark) return;
    [self _refreshWindow];
}

#pragma mark - setters & getters
- (void)setMode:(AKAddLocationMode)mode
{
	if (_mode == mode) return;
	_mode = mode;

	[progressIndicator startAnimation:self];
	self.hasLocation = NO;
	self.locationFail = NO;

	switch (mode)
	{
		case AKAutomaticLocationMode:
		{
			self.landmark = [AKLandmark landmark];
			// tracking
			[[AKLandmarkManager sharedManager] setTracking:YES];
			[[AKLandmarkManager sharedManager] addObserver:self selector:@selector(_didReceiveNotificationFromLocationManager:)];
		}
		break;

		case AKSpecifyLocationMode:
		{
			[[AKLandmarkManager sharedManager] removeObserver:self];
		}
		break;

		default: break;
	}
}

- (void)setLandmark:(AKLandmark *)landmark
{
	if (_landmark == landmark) return;
	[_landmark release];
	_landmark = [[AKLandmark alloc] initWithLandmark:landmark];

    if (![self.window isVisible]) return;
    [self _refreshWindow];
}

#pragma mark - refresh display
- (void)_refreshWindow
{
	// progress indicator
	[progressIndicator startAnimation:self];
	self.hasLocation = NO;
    self.locationFail = NO;

	// image updating
	NSURL *url =  [self.landmark imageURL];
    NSImageFromURL(url,
                   ^(NSImage *image)
                   {
                       [mapImageView setImage:image];
                       [progressIndicator stopAnimation:self];
					   self.hasLocation = YES;
					   self.locationFail = (nil == self.landmark.location);
                   },
                   ^(void)
				   {
					   self.hasLocation = YES;
					   self.locationFail = YES;
                   });
}

#pragma mark - location service
- (void)_didReceiveNotificationFromLocationManager:(NSNotification *)notification
{
    if ([[notification name] isEqual:AKLandmarkManagerDidGetNewLandmarkNotification])
    {
        
    }
    else if ([[notification name] isEqual:AKLandmarkManagerDidFailNotification])
    {
        self.hasLocation = NO;
        self.locationFail = YES;
    }
	self.landmark = [[AKLandmarkManager sharedManager] landmark];
}

#pragma mark - IBAction
- (IBAction)cancel:(id)sender
{
    [self.window orderOut:self];
    [NSApp endSheet:self.window returnCode:NSCancelButton];
}

- (IBAction)save:(id)sender
{
    [self.window orderOut:self];
    [NSApp endSheet:self.window returnCode:NSOKButton];
}

#pragma mark - synthesize
@synthesize mode = _mode, landmark = _landmark;
@synthesize hasLocation = _hasLocation, locationFail = _locationFail;
@end
