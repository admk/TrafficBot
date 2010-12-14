//
//  TBStatusItemView.h
//  TrafficBot
//
//  Created by Adam Ko on 25/10/2010.
//  Copyright (c) 2010 Cocoa Loco. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol TBStatusItemViewDelegate
- (void)showMenu:(id)sender;
@end


@interface TBStatusItemView : NSView {
	
	__weak id<TBStatusItemViewDelegate> controller;
    BOOL _highlighted;
	
}
@property (assign) id<TBStatusItemViewDelegate> controller;

- (id)initWithFrame:(NSRect)frame controller:(id<TBStatusItemViewDelegate>)inController;

- (void)highlight:(id)sender;
- (void)dismissHighlight:(id)sender;

@end
