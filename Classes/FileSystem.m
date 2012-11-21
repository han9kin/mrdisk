/*
 *  FileSystem.m
 *  MrDisk
 *
 *  Created by han9kin on 2011-05-23.
 *
 */

#import "ObjCUtil.h"
#import "FileSystem.h"


NSString *FSOptionPath     = @"path";
NSString *FSOptionEncoding = @"encoding";


@implementation FileSystem


- (void)dealloc
{
    [mName release];
    [mURL release];
    [mOptions release];
    [super dealloc];
}


+ (const NSStringEncoding *)availableFilenameEncodings
{
    SubclassResponsibility();

    return NULL;
}


- (NSString *)name
{
    return mName;
}


- (void)setName:(NSString *)aName
{
    [mName autorelease];
    mName = [aName copy];
}


- (NSURL *)url
{
    return mURL;
}


- (void)setURL:(NSURL *)aURL
{
    [mURL autorelease];
    mURL = [aURL copy];
}


- (NSDictionary *)options
{
    return mOptions;
}


- (void)setOptions:(NSDictionary *)aOptions
{
    [mOptions release];
    mOptions = [aOptions copy];
}


- (BOOL)isMounted
{
    SubclassResponsibility();

    return NO;
}


- (NSString *)mountPoint
{
    SubclassResponsibility();

    return nil;
}


- (void)mount
{
    SubclassResponsibility();
}


- (void)unmount
{
    SubclassResponsibility();
}


- (void)revealInFinder
{
    if ([self isMounted])
    {
        [[NSWorkspace sharedWorkspace] selectFile:[self mountPoint] inFileViewerRootedAtPath:@""];
    }
}


- (void)addToSidebar
{
    if ([self isMounted])
    {
        NSURL *sMountURL = [NSURL fileURLWithPath:[self mountPoint]];

        if (sMountURL)
        {
            LSSharedFileListRef sVolumeList;

            sVolumeList = LSSharedFileListCreate(kCFAllocatorDefault, kLSSharedFileListFavoriteVolumes, NULL);

            if (sVolumeList)
            {
                UInt32                   sSeedValue;
                NSEnumerator            *sEnumerator;
                LSSharedFileListItemRef  sVolumeItem;
                BOOL                     sExist = NO;

                sEnumerator = [[NSMakeCollectable(LSSharedFileListCopySnapshot(sVolumeList, &sSeedValue)) autorelease] objectEnumerator];

                while ((sVolumeItem = (LSSharedFileListItemRef)[sEnumerator nextObject]))
                {
                    CFURLRef sURL    = NULL;
                    OSStatus sStatus = LSSharedFileListItemResolve(sVolumeItem, (kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes), &sURL, NULL);

                    if (sStatus == noErr)
                    {
                        if ([[NSMakeCollectable(sURL) autorelease] isEqual:sMountURL])
                        {
                            sExist = YES;
                            break;
                        }
                    }
                }

                if (!sExist)
                {
                    LSSharedFileListItemRef sVolumeItem;

                    sVolumeItem = LSSharedFileListInsertItemURL(sVolumeList, kLSSharedFileListItemLast, NULL, NULL, (CFURLRef)sMountURL, NULL, NULL);

                    if (sVolumeItem)
                    {
                        CFRelease(sVolumeItem);
                    }
                }

                CFRelease(sVolumeList);
            }
        }
    }
}


@end
