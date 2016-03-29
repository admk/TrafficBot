//
//  Graph_ViewAppDelegate.h
//  Graph View
//
//  Created by Adam Ko on 10/12/2010.
//  Copyright 2010 Imperial College. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TBGraphView;

@interface Graph_ViewAppDelegate : NSObject <NSApplicationDelegate> {

	IBOutlet TBGraphView *graphView;

    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
