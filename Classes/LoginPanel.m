/*
 *  LoginPanel.m
 *  MrDisk
 *
 *  Created by han9kin on 2011-06-08.
 *
 */

#import "ObjCUtil.h"
#import "LoginPanel.h"


@implementation LoginPanel


@synthesize window      = mWindow;
@synthesize titleField  = mTitleField;
@synthesize promptField = mPromptField;
@synthesize inputField  = mInputField;


SYNTHESIZE_SINGLETON_CLASS(LoginPanel, loginPanel);


- (id)init
{
    self = [super init];

    if (self)
    {
        [NSBundle loadNibNamed:@"LoginPanel" owner:self];
    }

    return self;
}


- (void)setServerInfo:(NSString *)aServerInfo
{
    [mTitleField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Login to %@", @""), aServerInfo]];
}


- (void)setPrompt:(NSString *)aPrompt
{
    [mPromptField setStringValue:([aPrompt length] ? aPrompt : NSLocalizedString(@"Password:", @""))];
}


- (NSString *)inputString
{
    return [mInputField stringValue];
}


- (NSInteger)runModal
{
    [mInputField setObjectValue:nil];

    return [[NSApplication sharedApplication] runModalForWindow:mWindow];
}


- (IBAction)ok:(id)aSender
{
    [[NSApplication sharedApplication] stopModalWithCode:NSOKButton];
    [mWindow orderOut:nil];
}


- (IBAction)cancel:(id)aSender;
{
    [[NSApplication sharedApplication] stopModalWithCode:NSCancelButton];
    [mWindow orderOut:nil];
}


@end
