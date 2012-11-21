/*
 *  Keychain.m
 *  MrDisk
 *
 *  Created by han9kin on 2011-05-23.
 *
 */

#import "Keychain.h"


@implementation Keychain


+ (NSError *)errorWithStatus:(OSStatus)aStatus
{
    CFStringRef  sMessage = SecCopyErrorMessageString(aStatus, NULL);
    NSError     *sError;

    sError = [NSError errorWithDomain:@"KeychainErrorDomain" code:aStatus userInfo:[NSDictionary dictionaryWithObjectsAndKeys:(id)sMessage, NSLocalizedDescriptionKey, nil]];

    if (sMessage)
    {
        CFRelease(sMessage);
    }

    return sError;
}


+ (NSString *)passwordForUsername:(NSString *)aUsername service:(NSString *)aService error:(NSError **)aError
{
    const char *sUsername = [aUsername UTF8String];
    const char *sService  = [aService UTF8String];
    UInt32      sPasswordLength;
    void       *sPasswordData;
    OSStatus    sStatus;

    sStatus = SecKeychainFindGenericPassword(NULL, strlen(sService), sService, strlen(sUsername), sUsername, &sPasswordLength, &sPasswordData, NULL);

    if (sStatus == noErr)
    {
        NSString *sPassword = [[[NSString alloc] initWithBytes:sPasswordData length:sPasswordLength encoding:NSUTF8StringEncoding] autorelease];

        SecKeychainItemFreeContent(NULL, sPasswordData);

        return sPassword;
    }
    else
    {
        if (aError)
        {
            *aError = [self errorWithStatus:sStatus];
        }

        return nil;
    }
}


+ (BOOL)setPassword:(NSString *)aPassword username:(NSString *)aUsername service:(NSString *)aService error:(NSError **)aError
{
    NSAutoreleasePool  *sPool     = [[NSAutoreleasePool alloc] init];
    const char         *sService  = [aService UTF8String];
    const char         *sUsername = [aUsername UTF8String];
    const char         *sPassword = [aPassword UTF8String];
    SecKeychainItemRef  sItem     = NULL;
    OSStatus            sStatus;

    sStatus = SecKeychainFindGenericPassword(NULL, strlen(sService), sService, strlen(sUsername), sUsername, NULL, NULL, &sItem);

    if (sStatus == errSecItemNotFound)
    {
        const char               *sLabel    = [[NSString stringWithFormat:@"%@: %@", aService, aUsername] UTF8String];
        SecKeychainAttribute      sAttrs[]  = {
            { kSecLabelItemAttr,   strlen(sLabel),    (void *)sLabel    },
            { kSecAccountItemAttr, strlen(sUsername), (void *)sUsername },
            { kSecServiceItemAttr, strlen(sService),  (void *)sService  },
        };
        SecKeychainAttributeList  sAttrList = { 3, sAttrs };

        sStatus = SecKeychainItemCreateFromContent(kSecGenericPasswordItemClass, &sAttrList, strlen(sPassword), sPassword, NULL, NULL, NULL);
    }
    else if (sStatus == noErr)
    {
        sStatus = SecKeychainItemModifyAttributesAndData(sItem, NULL, strlen(sPassword), sPassword);
    }

    if (sItem)
    {
        CFRelease(sItem);
    }

    [sPool release];

    if (sStatus == noErr)
    {
        return YES;
    }
    else
    {
        if (aError)
        {
            *aError = [self errorWithStatus:sStatus];
        }

        return NO;
    }
}


+ (BOOL)deletePasswordForUsername:(NSString *)aUsername service:(NSString *)aService error:(NSError **)aError
{
    const char         *sUsername = [aUsername UTF8String];
    const char         *sService  = [aService UTF8String];
    SecKeychainItemRef  sItem     = NULL;
    OSStatus            sStatus;

    sStatus = SecKeychainFindGenericPassword(NULL, strlen(sService), sService, strlen(sUsername), sUsername, NULL, NULL, &sItem);

    if (sStatus == noErr)
    {
        sStatus = SecKeychainItemDelete(sItem);
    }

    if (sItem)
    {
        CFRelease(sItem);
    }

    if (sStatus == noErr)
    {
        return YES;
    }
    else
    {
        if (aError)
        {
            *aError = [self errorWithStatus:sStatus];
        }

        return NO;
    }
}


@end
