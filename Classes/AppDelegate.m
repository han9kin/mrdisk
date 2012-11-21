/*
 *  AppDelegate.m
 *  MrDisk
 *
 *  Created by han9kin on 2011-05-16.
 *
 */

#import "AppDelegate.h"
#import "DiskManager.h"


@implementation AppDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSError *sError;

    if (![[DiskManager sharedManager] start:&sError])
    {
        [[NSApplication sharedApplication] presentError:sError];
    }

    [[DiskManager sharedManager] showWindow];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [[DiskManager sharedManager] stop];
}


- (BOOL)applicationShouldHandleReopen:(NSApplication *)aApplication hasVisibleWindows:(BOOL)aFlag
{
    if (!aFlag)
    {
        [[DiskManager sharedManager] showWindow];
    }

    return YES;
}


@end
