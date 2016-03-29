//
//  AKAddAnniversaryWindowController.h
//  TrafficBot
//
//  Created by Gao Xitong on 10/10/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AKAnniversary.h"

@protocol AKAddAnniversaryDelegate <NSObject>
- (void)didFinishWithAnniversary:(AKAnniversary *)anniversary;
@end

@interface AKAddAnniversaryWindowController : NSWindowController <NSWindowDelegate>
{
    id<AKAddAnniversaryDelegate> _delegate;

    NSDate *_date;
    anni_repeat_t _repeat;

    IBOutlet NSDatePicker *datePicker;
    IBOutlet NSPopUpButton *repeatModePicker;
}

@property (assign) id<AKAddAnniversaryDelegate> delegate;

@property (retain) NSDate *date;
@property (assign) anni_repeat_t repeat;

- (void)beginSheetForWindow:(NSWindow *)window anniversary:(AKAnniversary *)anniversary;
- (IBAction)done:(id)sender;

@end
