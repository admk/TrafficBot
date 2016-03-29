//
//  AKAddLocationWindowController.h
//  TrafficBot
//
//  Created by Adam Ko on 11/07/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AKLandmarkManager.h"

@class AKLandmark;

typedef enum
{
	AKUndefinedLocationMode = -1,
	AKAutomaticLocationMode = 0,
	AKSpecifyLocationMode = 1
}
AKAddLocationMode;

@interface AKAddLandmarkWindowController : NSWindowController <NSWindowDelegate>
{
	IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSImageView *mapImageView;
    IBOutlet NSTextField *nameTextField;

@private
	AKAddLocationMode _mode;

	AKLandmark *_landmark;
    BOOL _hasLocation;
    BOOL _locationFail;
}

@property (assign, nonatomic) AKAddLocationMode mode;
@property (copy,   nonatomic) AKLandmark *landmark;
@property (assign, nonatomic) BOOL hasLocation;
@property (assign, nonatomic) BOOL locationFail;

- (IBAction)cancel:(id)sender;
- (IBAction)save:(id)sender;

@end
