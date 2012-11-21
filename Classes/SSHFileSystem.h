/*
 *  SSHFileSystem.h
 *  MrDisk
 *
 *  Created by han9kin on 2011-05-17.
 *
 */

#import <Cocoa/Cocoa.h>
#import <MRFS/MRFS.h>
#import <libssh/sftp.h>
#import "FileSystem.h"


@interface SSHFileSystem : FileSystem <NSStreamDelegate, MRFSOperations>
{
    MRFSVolume    *mVolume;

    ssh_session    mSession;
    sftp_session   mSFTP;

    NSString      *mRemoteRoot;
    unsigned long  mRemoteUID;
    unsigned long  mRemoteGID;
    uid_t          mLocalUID;
    gid_t          mLocalGID;
    BOOL           mMapID;
    BOOL           mRemoteMAC;
}


- (id)initWithServer:(MRFSServer *)aServer;


@end
