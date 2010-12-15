//
//  TBStatusViewController.h
//  TrafficBot
//
//  Created by Adam Ko on 25/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MAAttachedWindow, AKGaugeView, TBGraphView;

@interface TBStatusWindowController : NSWindowController {
	
	NSView		*contentView;
	AKGaugeView	*gaugeView;
	NSView		*notMonitoringView;
	NSTextField	*usageTextField;
@private
	NSRect				_statusItemRect;
	BOOL				_monitoring;
	NSNumber			*_limit;
}

@property (assign) IBOutlet NSView		*contentView;
@property (assign) IBOutlet AKGaugeView	*gaugeView;
@property (assign) IBOutlet NSView		*notMonitoringView;
@property (assign) IBOutlet NSTextField	*usageTextField;

@property (assign, getter=isMonitoring) BOOL monitoring;
@property (retain, nonatomic) NSNumber *limit;

- (void)show:(id)sender atPoint:(NSPoint)point;
- (void)dismiss:(id)sender;
- (IBAction)info:(id)sender;
- (IBAction)preferences:(id)sender;

@end
