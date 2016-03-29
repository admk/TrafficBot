//
//  AKGaugeView.h
//  GaugeView
//
//  Created by Adam Ko on 26/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//
//  View properties
//  Width = 150, Height = 82

#import <Cocoa/Cocoa.h>


@interface AKGaugeView : NSView {

@private
	float		_percentage;
	float		_criticalPercentage;

	NSImage		*_gaugeImage;
	NSImageView *_gaugePointerView;
	__weak NSTimer *_percentageAnimationTimer;
	int			_frameCount;
	float		_animatedPercentage;
	float		_increment;
}

@property (assign, nonatomic) float percentage;
@property (assign, nonatomic) float criticalPercentage;

- (void)setPercentage:(float)value animated:(BOOL)isAnimated;

@end
