//
//  TBPreferencesWindowController.m
//  TrafficBot
//
//  Created by Adam Ko on 31/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import "TBPreferencesWindowController.h"
#import "AKTrafficMonitorService.h"
#import "AKLandmarkManager.h"
#import "AKAddLandmarkWindowController.h"
#import "TrafficBotAppDelegate.h"
#import "AKSummaryView.h"
#import "TBSummaryGenerator.h"

#define SUMMARY_PANE	@"Summary"
#define GENERAL_PANE	@"General"
#define MONITORING_PANE	@"Monitoring"
#define LOCATION_PANE   @"Location"
#define ADVACNED_PANE	@"Advanced"


@interface TBPreferencesWindowController ()

- (void)addLandmarkSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)editLocationSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

- (void)clearStatisticsAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)resetAllPrefsAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)didSelectPathItem:(id)sender;

- (void)_selectPane:(NSString *)pane;

@end


@implementation TBPreferencesWindowController


- (id)init {
	self = [super initWithWindowNibName:@"TBPreferencesWindow"];
	if (!self) return nil;

    _interfaces = nil;
    _includeInterfaces = nil;

	return self;
}
- (void)dealloc {
	[addLocationWindowController release], addLocationWindowController = nil;
	[_summaryGenerator release], _summaryGenerator = nil;
    [_interfaces release], _interfaces = nil;
    [_includeInterfaces release], _includeInterfaces = nil;
    [super dealloc];
}

- (void)awakeFromNib {

	// summary generator
	if (!_summaryGenerator)
	{
		_summaryGenerator = [[TBSummaryGenerator alloc] init];
		// bindings & notifications
		NSArray *bindings = [NSArray arrayWithObjects:
							 Property(rollingPeriodFactor),
							 Property(rollingPeriodMultiplier),
							 Property(fixedPeriodInterval),
							 Property(shouldNotify),
							 Property(criticalPercentage),
							 Property(limit),
							 Property(monitoringMode),
							 Property(monitoring), nil];
		for (NSString *bindingKey in bindings)
			[_summaryGenerator bind:bindingKey 
						   toObject:[NSUserDefaultsController sharedUserDefaultsController] 
						withKeyPath:[@"values." stringByAppendingString:bindingKey]
							options:nil];
	}
	
	// summary view
	NSShadow *vShadow = [[[NSShadow alloc] init] autorelease];
	[vShadow setShadowColor:[NSColor blackColor]];
	[vShadow setShadowBlurRadius:3];
	[vShadow setShadowOffset:NSMakeSize(0, -1)];
	[summaryView setShadow:vShadow];
	[summaryView setBackgroundImage:[NSImage imageNamed:@"GraphWindowBackground.png"]];
	[summaryView setTextColor:[NSColor whiteColor]];
	[summaryView bind:Property(summaryString)
			 toObject:_summaryGenerator
		  withKeyPath:Property(summaryString)
			  options:nil];
	
	// window sizing
	[self.window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
	NSRect frame = generalView.frame;
	frame.size.height = 75; // offset for the toolbar
    [self.window setFrame:frame display:NO animate:NO];
	[self.window center];	
	
    // path
	[pathControl setURL:[NSURL fileURLWithPath:Defaults(runURL)]];

	// landmarks
	[landmarkTableView setTarget:self];
	[landmarkTableView setDoubleAction:@selector(editLandmark:)];
	
	// update warning text field on no landmarks added
    if ([[landmarkArrayController arrangedObjects] count] == 0)
        [landmarksWarningTextField setTextColor:[NSColor redColor]];
    else
        [landmarksWarningTextField setTextColor:[NSColor darkGrayColor]];
}
- (void)windowDidLoad {
	[self _selectPane:SUMMARY_PANE];
}

#pragma mark -
#pragma mark setters & getters
- (void)setInterfaces:(NSArray *)interfaces
{
	if (_interfaces == interfaces) return;
	[_interfaces release];
	_interfaces = [interfaces retain];
	// reload table view
	[interfacesTableView reloadData];
}

#pragma mark -
#pragma mark IBAction methods

- (IBAction)continueToSetup:(id)sender {
	[self _selectPane:MONITORING_PANE];
}

- (IBAction)didSelectToolbarItem:(id)sender {
	
	NSView *oldPreferencesView = _preferencesView;
	
	NSString *identifier = [pToolbar selectedItemIdentifier];
	if ([identifier isEqual:SUMMARY_PANE])
		_preferencesView = statusView;
	else if ([identifier isEqual:GENERAL_PANE])
		_preferencesView = generalView;
	else if ([identifier isEqual:MONITORING_PANE])
		_preferencesView = monitoringView;
    else if ([identifier isEqual:LOCATION_PANE])
        _preferencesView = locationView;
	else if ([identifier isEqual:ADVACNED_PANE])
		_preferencesView = advancedView;
	
	if (oldPreferencesView == _preferencesView) return;
	
	[oldPreferencesView removeFromSuperview];
	
	float heightDelta = (float)(_preferencesView.frame.size.height - oldPreferencesView.frame.size.height);
    NSRect frame = [self.window frame];
    frame.origin.y -= heightDelta;
    frame.size.height += heightDelta;
	
    [self.window setFrame:frame display:YES animate:YES];
	[self.window.contentView addSubview:_preferencesView];
}

#pragma mark -
#pragma mark monitoring

#pragma mark path control
- (void)pathControl:(NSPathControl *)myPathControl willDisplayOpenPanel:(NSOpenPanel *)openPanel {
	// change the wind title and choose buttons titles
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setCanChooseFiles:YES];
	[openPanel setResolvesAliases:YES];
	[openPanel setTitle:@"Choose an executable file"];
	[openPanel setPrompt:@"Choose"];
}
- (void)pathControl:(NSPathControl *)myPathControl willPopUpMenu:(NSMenu *)menu {
	NSMenuItem *sleepMacItem = [[[NSMenuItem allocWithZone:[NSMenu menuZone]]
								 initWithTitle:@"Sleep Mac"
								 action:@selector(didSelectPathItem:)
								 keyEquivalent:@""] autorelease];
	[sleepMacItem setTarget:self];
	[menu addItem:[NSMenuItem separatorItem]];
	[menu addItem:sleepMacItem];
}
- (void)didSelectPathItem:(id)sender {
	if ([[sender title] isEqual:@"Sleep Mac"]) {
		NSString *urlString = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Sleep Mac.scpt"];
		NSURL *url = [NSURL fileURLWithPath:urlString];
		[pathControl setURL:url];
		SetDefaults(urlString, runURL);
	}
}
- (NSDragOperation)pathControl:(NSPathControl *)myPathControl validateDrop:(id <NSDraggingInfo>)info {
	NSURL *url = [NSURL URLFromPasteboard:[info draggingPasteboard]];
	BOOL isDirectory = NO;
	BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDirectory];
	if (fileExists && (!isDirectory || [[url path] hasSuffix:@".app"])) {
		return NSDragOperationCopy;
	}
	return NSDragOperationNone;
}
-(BOOL)pathControl:(NSPathControl *)myPathControl acceptDrop:(id <NSDraggingInfo>)info {
	NSURL *url = [NSURL URLFromPasteboard:[info draggingPasteboard]];
	[myPathControl setURL:url];
	return YES;
}
- (IBAction)runPathDidChange:(NSPathControl *)myPathControl {
	SetDefaults([[myPathControl URL] path], runURL);
}

