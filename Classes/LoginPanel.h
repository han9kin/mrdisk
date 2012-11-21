/*
 *  LoginPanel.h
 *  MrDisk
 *
 *  Created by han9kin on 2011-06-08.
 *
 */

#import <Cocoa/Cocoa.h>


@interface LoginPanel : NSObject
{
    NSWindow    *mWindow;
    NSTextField *mTitleField;
    NSTextField *mPromptField;
    NSTextField *mInputField;
}

@property(assign) IBOutlet NSWindow    *window;
@property(assign) IBOutlet NSTextField *titleField;
@property(assign) IBOutlet NSTextField *promptField;
@property(assign) IBOutlet NSTextField *inputField;


+ (LoginPanel *)loginPanel;


- (void)setServerInfo:(NSString *)aServerInfo;
- (void)setPrompt:(NSString *)aPrompt;

- (NSString *)inputString;


- (NSInteger)runModal;


- (IBAction)ok:(id)aSender;
- (IBAction)cancel:(id)aSender;


@end
