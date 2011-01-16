//
//  TBFirstLaunchWindowController.h
//  TrafficBot
//
//  Created by Adam Ko on 16/01/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TBSetupView;
@interface TBFirstLaunchWindowController : NSWindowController {
	
	NSView			*contentView;
@private
	TBSetupView		*_setupView;
}

@property (retain, nonatomic) IBOutlet NSView *contentView;

- (void)show:(id)sender;
- (void)dismiss:(id)sender;

@end