#pragma mark defaults update
- (IBAction)updateRollingPeriodTimeInterval:(id)sender {
	float factor = [Defaults(rollingPeriodFactor) floatValue];
	float multiplier = [Defaults(rollingPeriodMultiplier) floatValue];
	NSNumber *interval = [NSNumber numberWithFloat:(factor * multiplier)];
	SetDefaults(interval, rollingPeriodInterval);
}
- (IBAction)updateLimit:(id)sender {
	float factor = [Defaults(limitFactor) floatValue];
	float multiplier = [Defaults(limitMultiplier) floatValue];
	NSNumber *limit = [NSNumber numberWithFloat:(factor * multiplier)];
	SetDefaults(limit, limit);
	// limit affects threshold too
	[self updateThresholds:sender];
}
- (IBAction)updateThresholds:(id)sender {
	[[NSApp delegate] refreshThresholds];
}

#pragma mark -
#pragma mark landmark
- (IBAction)addLandmark:(id)sender
{
    if (!addLocationWindowController)
    {
        addLocationWindowController = [[AKAddLandmarkWindowController alloc] initWithWindowNibName:@"AKAddLandmarkWindow"];
    }
	addLocationWindowController.mode = AKAutomaticLocationMode;
	[NSApp beginSheet:addLocationWindowController.window
       modalForWindow:self.window
        modalDelegate:self
       didEndSelector:@selector(addLandmarkSheetDidEnd:returnCode:contextInfo:)
          contextInfo:nil];
}
- (void)addLandmarkSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if (NSCancelButton == returnCode) return;
    
	AKLandmark *landmark = [AKLandmark landmarkWithLandmark:addLocationWindowController.landmark];
    NSMutableArray *landmarks = [[[landmarkArrayController arrangedObjects] mutableCopy] autorelease];
	[landmarks addObject:landmark];
    SetDefaults([NSKeyedArchiver archivedDataWithRootObject:landmarks], landmarks);
}
- (IBAction)removeLandmark:(id)sender
{
    NSMutableArray *landmarks = [[[landmarkArrayController arrangedObjects] mutableCopy] autorelease];
    NSArray *selectedLandmarks = [landmarkArrayController selectedObjects];
	[landmarks removeObjectsInArray:selectedLandmarks];
    SetDefaults([NSKeyedArchiver archivedDataWithRootObject:landmarks], landmarks);

	// update warning text field on no landmarks added
    if ([landmarks count] == 0)
        [landmarksWarningTextField setTextColor:[NSColor redColor]];
    else
        [landmarksWarningTextField setTextColor:[NSColor darkGrayColor]];
}
- (IBAction)editLandmark:(id)sender
{
	NSArray *selectedLandmarks = [landmarkArrayController selectedObjects];
	if ([selectedLandmarks count] != 1) return;

	AKLandmark *landmark = [selectedLandmarks objectAtIndex:0];

	if (!addLocationWindowController)
	{
		addLocationWindowController = [[AKAddLandmarkWindowController alloc] initWithWindowNibName:@"AKAddLandmarkWindow"];
	}
	addLocationWindowController.mode = AKSpecifyLocationMode;
	addLocationWindowController.landmark = landmark;
	[NSApp beginSheet:addLocationWindowController.window
       modalForWindow:self.window
        modalDelegate:self
       didEndSelector:@selector(editLocationSheetDidEnd:returnCode:contextInfo:)
          contextInfo:nil];
}
- (void)editLocationSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (NSCancelButton == returnCode) return;

	[self removeLandmark:nil]; // remove selection
	[self addLandmarkSheetDidEnd:sheet returnCode:returnCode contextInfo:contextInfo]; // readd new
}

