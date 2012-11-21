/*
 *  Keychain.h
 *  MrDisk
 *
 *  Created by han9kin on 2011-05-23.
 *
 */

#import <Cocoa/Cocoa.h>


@interface Keychain : NSObject
{

}


+ (NSString *)passwordForUsername:(NSString *)aUsername service:(NSString *)aService error:(NSError **)aError;
+ (BOOL)setPassword:(NSString *)aPassword username:(NSString *)aUsername service:(NSString *)aService error:(NSError **)aError;
+ (BOOL)deletePasswordForUsername:(NSString *)aUsername service:(NSString *)aService error:(NSError **)aError;


@end
