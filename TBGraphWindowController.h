//
//  TBGraphWindowController.h
//  TrafficBot
//
//  Created by Adam Ko on 13/12/2010.
//  Copyright 2010 Imperial College. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TBGraphView.h"

@interface TBGraphWindowController : NSWindowController <TBGraphViewDelegate> {

	NSView		*contentView;
	TBGraphView *graphView;
	NSPanel		*draggedPanel;
	TBGraphView *draggedGraphView;
@private
	NSRect		_zoomRect;
}
@property (assign) IBOutlet NSView		*contentView;
@property (assign) IBOutlet TBGraphView *graphView;
@property (assign) IBOutlet NSPanel		*draggedPanel;
@property (assign) IBOutlet TBGraphView *draggedGraphView;

- (void)flip:(id)sender fromWindow:(NSWindow *)aWindow atPoint:(NSPoint)point;
- (void)dismiss:(id)sender;

@end
