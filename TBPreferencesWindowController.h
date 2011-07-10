//
//  TBPreferencesWindowController.h
//  TrafficBot
//
//  Created by Adam Ko on 31/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class TBSummaryGenerator, AKSummaryView;
@interface TBPreferencesWindowController : NSWindowController <NSPathControlDelegate, NSTableViewDataSource, NSTableViewDelegate> {
	
	IBOutlet NSToolbar *pToolbar;
	IBOutlet NSView *statusView;
	IBOutlet NSView *generalView;
	IBOutlet NSView *monitoringView;
    IBOutlet NSView *locationView;
	IBOutlet NSView *advancedView;
	
	IBOutlet AKSummaryView *summaryView;

	IBOutlet NSPathControl *pathControl;

	IBOutlet NSArrayController *landmarkArrayController;

    IBOutlet NSTableView *interfacesTableView;
    IBOutlet NSTextField *interfacesWarningTextField;

@private
	__weak NSView *_preferencesView;
	TBSummaryGenerator *_summaryGenerator;
    NSArray *_interfaceNameArray;

    NSArray *_includeInterfaces;
    
    BOOL _hasLocation;
    BOOL _locationFail;
    NSImage *_currentLocationImage;
}

@property (retain, nonatomic) NSArray *includeInterfaces;
@property (assign, nonatomic) NSImage *currentLocationImage;
@property (assign, nonatomic) BOOL hasLocation;
@property (assign, nonatomic) BOOL locationFail;

// IBAction methods
- (IBAction)continueToSetup:(id)sender;
- (IBAction)didSelectToolbarItem:(id)sender;
- (IBAction)clearStatistics:(id)sender;
- (IBAction)resetAllPrefs:(id)sender;

- (IBAction)updateRollingPeriodTimeInterval:(id)sender;
- (IBAction)updateLimit:(id)sender;
- (IBAction)updateThresholds:(id)sender;

- (IBAction)runPathDidChange:(NSPathControl *)myPathControl;

@end
