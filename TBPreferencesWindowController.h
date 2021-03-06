//
//  TBPreferencesWindowController.h
//  TrafficBot
//
//  Created by Adam Ko on 31/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AKAddAnniversaryWindowController.h"

@class TBSummaryGenerator, AKSummaryView, AKAddLandmarkWindowController;
@interface TBPreferencesWindowController
    : NSWindowController
    <NSWindowDelegate, NSPathControlDelegate, NSTableViewDataSource, NSTableViewDelegate, AKAddAnniversaryDelegate>
{

    AKAddAnniversaryWindowController *addAnniversaryWindowController;
    AKAddLandmarkWindowController *addLocationWindowController;

    // preferences window
	IBOutlet NSToolbar *pToolbar;
	IBOutlet NSView *statusView;
	IBOutlet NSView *generalView;
	IBOutlet NSView *monitoringView;
    IBOutlet NSView *locationView;
	IBOutlet NSView *advancedView;
	
    // summary pane
	IBOutlet AKSummaryView *summaryView;

    // monitoring pane
    IBOutlet NSImageView *tbhStatusImageView;
    IBOutlet NSTextField *tbhStatusTextField;
	IBOutlet NSPathControl *pathControl;
    IBOutlet NSArrayController *anniversaryArrayController;
    IBOutlet NSTableView *anniversaryTableView;
    IBOutlet NSButton *anniversaryAddButton;

    // location pane
	IBOutlet NSArrayController *landmarkArrayController;
	IBOutlet NSTableView *landmarkTableView;
	IBOutlet NSTextField *landmarksWarningTextField;

    // advanced pane
    IBOutlet NSTableView *interfacesTableView;
    IBOutlet NSTextField *interfacesWarningTextField;

@private
	__weak NSView *_preferencesView;
	TBSummaryGenerator *_summaryGenerator;
    __weak NSTimer *_tbhPollTimer;
    NSArray *_interfaces;
    NSArray *_includeInterfaces;
}

@property (retain, nonatomic) NSArray *interfaces;
@property (retain, nonatomic) NSArray *includeInterfaces;

// IBAction methods
- (IBAction)continueToSetup:(id)sender;
- (IBAction)didSelectToolbarItem:(id)sender;
- (IBAction)clearStatistics:(id)sender;
- (IBAction)resetAllPrefs:(id)sender;

- (IBAction)updateMonitoringMode:(id)sender;
- (IBAction)updateRollingPeriodTimeInterval:(id)sender;
- (IBAction)updateFixedPeriod:(id)sender;
- (IBAction)updateLimit:(id)sender;
- (IBAction)updateThresholds:(id)sender;

- (IBAction)toggleExcludingLocal:(id)sender;
- (IBAction)runPathDidChange:(NSPathControl *)myPathControl;

- (IBAction)addAnniversary:(id)sender;
- (IBAction)removeAnniversary:(id)sender;
- (IBAction)editAnniversary:(id)sender;

- (IBAction)addLandmark:(id)sender;
- (IBAction)removeLandmark:(id)sender;
- (IBAction)editLandmark:(id)sender;

@end
