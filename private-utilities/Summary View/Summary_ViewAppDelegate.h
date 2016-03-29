//
//  Summary_ViewAppDelegate.h
//  Summary View
//
//  Created by Adam Ko on 22/01/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AKSummaryView;
@interface Summary_ViewAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
	IBOutlet AKSummaryView *summaryView;
}

@property (assign) IBOutlet NSWindow *window;

@end
