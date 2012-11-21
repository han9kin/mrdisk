/*
 *  NSURL+Additions.m
 *  MrDisk
 *
 *  Created by han9kin on 2011-05-23.
 *
 */

#import "NSURL+Additions.h"


@implementation NSURL (Additions)


- (NSString *)stringWithoutPath
{
    NSString        *sScheme   = [self scheme];
    NSString        *sHost     = [self host];
    NSNumber        *sPort     = [self port];
    NSString        *sUsername = [self user];
    NSMutableString *sString   = [NSMutableString string];

    if (sScheme)
    {
        [sString appendFormat:@"%@://", sScheme];
    }

    if (sUsername)
    {
        [sString appendString:sUsername];
    }

    if (sHost)
    {
        if ([sUsername length])
        {
            [sString appendString:@"@"];
        }

        [sString appendString:sHost];
    }

    if (sPort)
    {
        [sString appendFormat:@":%@", sPort];
    }

    return sString;
}


@end
