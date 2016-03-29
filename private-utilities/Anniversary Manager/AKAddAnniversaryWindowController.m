//
//  AKAddAnniversaryWindowController.m
//  TrafficBot
//
//  Created by Gao Xitong on 10/10/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import "AKAddAnniversaryWindowController.h"

@interface AKAddAnniversaryWindowController ()
- (void)_windowSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
@end
@implementation AKAddAnniversaryWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (!self) return nil;
    
    return self;
}

- (void)awakeFromNib
{
    
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.window.delegate = self;
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    if (!self.date) self.date = [NSDate date];
}

- (void)beginSheetForWindow:(NSWindow *)window anniversary:(AKAnniversary *)anniversary
{
    if (anniversary)
    {
        self.date = anniversary.startDate;
        self.repeat = anniversary.repeat;
    }
    [NSApp beginSheet:[self window]
       modalForWindow:window
        modalDelegate:self
       didEndSelector:@selector(_windowSheetDidEnd:returnCode:contextInfo:)
          contextInfo:nil];
}
- (IBAction)done:(id)sender
{
    [self.window orderOut:self];
    [NSApp endSheet:self.window returnCode:NSOKButton];
}

- (void)_windowSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [self.delegate didFinishWithAnniversary:
     [AKAnniversary anniversaryWithDate:self.date
                                 repeat:self.repeat]];
}

@synthesize delegate = _delegate;
@synthesize date = _date, repeat = _repeat;
@end
