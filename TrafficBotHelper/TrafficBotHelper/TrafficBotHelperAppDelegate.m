//
//  TrafficBotHelperAppDelegate.m
//  TrafficBotHelper
//
//  Created by Xitong Gao on 24/09/2011.
//  Copyright 2011 AK.Kloca. All rights reserved.
//

#import "TrafficBotHelperAppDelegate.h"
#include "BetterAuthorizationSampleLib.h"

@interface NSAttributedString (Hyperlink)
+(id)hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL;
@end
@implementation NSAttributedString (Hyperlink)
+(id)hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL
{
    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString: inString];
    NSRange range = NSMakeRange(0, [attrString length]);
    
    [attrString beginEditing];
    [attrString addAttribute:NSLinkAttributeName value:[aURL absoluteString] range:range];
    
    // make the text appear in blue
    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
    
    // next make the text appear with an underline
    [attrString addAttribute:
     NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSSingleUnderlineStyle] range:range];
    
    [attrString endEditing];
    
    return [attrString autorelease];
}
@end

@implementation TrafficBotHelperAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    OSStatus junk = AuthorizationCreate(NULL, NULL, kAuthorizationFlagDefaults, &_auth);
    assert(junk == noErr);
    assert(_auth != NULL);

    [_window setDelegate:self];

    NSURL* url = [NSURL URLWithString:@"http://admko.zzl.org"];
    NSMutableAttributedString* string = [[NSMutableAttributedString alloc] init];
    [string appendAttributedString: [NSAttributedString hyperlinkFromString:@"AK.Kloca" withURL:url]];
    [_linkTextField setAttributedStringValue:string];

    [_window center];
    [_window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}
- (void)windowWillClose:(NSNotification *)aNotification
{
    [NSApp terminate:self];
}
- (IBAction)install:(id)sender
{
    CFStringRef bundleID = (CFStringRef)[[NSBundle mainBundle] bundleIdentifier];
    BASFailCode failCode = BASDiagnoseFailure(_auth, bundleID);
    BASFixFailure(_auth, bundleID, CFSTR("TrafficBotHelperInstaller"), CFSTR("TrafficBotHelperDaemon"), failCode);
}

- (IBAction)uninstall:(id)sender
{
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:
                             @"do shell script \""
                              "launchctl unload -w /Library/LaunchDaemons/com.akkloca.TrafficBotHelper.plist; "
                              "rm /Library/LaunchDaemons/com.akkloca.TrafficBotHelper.plist; "
                              "rm /Library/PrivilegedHelperTools/com.akkloca.TrafficBotHelper\" "
                              "with administrator privileges"];
    [script executeAndReturnError:NULL];
    [script release];
}

@synthesize window=_window;
@end
