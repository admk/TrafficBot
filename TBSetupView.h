//
//  TBSetupView.h
//  TrafficBot
//
//  Created by Adam Ko on 15/01/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TBSetupView : NSView {

@private
	NSString *_infoString;
	NSButton *_setupButton;
}

@property (nonatomic, retain) NSString *infoString;

@end
