/*
 *  FileSystem.h
 *  MrDisk
 *
 *  Created by han9kin on 2011-05-23.
 *
 */

#import <Cocoa/Cocoa.h>


extern NSString *FSOptionPath;
extern NSString *FSOptionEncoding;


@interface FileSystem : NSObject
{
    NSString     *mName;
    NSURL        *mURL;
    NSDictionary *mOptions;
}


+ (const NSStringEncoding *)availableFilenameEncodings;


- (NSString *)name;
- (void)setName:(NSString *)aName;

- (NSURL *)url;
- (void)setURL:(NSURL *)aURL;

- (NSDictionary *)options;
- (void)setOptions:(NSDictionary *)aOptions;


- (BOOL)isMounted;
- (NSString *)mountPoint;
- (void)mount;
- (void)unmount;

- (void)revealInFinder;
- (void)addToSidebar;


@end
