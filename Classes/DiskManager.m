/*
 *  DiskManager.m
 *  MrDisk
 *
 *  Created by han9kin on 2011-05-23.
 *
 */

#import "ObjCUtil.h"
#import "NSURL+Additions.h"
#import "Keychain.h"
#import "DiskManager.h"
#import "SSHFileSystem.h"


@interface DiskManager (Private)
@end


@implementation DiskManager (Private)


- (void)loadDisks
{
    NSArray *sDisks = [[NSUserDefaults standardUserDefaults] arrayForKey:@"disks"];

    for (NSDictionary *sInfo in sDisks)
    {
        if ([sInfo isKindOfClass:[NSDictionary class]])
        {
            NSString *sName = [sInfo objectForKey:@"name"];
            NSURL    *sURL  = [NSURL URLWithString:[sInfo objectForKey:@"url"]];

            if ([sName length] && sURL)
            {
                FileSystem *sFileSystem;

                sFileSystem = [[SSHFileSystem alloc] initWithServer:mServer];
                [sFileSystem setName:sName];
                [sFileSystem setURL:sURL];
                [sFileSystem setOptions:[sInfo objectForKey:@"options"]];
                [mFileSystems addObject:sFileSystem];
                [sFileSystem release];
            }
        }
    }
}


- (void)saveDisks
{
    NSMutableArray *sDisks = [NSMutableArray array];

    for (FileSystem *sFileSystem in mFileSystems)
    {
        NSMutableDictionary *sInfo = [NSMutableDictionary dictionary];

        [sInfo setObject:[sFileSystem name] forKey:@"name"];
        [sInfo setObject:[[sFileSystem url] absoluteString] forKey:@"url"];
        [sInfo setObject:[sFileSystem options] forKey:@"options"];
        [sDisks addObject:sInfo];
    }

    [[NSUserDefaults standardUserDefaults] setObject:sDisks forKey:@"disks"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


- (NSString *)urlStringFromFieldValues
{
    NSString        *sHost     = [mHostField stringValue];
    NSString        *sPort     = [mPortField stringValue];
    NSString        *sUsername = [mUsernameField stringValue];
    NSString        *sPath     = [mPathField stringValue];
    NSMutableString *sURL      = [NSMutableString string];

    [sURL appendString:@"sftp://"];

    if ([sUsername length])
    {
        [sURL appendString:sUsername];
    }

    if ([sHost length])
    {
        if ([sUsername length])
        {
            [sURL appendString:@"@"];
        }

        [sURL appendString:sHost];
    }

    if ([sPort length])
    {
        [sURL appendFormat:@":%@", sPort];
    }

    if ([sPath hasPrefix:@"/"])
    {
        [sURL appendString:sPath];
    }

    return sURL;
}


- (void)updateURLField
{
    [mURLField setStringValue:[self urlStringFromFieldValues]];
}


- (void)updateBasicInfoFields
{
    NSURL *sURL = [NSURL URLWithString:[mURLField stringValue]];

    if (sURL)
    {
        [mHostField setObjectValue:[sURL host]];
        [mPortField setObjectValue:[sURL port]];
        [mUsernameField setObjectValue:[sURL user]];

        if ([sURL password])
        {
            [mPasswordField setObjectValue:[sURL password]];
        }

        if ([[sURL path] length])
        {
            [mPathField setObjectValue:[sURL path]];
        }
        else
        {
            if ([[mPathField stringValue] hasPrefix:@"/"])
            {
                [mPathField setObjectValue:[sURL path]];
            }
        }
    }
}


- (void)updateSaveButtonState
{
    if ([mNameField isEnabled] && [[mHostField stringValue] length] && [[mUsernameField stringValue] length])
    {
        [mSaveButton setEnabled:YES];
    }
    else
    {
        [mSaveButton setEnabled:NO];
    }
}


- (void)updateAvailableEncodingList
{
    const NSStringEncoding *sEncoding = [SSHFileSystem availableFilenameEncodings];

    [mEncodingPopUp removeAllItems];
    [mEncodingPopUp addItemWithTitle:@"utf-8 (mac)"];

    while (*sEncoding)
    {
        [mEncodingPopUp addItemWithTitle:(id)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(*sEncoding))];
        [[mEncodingPopUp lastItem] setTag:*sEncoding];

        sEncoding++;
    }
}


@end


@implementation DiskManager


@synthesize window        = mWindow;
@synthesize tableView     = mTableView;
@synthesize actionButton  = mActionButton;
@synthesize menu          = mMenu;
@synthesize editorWindow  = mEditorWindow;
@synthesize nameField     = mNameField;
@synthesize urlField      = mURLField;
@synthesize protocolPopUp = mProtocolPopUp;
@synthesize hostField     = mHostField;
@synthesize portField     = mPortField;
@synthesize usernameField = mUsernameField;
@synthesize passwordField = mPasswordField;
@synthesize pathField     = mPathField;
@synthesize encodingPopUp = mEncodingPopUp;
@synthesize saveButton    = mSaveButton;


SYNTHESIZE_SINGLETON_CLASS(DiskManager, sharedManager);


- (id)init
{
    self = [super init];

    if (self)
    {
        mServer      = [[MRFSServer alloc] init];
        mFileSystems = [[NSMutableArray alloc] init];

        [mServer setServerName:@"MrDisk"];
        [mServer setShowsMountedVolumesOnly:YES];

        [self loadDisks];
    }

    return self;
}


- (void)dealloc
{
    [mFileSystems release];
    [mServer release];
    [super dealloc];
}


- (BOOL)start:(NSError **)aError
{
    return [mServer start:aError];
}


- (void)stop
{
    [mServer stop];
}


- (void)showWindow
{
    if (!mWindow)
    {
        if (![NSBundle loadNibNamed:@"DiskManager" owner:self])
        {
            NSLog(@"DiskManager nib loading failed");
            return;
        }

        [mWindow setMovableByWindowBackground:YES];
        [mTableView setTarget:self];
        [mTableView setDoubleAction:@selector(mount:)];

        for (NSMenuItem *sMenuItem in [mMenu itemArray])
        {
            [[mActionButton menu] addItem:[[sMenuItem copy] autorelease]];
        }

        [self updateAvailableEncodingList];
    }

    [mWindow makeKeyAndOrderFront:nil];
}


#pragma mark -
#pragma mark Interface Actions


- (BOOL)validateMenuItem:(NSMenuItem *)aMenuItem
{
    if (([aMenuItem menu] == mMenu) || ([aMenuItem menu] == [mActionButton menu]))
    {
        NSInteger sIndex = [mTableView selectedRow];

        if ((sIndex >= 0) && (sIndex < [mFileSystems count]))
        {
            FileSystem *sFileSystem = [mFileSystems objectAtIndex:sIndex];
            SEL         sSelector   = [aMenuItem action];

            if ((sSelector == @selector(revealInFinder:)) || (sSelector == @selector(addToSidebar:)) || (sSelector == @selector(unmount:)))
            {
                return [sFileSystem isMounted] ? YES : NO;
            }
            else if ((sSelector == @selector(mount:)) || (sSelector == @selector(remove:)))
            {
                return [sFileSystem isMounted] ? NO : YES;
            }
            else
            {
                return YES;
            }
        }
        else
        {
            return NO;
        }
    }
    else
    {
        return YES;
    }
}


- (IBAction)add:(id)aSender
{
    [mTableView deselectAll:self];

    [mNameField setEnabled:YES];
    [mURLField setEnabled:YES];
    [mProtocolPopUp setEnabled:YES];
    [mHostField setEnabled:YES];
    [mPortField setEnabled:YES];
    [mUsernameField setEnabled:YES];
    [mPasswordField setEnabled:YES];
    [mPathField setEnabled:YES];
    [mEncodingPopUp setEnabled:YES];

    [mNameField setObjectValue:nil];
    [mURLField setObjectValue:nil];
    [mPasswordField setObjectValue:nil];
    [mPathField setObjectValue:nil];
    [mEncodingPopUp selectItemAtIndex:0];
    [mSaveButton setTag:-1];
    [self updateBasicInfoFields];
    [self updateSaveButtonState];

    [mNameField selectText:self];
    [[NSApplication sharedApplication] beginSheet:mEditorWindow modalForWindow:mWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}


- (IBAction)revealInFinder:(id)aSender
{
    NSInteger sIndex = [mTableView selectedRow];

    if ((sIndex >= 0) && (sIndex < [mFileSystems count]))
    {
        FileSystem *sFileSystem = [mFileSystems objectAtIndex:sIndex];

        if ([sFileSystem isMounted])
        {
            [sFileSystem revealInFinder];
        }
    }
}


- (IBAction)addToSidebar:(id)aSender
{
    NSInteger sIndex = [mTableView selectedRow];

    if ((sIndex >= 0) && (sIndex < [mFileSystems count]))
    {
        FileSystem *sFileSystem = [mFileSystems objectAtIndex:sIndex];

        if ([sFileSystem isMounted])
        {
            [sFileSystem addToSidebar];
        }
    }
}


- (IBAction)mount:(id)aSender
{
    NSInteger sIndex = [mTableView selectedRow];

    if ((sIndex >= 0) && (sIndex < [mFileSystems count]))
    {
        FileSystem *sFileSystem = [mFileSystems objectAtIndex:sIndex];

        if (![sFileSystem isMounted])
        {
            [sFileSystem mount];
        }
    }
}


- (IBAction)unmount:(id)aSender
{
    NSInteger sIndex = [mTableView selectedRow];

    if ((sIndex >= 0) && (sIndex < [mFileSystems count]))
    {
        FileSystem *sFileSystem = [mFileSystems objectAtIndex:sIndex];

        if ([sFileSystem isMounted])
        {
            [sFileSystem unmount];
        }
    }
}


- (IBAction)edit:(id)aSender
{
    NSInteger sIndex = [mTableView selectedRow];

    if ((sIndex >= 0) && (sIndex < [mFileSystems count]))
    {
        FileSystem *sFileSystem = [mFileSystems objectAtIndex:sIndex];

        if ([sFileSystem isMounted])
        {
            [mNameField setEnabled:NO];
            [mURLField setEnabled:NO];
            [mProtocolPopUp setEnabled:NO];
            [mHostField setEnabled:NO];
            [mPortField setEnabled:NO];
            [mUsernameField setEnabled:NO];
            [mPasswordField setEnabled:NO];
            [mPathField setEnabled:NO];
            [mEncodingPopUp setEnabled:NO];
        }
        else
        {
            [mNameField setEnabled:YES];
            [mURLField setEnabled:YES];
            [mProtocolPopUp setEnabled:YES];
            [mHostField setEnabled:YES];
            [mPortField setEnabled:YES];
            [mUsernameField setEnabled:YES];
            [mPasswordField setEnabled:YES];
            [mPathField setEnabled:YES];
            [mEncodingPopUp setEnabled:YES];
        }

        [mNameField setObjectValue:[sFileSystem name]];
        [mURLField setObjectValue:[[sFileSystem url] absoluteString]];
        [mPasswordField setObjectValue:[Keychain passwordForUsername:[[sFileSystem url] stringWithoutPath] service:@"MrDisk" error:NULL]];
        [mPathField setObjectValue:[[sFileSystem options] objectForKey:FSOptionPath]];
        [mEncodingPopUp selectItemWithTag:[[[sFileSystem options] objectForKey:FSOptionEncoding] unsignedIntegerValue]];
        [mSaveButton setTag:sIndex];
        [self updateBasicInfoFields];
        [self updateSaveButtonState];

        [mNameField selectText:self];
        [[NSApplication sharedApplication] beginSheet:mEditorWindow modalForWindow:mWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    }
}


- (IBAction)remove:(id)aSender
{
    NSInteger sIndex = [mTableView selectedRow];

    if ((sIndex >= 0) && (sIndex < [mFileSystems count]))
    {
        FileSystem *sFileSystem = [mFileSystems objectAtIndex:sIndex];

        if (![sFileSystem isMounted])
        {
            [mFileSystems removeObjectAtIndex:sIndex];
        }
    }

    [mTableView deselectAll:nil];
    [mTableView reloadData];
}


- (IBAction)cancelEditing:(id)aSender
{
    [[NSApplication sharedApplication] endSheet:mEditorWindow];
    [mEditorWindow orderOut:nil];
}


- (IBAction)saveEditing:(id)aSender
{
    NSInteger            sIndex   = [aSender tag];
    NSString            *sName    = [mNameField stringValue];
    NSURL               *sURL     = [NSURL URLWithString:[self urlStringFromFieldValues]];
    NSMutableDictionary *sOptions = [NSMutableDictionary dictionary];

    if ([[mPathField stringValue] length])
    {
        [sOptions setObject:[mPathField stringValue] forKey:FSOptionPath];
    }

    [sOptions setObject:[NSNumber numberWithUnsignedInteger:[[mEncodingPopUp selectedItem] tag]] forKey:FSOptionEncoding];

    if ([[sURL scheme] length] && [[sURL host] length] && [[sURL user] length])
    {
        if ((sIndex >= 0) && (sIndex < [mFileSystems count]))
        {
            FileSystem *sFileSystem = [mFileSystems objectAtIndex:sIndex];

            [Keychain deletePasswordForUsername:[[sFileSystem url] stringWithoutPath] service:@"MrDisk" error:NULL];

            if (![[sFileSystem name] isEqualToString:sName])
            {
                [sFileSystem setName:sName];
            }

            if (![[sFileSystem url] isEqual:sURL])
            {
                [sFileSystem setURL:sURL];
            }

            [sFileSystem setOptions:sOptions];

            if ([[mPasswordField stringValue] length])
            {
                NSError *sError;

                if (![Keychain setPassword:[mPasswordField stringValue] username:[sURL stringWithoutPath] service:@"MrDisk" error:&sError])
                {
                    NSLog(@"keychain error: %@", sError);
                }
            }

            [self saveDisks];
            [mTableView reloadData];
        }
        else
        {
            if (![sName length])
            {
                sName = [sURL host];
            }

            if ([[sURL scheme] isEqualToString:@"sftp"])
            {
                FileSystem *sFileSystem;

                if ([[mPasswordField stringValue] length])
                {
                    NSError *sError;

                    if (![Keychain setPassword:[mPasswordField stringValue] username:[sURL stringWithoutPath] service:@"MrDisk" error:&sError])
                    {
                        NSLog(@"keychain error: %@", sError);
                    }
                }

                sFileSystem = [[SSHFileSystem alloc] initWithServer:mServer];
                [sFileSystem setName:sName];
                [sFileSystem setURL:sURL];
                [sFileSystem setOptions:sOptions];
                [mFileSystems addObject:sFileSystem];
                [sFileSystem release];

                [self saveDisks];
                [mTableView reloadData];
            }
        }
    }

    [[NSApplication sharedApplication] endSheet:mEditorWindow];
    [mEditorWindow orderOut:nil];
}


#pragma mark -
#pragma mark NSControlDelegate


- (void)controlTextDidChange:(NSNotification *)aNotification
{
    NSTextField *sTextField = [aNotification object];

    if (sTextField == mURLField)
    {
        [self updateBasicInfoFields];
    }
    else if ([sTextField tag])
    {
        [self updateURLField];
    }

    [self updateSaveButtonState];
}


#pragma mark -
#pragma mark NSTableViewDataSource


- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [mFileSystems count];
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)aRowIndex
{
    return nil;
}


#pragma mark -
#pragma mark NSTableViewDelegate


- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)aIndex
{
    [aCell setRepresentedObject:[mFileSystems objectAtIndex:aIndex]];
}


- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    NSInteger sIndex = [mTableView selectedRow];

    if ((sIndex >= 0) && (sIndex < [mFileSystems count]))
    {
        [mActionButton setEnabled:YES];
    }
    else
    {
        [mActionButton setEnabled:NO];
    }
}


- (void)showActionInTableView:(NSTableView *)aTableView
{
    NSInteger sIndex = [mTableView selectedRow];

    if ((sIndex >= 0) && (sIndex < [mFileSystems count]))
    {
        [NSMenu popUpContextMenu:mMenu withEvent:[mWindow currentEvent] forView:mTableView];
    }
}


@end
