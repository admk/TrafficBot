//
//  TBPreferencesWindowController.h
//  TrafficBot
//
//  Created by Adam Ko on 31/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TBSummaryGenerator, AKSummaryView, AKAddLandmarkWindowController;
@interface TBPreferencesWindowController : NSWindowController <NSPathControlDelegate, NSTableViewDataSource, NSTableViewDelegate> {

    AKAddLandmarkWindowController *addLocationWindowController;

	IBOutlet NSToolbar *pToolbar;
	IBOutlet NSView *statusView;
	IBOutlet NSView *generalView;
	IBOutlet NSView *monitoringView;
    IBOutlet NSView *locationView;
	IBOutlet NSView *advancedView;
	
	IBOutlet AKSummaryView *summaryView;

	IBOutlet NSPathControl *pathControl;

	IBOutlet NSArrayController *landmarkArrayController;
	IBOutlet NSTableView *landmarkTableView;
	IBOutlet NSTextField *landmarksWarningTextField;

    IBOutlet NSTableView *interfacesTableView;
    IBOutlet NSTextField *interfacesWarningTextField;

@private
	__weak NSView *_preferencesView;
	TBSummaryGenerator *_summaryGenerator;
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

- (IBAction)updateRollingPeriodTimeInterval:(id)sender;
- (IBAction)updateLimit:(id)sender;
- (IBAction)updateThresholds:(id)sender;

- (IBAction)runPathDidChange:(NSPathControl *)myPathControl;

- (IBAction)addLandmark:(id)sender;
- (IBAction)removeLandmark:(id)sender;
- (IBAction)editLandmark:(id)sender;

@end
