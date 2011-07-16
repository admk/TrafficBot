//
//  TBStatusViewController.h
//  TrafficBot
//
//  Created by Adam Ko on 25/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MAAttachedWindow, AKGaugeView, TBGraphView, TBSetupView;

@interface TBStatusWindowController : NSWindowController {
	
	NSView		*contentView;
	AKGaugeView	*gaugeView;
	IBOutlet NSTextField	*usageTextField;
	
@private
	TBSetupView	*_notMonitoringView;
	BOOL		_monitoring;
	NSNumber	*_limit;
	
	BOOL		_shouldAnimateGauge;
	BOOL		_animate;
}

@property (nonatomic, assign) IBOutlet NSView		*contentView;
@property (nonatomic, assign) IBOutlet AKGaugeView	*gaugeView;

@property (nonatomic, assign, getter=isMonitoring) BOOL monitoring;
@property (nonatomic, retain, nonatomic) NSNumber *limit;

@property (nonatomic, assign) BOOL shouldAnimateGauge;

- (void)show:(id)sender animate:(BOOL)animate;
- (void)dismiss:(id)sender;
- (IBAction)showGraphWindow:(id)sender;
- (IBAction)preferences:(id)sender;

@end
