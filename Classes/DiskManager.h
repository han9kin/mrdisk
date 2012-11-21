/*
 *  DiskManager.h
 *  MrDisk
 *
 *  Created by han9kin on 2011-05-23.
 *
 */

#import <Cocoa/Cocoa.h>
#import <MRFS/MRFS.h>


@interface DiskManager : NSObject
{
    NSWindow       *mWindow;
    NSTableView    *mTableView;
    NSPopUpButton  *mActionButton;
    NSMenu         *mMenu;

    NSWindow       *mEditorWindow;
    NSTextField    *mNameField;
    NSTextField    *mURLField;
    NSPopUpButton  *mProtocolPopUp;
    NSTextField    *mHostField;
    NSTextField    *mPortField;
    NSTextField    *mUsernameField;
    NSTextField    *mPasswordField;
    NSTextField    *mPathField;
    NSPopUpButton  *mEncodingPopUp;
    NSButton       *mSaveButton;

    MRFSServer     *mServer;
    NSMutableArray *mFileSystems;
}

@property(assign) IBOutlet NSWindow      *window;
@property(assign) IBOutlet NSTableView   *tableView;
@property(assign) IBOutlet NSPopUpButton *actionButton;
@property(assign) IBOutlet NSMenu        *menu;

@property(assign) IBOutlet NSWindow      *editorWindow;
@property(assign) IBOutlet NSTextField   *nameField;
@property(assign) IBOutlet NSTextField   *urlField;
@property(assign) IBOutlet NSPopUpButton *protocolPopUp;
@property(assign) IBOutlet NSTextField   *hostField;
@property(assign) IBOutlet NSTextField   *portField;
@property(assign) IBOutlet NSTextField   *usernameField;
@property(assign) IBOutlet NSTextField   *passwordField;
@property(assign) IBOutlet NSTextField   *pathField;
@property(assign) IBOutlet NSPopUpButton *encodingPopUp;
@property(assign) IBOutlet NSButton      *saveButton;


+ (DiskManager *)sharedManager;


- (BOOL)start:(NSError **)aError;
- (void)stop;


- (void)showWindow;


- (IBAction)add:(id)aSender;

- (IBAction)revealInFinder:(id)aSender;
- (IBAction)addToSidebar:(id)aSender;
- (IBAction)mount:(id)aSender;
- (IBAction)unmount:(id)aSender;
- (IBAction)edit:(id)aSender;
- (IBAction)remove:(id)aSender;

- (IBAction)cancelEditing:(id)aSender;
- (IBAction)saveEditing:(id)aSender;


@end
