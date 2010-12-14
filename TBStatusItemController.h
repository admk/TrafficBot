//
//  TBStatusItemController.h
//  TrafficBot
//
//  Created by Adam Ko on 11/08/2010.
//  Copyright (c) 2010 Loca Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TBStatusItemView.h"

@interface TBStatusItemController : NSObject <TBStatusItemViewDelegate> {
	
	TBStatusItemView *statusItemView;
	
	NSStatusItem* statusItem;
	IBOutlet NSMenu *menu;
}

@property (retain) TBStatusItemView *statusItemView;

- (id)init;
- (void)showStatusItem;

- (void)dismissHighlight:(id)sender;
- (void)showMenu:(id)sender;
- (IBAction)about:(id)sender;

@end
