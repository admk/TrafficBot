//
//  AKSummaryView.h
//  Summary View
//
//  Created by Adam Ko on 22/01/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AKSummaryView : NSView {

@private
	NSString *_summaryString;
	NSImage *_backgroundImage;
	NSColor *_textColor;
	NSShadow *_shadow;
}

@property (retain, nonatomic) NSString *summaryString;

- (NSImage *)backgroundImage;
- (void)setBackgroundImage:(NSImage *)image;

- (NSColor *)textColor;
- (void)setTextColor:(NSColor *)color;

- (NSShadow *)shadow;
- (void)setShadow:(NSShadow *)aShadow;


@end
