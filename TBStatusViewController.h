//
//  TBStatusViewController.h
//  TrafficBot
//
//  Created by Adam Ko on 25/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MAAttachedWindow, AKGaugeView, TBGraphView;

@interface TBStatusViewController : NSViewController {
	
	MAAttachedWindow		*window;
	IBOutlet AKGaugeView	*gaugeView;
	IBOutlet NSView			*notMonitoringView;
	IBOutlet NSTextField	*usageTextField;
		
@private
	NSRect				_statusItemRect;
	BOOL				_monitoring;
	NSNumber			*_limit;
}

@property (readonly) MAAttachedWindow *window;
@property (assign, getter=isMonitoring) BOOL monitoring;
@property (retain, nonatomic) NSNumber *limit;

- (void)show:(id)sender atPoint:(NSPoint)point;
- (void)dismiss:(id)sender;
- (IBAction)info:(id)sender;
- (IBAction)preferences:(id)sender;

@end