#pragma mark -
#pragma mark advanced

- (IBAction)clearStatistics:(id)sender {
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	[alert setMessageText:@"Clear statistics"];
	[alert setInformativeText:@"Are you sure you want to clear all statistics? All recent logs will be lost."];
	[alert setAlertStyle:NSInformationalAlertStyle];
	[alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(clearStatisticsAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}
- (void)clearStatisticsAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if (returnCode != NSAlertFirstButtonReturn) return;
	[[AKTrafficMonitorService sharedService] clearStatistics];
}

- (IBAction)resetAllPrefs:(id)sender{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	[alert setMessageText:@"Reset All Preferences"];
	[alert setInformativeText:@"Are you sure you want to reset your preferences?"];
	[alert setAlertStyle:NSInformationalAlertStyle];
	[alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(resetAllPrefsAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}
- (void)resetAllPrefsAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if (returnCode != NSAlertFirstButtonReturn) return;
	[[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
    [interfacesTableView reloadData];
}

#pragma mark -
#pragma mark interfaces table view
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self.interfaces count];
}
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    // update warning text field on no interfaces selected
    BOOL setRed = YES;
    for (NSString *interface in self.includeInterfaces)
    {
        if ([self.interfaces containsObject:interface])
        {
            setRed = NO;
        }
    }
    if (setRed)
        [interfacesWarningTextField setTextColor:[NSColor redColor]];
    else
        [interfacesWarningTextField setTextColor:[NSColor darkGrayColor]];

    // cell settings
    NSString *interfaceName = [self.interfaces objectAtIndex:row];
    NSButtonCell *cell = [tableColumn dataCellForRow:row];
    [cell setTitle:interfaceName];
    BOOL state = [self.includeInterfaces containsObject:interfaceName];
    NSNumber *stateVal = [NSNumber numberWithInteger:state?NSOnState:NSOffState];
    return stateVal;
}
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *interfaceName = [self.interfaces objectAtIndex:row];
    if (!self.includeInterfaces)
    {
        self.includeInterfaces = [[[NSArray alloc] init] autorelease];
    }
    NSMutableArray *newInterfaces = [[self.includeInterfaces mutableCopy] autorelease];
    if ([object intValue] == NSOnState)
    {
        [newInterfaces addObject:interfaceName];
    }
    else
    {
        [newInterfaces removeObject:interfaceName];
    }
    SetDefaults(newInterfaces, includeInterfaces);
}

#pragma mark -
#pragma mark private
- (void)_selectPane:(NSString *)pane {
	[pToolbar setSelectedItemIdentifier:pane];
	[self didSelectToolbarItem:pane];
}

#pragma mark -
#pragma mark synthesize
@synthesize interfaces = _interfaces;
@synthesize includeInterfaces = _includeInterfaces;
@end
