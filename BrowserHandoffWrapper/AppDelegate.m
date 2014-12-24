//
//  AppDelegate.m
//  BrowserHandoffWrapper
//
//  Created by Lau Ching Jun on 12/25/14.
//  Copyright (c) 2014 chingjun. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSMenu *menu;
@property (strong, nonatomic) NSString *appToUse;
@property (assign, nonatomic) BOOL hideStatusBarIcon;

@end

static NSString * const kBundleIdKey = @"BundleIdForHandoffURL";
static NSString * const kHideStatusBarIcon = @"HideStatusBarIcon";

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // load settings
    self.appToUse = [[NSUserDefaults standardUserDefaults] stringForKey:kBundleIdKey] ?: @"com.apple.Safari";
    self.hideStatusBarIcon = [[NSUserDefaults standardUserDefaults] boolForKey:kHideStatusBarIcon];
    
    // setup URL handler
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
    
    NSString *myBundleId = [[NSBundle mainBundle] bundleIdentifier];
    
    // setup system bar menu
    if (!self.hideStatusBarIcon) {
        // setup system bar icon
        self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
        self.statusItem.image = [NSImage imageNamed:@"status-bar-icon"];
        self.statusItem.image.template = YES;
        
        NSMenu *menu = [[NSMenu alloc] initWithTitle:@"ChromeHandoffWrapper"];
        
        NSArray *array = [self URLOfAppsHandlingWebURLScheme];
        for (NSURL *url in array) {
            NSString *name = [[url lastPathComponent] stringByDeletingPathExtension];
            NSBundle *bundle = [NSBundle bundleWithURL:url];
            NSString *bundleId = [bundle bundleIdentifier];
            
            if ([bundleId isEqualToString:myBundleId]) {
                continue;
            }
            
            NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:url.path];
            
            NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:name action:@selector(appTapped:) keyEquivalent:@""];
            if (icon) {
                [icon setSize:NSMakeSize(16, 16)];
                menuItem.image = icon;
            }
            menuItem.representedObject = bundleId;
            [menu addItem:menuItem];
        }
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Hide icon" action:@selector(hideIcon:) keyEquivalent:@""]];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Install handler" action:@selector(setAsDefaultBrowser:) keyEquivalent:@""]];
        
        self.menu = menu;
        self.statusItem.menu = menu;
    }
    
    [self useApplication:self.appToUse];
}

- (void)appTapped:(id)sender {
    NSMenuItem *menuItem = sender;
    NSString *bundleId = menuItem.representedObject;
    
    [[NSUserDefaults standardUserDefaults] setObject:bundleId forKey:kBundleIdKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self useApplication:bundleId];
}

- (void)setAsDefaultBrowser:(id)sender {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    
    LSSetDefaultHandlerForURLScheme(CFSTR("http"), (__bridge CFStringRef)(bundleId));
    LSSetDefaultHandlerForURLScheme(CFSTR("https"), (__bridge CFStringRef)(bundleId));
    LSSetDefaultHandlerForURLScheme(CFSTR("ftp"), (__bridge CFStringRef)(bundleId));
}

- (void)hideIcon:(id)sender {
    //[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kHideStatusBarIcon];
    //[[NSUserDefaults standardUserDefaults] synchronize];
    
    self.statusItem = nil;
}

- (void)useApplication:(NSString *)bundleId {
    self.appToUse = bundleId;
    
    for (NSMenuItem *menuItem in self.menu.itemArray) {
        if ([menuItem.representedObject isKindOfClass:[NSString class]]) {
            menuItem.state = [menuItem.representedObject isEqualToString:bundleId]? NSOnState : NSOffState;
        }
    }
}

#pragma mark - Handle open URL and handoff

- (void)handleURLEvent:(NSAppleEventDescriptor*)event withReplyEvent:(NSAppleEventDescriptor*)replyEvent
{
    NSString* url = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    [self openURL:[NSURL URLWithString:url]];
}

- (BOOL)application:(NSApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray *))restorationHandler {
    if (userActivity.webpageURL) {
        [self openURL:userActivity.webpageURL];
    }
    
    return YES;
}

- (void)openURL:(NSURL *)url {
    [[NSWorkspace sharedWorkspace] openURLs:@[url] withAppBundleIdentifier:self.appToUse options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifiers:NULL];
}

#pragma mark - Applications that handle URL

- (NSArray *)URLOfAppsHandlingWebURLScheme {
    return CFBridgingRelease(LSCopyApplicationURLsForURL((__bridge CFURLRef)[NSURL URLWithString:@"http://example.com"], kLSRolesAll));
}

@end
