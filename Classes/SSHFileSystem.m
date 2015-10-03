/*
 *  SSHFileSystem.m
 *  MrDisk
 *
 *  Created by han9kin on 2011-05-17.
 *
 */

#import "NSURL+Additions.h"
#import "Keychain.h"
#import "LoginPanel.h"
#import "SSHFileSystem.h"


#define SSHFS_LOG 0


#define SSHFS_XFER_SIZE (60 * 1024)


static int32_t gTimeDiff    = 0;
static int32_t gDefaultTime = 0;


@interface SSHFileHandle : NSObject
{
    sftp_file mHandle;
}

- (id)initWithHandle:(sftp_file)aHandle;
- (sftp_file)handle;
- (BOOL)closeHandle;

@end


@implementation SSHFileHandle


- (id)initWithHandle:(sftp_file)aHandle
{
    self = [super init];

    if (self)
    {
        mHandle = aHandle;
    }

    return self;
}


- (void)dealloc
{
    if (mHandle)
    {
        sftp_close(mHandle);
    }
    [super dealloc];
}


- (sftp_file)handle
{
    return mHandle;
}


- (BOOL)closeHandle
{
    int sRet = sftp_close(mHandle);

    mHandle = NULL;

    return (sRet == SSH_NO_ERROR) ? YES : NO;
}


@end


@interface SSHFileSystem (SFTP)

- (BOOL)verify;
- (BOOL)authenticate;
- (void)printBanner;
- (void)connect;
- (void)disconnect;
- (int)posixError;
- (const char *)rootPath;
- (const char *)remotePath:(NSString *)aPath;

@end


@implementation SSHFileSystem (SFTP)


- (BOOL)verify
{
    return YES;
}


- (BOOL)authenticate
{
    NSString *sPassword;
    int       sMethod;
    int       sRet;

    if (!mSession)
    {
        return NO;
    }

    sPassword = [Keychain passwordForUsername:[[self url] stringWithoutPath] service:@"MrDisk" error:NULL];

    ssh_userauth_none(mSession, NULL);
    sMethod = ssh_userauth_list(mSession, NULL);

    if (sMethod & SSH_AUTH_METHOD_NONE)
    {
        sRet = ssh_userauth_none(mSession, NULL);

        if (sRet == SSH_AUTH_SUCCESS)
        {
#if SSHFS_LOG
            NSLog(@"authentication (none) success");
#endif
            return YES;
        }
        else
        {
#if SSHFS_LOG
            NSLog(@"authentication (none) failed: %d", sRet);
#endif
        }
    }

    if (sMethod & SSH_AUTH_METHOD_PUBLICKEY)
    {
        sRet = ssh_userauth_autopubkey(mSession, ([sPassword length] ? [sPassword UTF8String] : ""));

        if (sRet == SSH_AUTH_SUCCESS)
        {
#if SSHFS_LOG
            NSLog(@"authentication (publickey) success");
#endif
            return YES;
        }
        else
        {
#if SSHFS_LOG
            NSLog(@"authentication (publickey) failed: %d", sRet);
#endif
        }
    }

    if (sMethod & SSH_AUTH_METHOD_PASSWORD)
    {
        sRet = ssh_userauth_password(mSession, NULL, ([sPassword length] ? [sPassword UTF8String] : ""));

        if (sRet == SSH_AUTH_SUCCESS)
        {
#if SSHFS_LOG
            NSLog(@"authentication (password) success");
#endif
            return YES;
        }
        else
        {
#if SSHFS_LOG
            NSLog(@"authentication (password) failed: %d", sRet);
#endif
        }
    }

    if (sMethod & SSH_AUTH_METHOD_INTERACTIVE)
    {
        sRet = ssh_userauth_kbdint(mSession, NULL, NULL);

        while (sRet == SSH_AUTH_INFO)
        {
            const char *sName        = ssh_userauth_kbdint_getname(mSession);
            const char *sInstruction = ssh_userauth_kbdint_getinstruction(mSession);
            int         sPrompts     = ssh_userauth_kbdint_getnprompts(mSession);
            BOOL        sOK          = YES;

            if (strlen(sName))
            {
#if SSHFS_LOG
                NSLog(@"authentication (keyboard-interactive) name: %s", sName);
#endif
            }

            if (strlen(sInstruction))
            {
#if SSHFS_LOG
                NSLog(@"authentication (keyboard-interactive) instruction: %s", sInstruction);
#endif
            }

            for (int i = 0; i < sPrompts; i++)
            {
                const char *sPrompt = ssh_userauth_kbdint_getprompt(mSession, i, NULL);

                if ([[[NSString stringWithUTF8String:sPrompt] lowercaseString] hasSuffix:@"password:"])
                {
                    ssh_userauth_kbdint_setanswer(mSession, i, ([sPassword length] ? [sPassword UTF8String] : ""));
                }
                else
                {
#if SSHFS_LOG
                    NSLog(@"authentication (keyboard-interactive) unknown prompt: %s", sPrompt);
#endif
                    sOK = NO;
                }
            }

            if (sOK)
            {
                sRet = ssh_userauth_kbdint(mSession, NULL, NULL);
            }
            else
            {
                break;
            }
        }

        if (sRet == SSH_AUTH_SUCCESS)
        {
#if SSHFS_LOG
            NSLog(@"authentication (keyboard-interactive) success");
#endif
            return YES;
        }
        else
        {
#if SSHFS_LOG
            NSLog(@"authentication (keyboard-interactive) failed: %d", sRet);
#endif
        }
    }

    if (!sPassword)
    {
        if (sMethod & SSH_AUTH_METHOD_PASSWORD)
        {
            LoginPanel *sPanel = [LoginPanel loginPanel];

            [sPanel setServerInfo:[[self url] stringWithoutPath]];
            [sPanel setPrompt:nil];

            if (([sPanel runModal] == NSOKButton) && [[sPanel inputString] length])
            {
                sRet = ssh_userauth_password(mSession, NULL, [[sPanel inputString] UTF8String]);

                if (sRet == SSH_AUTH_SUCCESS)
                {
#if SSHFS_LOG
                    NSLog(@"authentication (password) success");
#endif
                    return YES;
                }
            }
        }
        else if (sMethod & SSH_AUTH_METHOD_INTERACTIVE)
        {
            sRet = ssh_userauth_kbdint(mSession, NULL, NULL);

            while (sRet == SSH_AUTH_INFO)
            {
                int  sPrompts = ssh_userauth_kbdint_getnprompts(mSession);
                BOOL sOK      = YES;

                for (int i = 0; i < sPrompts; i++)
                {
                    LoginPanel *sPanel  = [LoginPanel loginPanel];
                    const char *sPrompt = ssh_userauth_kbdint_getprompt(mSession, i, NULL);

                    [sPanel setServerInfo:[[self url] stringWithoutPath]];
                    [sPanel setPrompt:[NSString stringWithUTF8String:sPrompt]];

                    if ([sPanel runModal] == NSOKButton)
                    {
                        NSString *sInputString = [sPanel inputString];

                        ssh_userauth_kbdint_setanswer(mSession, i, ([sInputString length] ? [sInputString UTF8String] : ""));
                    }
                    else
                    {
                        sOK = NO;
                    }
                }

                if (sOK)
                {
                    sRet = ssh_userauth_kbdint(mSession, NULL, NULL);
                }
                else
                {
                    break;
                }
            }

            if (sRet == SSH_AUTH_SUCCESS)
            {
#if SSHFS_LOG
                NSLog(@"authentication (keyboard-interactive) success");
#endif
                return YES;
            }
            else
            {
#if SSHFS_LOG
                NSLog(@"authentication (keyboard-interactive) failed: %d", sRet);
#endif
            }
        }
    }

    NSLog(@"authentication failed");

    return NO;
}


- (void)printBanner
{
    char *sBanner = ssh_get_issue_banner(mSession);

    if (sBanner)
    {
        NSLog(@"%s", sBanner);

        ssh_string_free_char(sBanner);
    }
}


- (BOOL)getRemoteInfo
{
    char *sPath = sftp_canonicalize_path(mSFTP, [self rootPath]);

    if (sPath)
    {
        [mRemoteRoot autorelease];
        mRemoteRoot = [[NSString alloc] initWithUTF8String:sPath];

        free(sPath);
    }
    else
    {
        NSLog(@"Unable to get remote path for directory to mount (%s) (error=%d)", [self rootPath], sftp_get_error(mSFTP));

        return NO;
    }

    sftp_attributes sFileAttr;

    mRemoteUID = 0;
    mRemoteGID = 0;
    mLocalUID  = getuid();
    mLocalGID  = getgid();
    mMapID     = NO;

    sFileAttr = sftp_stat(mSFTP, ".");

    if (sFileAttr)
    {
        if (sFileAttr->flags & SSH_FILEXFER_ATTR_UIDGID)
        {
            mRemoteUID = sFileAttr->uid;
            mRemoteGID = sFileAttr->gid;
            mMapID     = YES;
        }

        sftp_attributes_free(sFileAttr);
    }

    return YES;
}


- (void)connect
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"connect");
#endif
        if (!mSession)
        {
            mSession = ssh_new();

            if (mSession)
            {
                int sPort = [[self url] port] ? [[[self url] port] intValue] : 22;
                int sRet;

                ssh_options_set(mSession, SSH_OPTIONS_HOST, [[[self url] host] UTF8String]);
                ssh_options_set(mSession, SSH_OPTIONS_PORT, &sPort);
                ssh_options_set(mSession, SSH_OPTIONS_USER, [[[self url] user] UTF8String]);

                sRet = ssh_connect(mSession);

                if (sRet == SSH_OK)
                {
#if SSHFS_LOG
                    NSLog(@"ssh protocol version: %d", ssh_get_version(mSession));
                    NSLog(@"openssh server version: %d", ssh_get_openssh_version(mSession));
#endif
                }
                else
                {
                    NSLog(@"ssh_connect() error: %s", ssh_get_error(mSession));
                    ssh_free(mSession);
                    mSession = NULL;
                }
            }
            else
            {
                NSLog(@"ssh_new() failed");
                return;
            }

            if (![self verify])
            {
                [self disconnect];
                return;
            }

            if (![self authenticate])
            {
                [[NSApplication sharedApplication] presentError:[NSError errorWithDomain:@"AppDomain" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:NSLocalizedString(@"Login to %@ failed", @""), [[self url] stringWithoutPath]], NSLocalizedDescriptionKey, nil]]];
                [self disconnect];
                return;
            }

            [self printBanner];

            mSFTP = sftp_new(mSession);

            if (mSFTP)
            {
                int sRet = sftp_init(mSFTP);

                if (sRet == SSH_OK)
                {
#if SSHFS_LOG
                    int sCount = sftp_extensions_get_count(mSFTP);

                    NSLog(@"sftp protocol version: %d", sftp_server_version(mSFTP));

                    for (int i = 0; i < sCount; i++)
                    {
                        NSLog(@"sftp extension [%s] = %s", sftp_extensions_get_name(mSFTP, i), sftp_extensions_get_data(mSFTP, i));
                    }
#endif
                }
                else
                {
                    NSLog(@"sftp_init() failed: %d", sftp_get_error(mSFTP));
                    [self disconnect];
                    return;
                }

                if (![self getRemoteInfo])
                {
                    [self disconnect];
                    return;
                }
            }
            else
            {
                NSLog(@"sftp_new() failed: %s", ssh_get_error(mSession));
                [self disconnect];
                return;
            }

            [mVolume mountAtPath:nil];
        }
    }
}


- (void)disconnect
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"disconnect");
#endif
        if (mSFTP)
        {
            sftp_free(mSFTP);
            mSFTP = NULL;
        }

        if (mSession)
        {
            ssh_disconnect(mSession);
            ssh_free(mSession);
            mSession = NULL;
        }
    }
}


- (int)posixError
{
    unsigned long sSFTPError = sftp_get_error(mSFTP);
    int           sPosixError;

    switch (sSFTPError)
    {
        case SSH_FX_OK:
            NSLog(@"sftp error = 0; ssh error: %s", ssh_get_error(mSession));
            sPosixError = EIO;
            break;
        case SSH_FX_EOF:
            sPosixError = 0;
            break;
        case SSH_FX_NO_SUCH_FILE:
            sPosixError = ENOENT;
            break;
        case SSH_FX_PERMISSION_DENIED:
            sPosixError = EACCES;
            break;
        case SSH_FX_FAILURE:
            sPosixError = EINVAL;
            break;
        case SSH_FX_BAD_MESSAGE:
            sPosixError = EIO;
            break;
        case SSH_FX_NO_CONNECTION:
            sPosixError = ENOTCONN;
            break;
        case SSH_FX_CONNECTION_LOST:
            sPosixError = ECONNRESET;
            break;
        case SSH_FX_OP_UNSUPPORTED:
            sPosixError = ENOTSUP;
            break;
        case SSH_FX_INVALID_HANDLE:
            sPosixError = EBADF;
            break;
        case SSH_FX_NO_SUCH_PATH:
            sPosixError = ENOENT;
            break;
        case SSH_FX_FILE_ALREADY_EXISTS:
            sPosixError = EEXIST;
            break;
        case SSH_FX_WRITE_PROTECT:
            sPosixError = EROFS;
            break;
        case SSH_FX_NO_MEDIA:
            sPosixError = ENXIO;
            break;
        default:
            sPosixError = EIO;
            break;
    }

    return sPosixError;
}


- (const char *)rootPath
{
    if ([mRemoteRoot length])
    {
        if (mRemoteMAC)
        {
            return [mRemoteRoot fileSystemRepresentation];
        }
        else
        {
            return [[mRemoteRoot precomposedStringWithCanonicalMapping] UTF8String];
        }
    }
    else
    {
        return ".";
    }
}


- (const char *)remotePath:(NSString *)aPath
{
    if (mRemoteMAC)
    {
        return [[mRemoteRoot stringByAppendingPathComponent:aPath] fileSystemRepresentation];
    }
    else
    {
        return [[[mRemoteRoot stringByAppendingPathComponent:aPath] precomposedStringWithCanonicalMapping] UTF8String];
    }
}


@end


@implementation SSHFileSystem


+ (void)initialize
{
    if (!gTimeDiff)
    {
        NSDate *sDate = [NSDate date];

        gTimeDiff = (int32_t)[sDate timeIntervalSince1970] - (int32_t)[sDate timeIntervalSinceReferenceDate];
    }

    if (!gDefaultTime)
    {
        gDefaultTime = [NSDate timeIntervalSinceReferenceDate];
    }
}


- (id)initWithServer:(MRFSServer *)aServer
{
    self = [super init];

    if (self)
    {
        mVolume = [[MRFSVolume alloc] initWithServer:aServer];
        [mVolume setDelegate:self];
    }

    return self;
}


- (void)dealloc
{
    [mVolume release];
    [mRemoteRoot release];
    [self disconnect];
    [super dealloc];
}


+ (const NSStringEncoding *)availableFilenameEncodings
{
    static const NSStringEncoding sEncodings[] = {
        NSUTF8StringEncoding,
        0
    };

    return sEncodings;
}


- (void)setName:(NSString *)aName
{
    if ([mVolume setVolumeName:aName])
    {
        [super setName:aName];
    }
}


- (void)setURL:(NSURL *)aURL
{
    if (!mRemoteRoot && [[aURL path] length])
    {
        mRemoteRoot = [[aURL path] copy];
    }

    [super setURL:aURL];
}


- (void)setOptions:(NSDictionary *)aOptions
{
    NSString *sPath = [aOptions objectForKey:FSOptionPath];

    if ([sPath length])
    {
        [mRemoteRoot autorelease];
        mRemoteRoot = [sPath copy];
    }

    mRemoteMAC = [[aOptions objectForKey:FSOptionEncoding] unsignedIntegerValue] ? NO : YES;

    [super setOptions:aOptions];
}


- (BOOL)isMounted
{
    return [mVolume isMounted];
}


- (NSString *)mountPoint
{
    return [mVolume isMounted] ? [mVolume mountPoint] : nil;
}


- (void)mount
{
    if (![mVolume isMounted])
    {
        [self connect];
    }
}


- (void)unmount
{
    if ([mVolume isMounted])
    {
        [mVolume unmount];
    }
}


#pragma mark -
#pragma mark MRFSOperations


- (void)volume:(MRFSVolume *)aVolume mountDidFinishAtPath:(NSString *)aMountPoint
{
    NSLog(@"volume mounted at %@", aMountPoint);
}


- (void)volume:(MRFSVolume *)aVolume mountDidFailWithError:(NSError *)aError
{
    NSLog(@"volume mount failed: %@", aError);

    [self disconnect];
    [[NSApplication sharedApplication] presentError:aError];
}


- (void)volume:(MRFSVolume *)aVolume unmountDidFinishAtPath:(NSString *)aMountPoint
{
    NSLog(@"volume unmounted at %@", aMountPoint);

    [self disconnect];
}


- (void)volume:(MRFSVolume *)aVolume unmountDidFailWithError:(NSError *)aError
{
    NSLog(@"volume unmount failed: %@", aError);

    [[NSApplication sharedApplication] presentError:aError];
}


- (void)fillFileStat:(MRFSFileStat *)aFileStat fromFileAttr:(sftp_attributes)aFileAttr
{
    if (aFileAttr->flags & SSH_FILEXFER_ATTR_CREATETIME)
    {
        aFileStat->creationDate = aFileAttr->createtime - gTimeDiff;
    }
    else if (aFileAttr->flags & SSH_FILEXFER_ATTR_ACMODTIME)
    {
        aFileStat->creationDate = aFileAttr->mtime - gTimeDiff;
    }
    else
    {
        aFileStat->creationDate = gDefaultTime;
    }

    if (aFileAttr->flags & SSH_FILEXFER_ATTR_MODIFYTIME)
    {
        aFileStat->modificationDate = aFileAttr->mtime - gTimeDiff;
    }
    else if (aFileAttr->flags & SSH_FILEXFER_ATTR_ACMODTIME)
    {
        aFileStat->modificationDate = aFileAttr->mtime - gTimeDiff;
    }
    else
    {
        aFileStat->modificationDate = gDefaultTime;
    }


    if ((aFileAttr->flags & SSH_FILEXFER_ATTR_UIDGID) && mMapID)
    {
        aFileStat->userID  = (aFileAttr->uid == mRemoteUID) ? mLocalUID : aFileAttr->uid;
        aFileStat->groupID = (aFileAttr->gid == mRemoteGID) ? mLocalGID : aFileAttr->gid;
    }
    else
    {
        aFileStat->userID  = mLocalUID;
        aFileStat->groupID = mLocalGID;
    }

    if (aFileAttr->flags & SSH_FILEXFER_ATTR_PERMISSIONS)
    {
        aFileStat->mode = aFileAttr->permissions;
    }
    else
    {
        aFileStat->mode = S_IRUSR;
    }

    if (aFileAttr->type == SSH_FILEXFER_TYPE_REGULAR)
    {
        aFileStat->mode |= S_IFREG;
    }
    else if (aFileAttr->type == SSH_FILEXFER_TYPE_DIRECTORY)
    {
        aFileStat->mode |= S_IFDIR;
    }
    else if (aFileAttr->type == SSH_FILEXFER_TYPE_SYMLINK)
    {
        aFileStat->mode |= S_IFLNK;
    }
    else if (aFileAttr->type == SSH_FILEXFER_TYPE_SPECIAL)
    {
        aFileStat->mode |= S_IFBLK;
    }
    else
    {
        aFileStat->mode |= S_IFSOCK;
    }

    if (aFileAttr->flags & SSH_FILEXFER_ATTR_SIZE)
    {
        aFileStat->size = aFileAttr->size;
    }
    else
    {
        aFileStat->size = 0;
    }
}


- (void)fillFileAttr:(sftp_attributes)aFileAttr fromFileStat:(MRFSFileStat *)aFileStat bitmap:(int)aBitmap
{
    aFileAttr->flags = 0;

    if (aBitmap & kMRFSFileCreationDateBit)
    {
        aFileAttr->createtime = aFileStat->creationDate + gTimeDiff;
        aFileAttr->flags |= SSH_FILEXFER_ATTR_CREATETIME;
    }

    if (aBitmap & kMRFSFileModificationDateBit)
    {
        aFileAttr->atime = aFileStat->modificationDate + gTimeDiff;
        aFileAttr->mtime = aFileStat->modificationDate + gTimeDiff;
        aFileAttr->flags |= SSH_FILEXFER_ATTR_ACMODTIME | SSH_FILEXFER_ATTR_MODIFYTIME;
    }

    if ((aBitmap & kMRFSFileUserIDBit) && (aBitmap & kMRFSFileGroupIDBit) && mMapID)
    {
        aFileAttr->uid = (aFileStat->userID == mLocalUID) ? mRemoteUID : aFileStat->userID;
        aFileAttr->gid = (aFileStat->groupID == mLocalGID) ? mRemoteGID : aFileStat->groupID;
        aFileAttr->flags |= SSH_FILEXFER_ATTR_UIDGID;
    }

    if (aBitmap & kMRFSFileModeBit)
    {
        aFileAttr->permissions = aFileStat->mode & (S_IRWXU | S_IRWXG | S_IRWXO);
        aFileAttr->flags |= SSH_FILEXFER_ATTR_PERMISSIONS;
    }
}


- (int)getVolumeStat:(MRFSVolumeStat *)aVolumeStat
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"statvfs");
#endif
        if (mSFTP)
        {
            sftp_statvfs_t sVolumeStat;

            sVolumeStat = sftp_statvfs(mSFTP, [self rootPath]);

            if (sVolumeStat)
            {
                aVolumeStat->blockSize = sVolumeStat->f_bsize;
                aVolumeStat->totalSize = sVolumeStat->f_blocks * sVolumeStat->f_frsize;
                aVolumeStat->freeSize  = sVolumeStat->f_bavail * sVolumeStat->f_frsize;

                sftp_statvfs_free(sVolumeStat);

                return 0;
            }
            else
            {
                return [self posixError];
            }
        }
        else
        {
            return ENXIO;
        }
    }
}


- (int)getFileStat:(MRFSFileStat *)aFileStat ofItemAtPath:(NSString *)aPath
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"lstat %@", aPath);
#endif
        if (mSFTP)
        {
            sftp_attributes sFileAttr;

            sFileAttr = sftp_lstat(mSFTP, [self remotePath:aPath]);

            if (sFileAttr)
            {
                [self fillFileStat:aFileStat fromFileAttr:sFileAttr];

                sftp_attributes_free(sFileAttr);

                return 0;
            }
            else
            {
                return [self posixError];
            }
        }
        else
        {
            return ENXIO;
        }
    }
}


- (int)getOffspringNames:(NSArray **)aOffspringNames fileStats:(NSArray **)aFileStats ofDirectoryAtPath:(NSString *)aPath
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"readdir %@", aPath);
#endif
        if (mSFTP)
        {
            sftp_dir         sHandle;
            sftp_attributes  sFileAttr;
            MRFSFileStat     sFileStat;
            NSMutableArray  *sNames;
            NSMutableArray  *sFileStats;
            int              sResult;

            sHandle = sftp_opendir(mSFTP, [self remotePath:aPath]);

            if (!sHandle)
            {
                return [self posixError];
            }

            sNames     = [NSMutableArray array];
            sFileStats = [NSMutableArray array];

            while ((sFileAttr = sftp_readdir(mSFTP, sHandle)) != NULL)
            {
                NSString *sName = [NSString stringWithUTF8String:sFileAttr->name];

                if (sName)
                {
                    if (![sName isEqualToString:@"."] && ![sName isEqualToString:@".."])
                    {
                        [self fillFileStat:&sFileStat fromFileAttr:sFileAttr];

                        [sNames addObject:[NSString stringWithUTF8String:[sName fileSystemRepresentation]]];
                        [sFileStats addObject:[NSData dataWithBytes:&sFileStat length:sizeof(sFileStat)]];
                    }
                }
                else
                {
                    NSLog(@"filename encoding failed while listing: %s", sFileAttr->name);
                }

                sftp_attributes_free(sFileAttr);
            }

            if (sftp_dir_eof(sHandle))
            {
                *aOffspringNames = sNames;
                *aFileStats      = sFileStats;

                sResult = 0;
            }
            else
            {
                sResult = [self posixError];
            }

            sftp_closedir(sHandle);

            return sResult;
        }
        else
        {
            return ENXIO;
        }
    }
}


- (int)openFileAtPath:(NSString *)aPath accessMode:(int16_t)aAccessMode userData:(id *)aUserData
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"open %@ (%#hx)", aPath, aAccessMode);
#endif
        if (mSFTP)
        {
            sftp_file sHandle;
            int       sFlags;

            if ((aAccessMode & kMRFSFileRead) && (aAccessMode & kMRFSFileWrite))
            {
                sFlags = O_RDWR | O_NOFOLLOW;
            }
            else if (aAccessMode & kMRFSFileWrite)
            {
                sFlags = O_WRONLY | O_NOFOLLOW;
            }
            else
            {
                sFlags = O_RDONLY | O_NOFOLLOW;
            }

            sHandle = sftp_open(mSFTP, [self remotePath:aPath], sFlags, 0);

            if (sHandle)
            {
                *aUserData = [[[SSHFileHandle alloc] initWithHandle:sHandle] autorelease];

                return 0;
            }
            else
            {
                return [self posixError];
            }
        }
        else
        {
            return ENXIO;
        }
    }
}


- (int)closeFileAtPath:(NSString *)aPath userData:(id)aUserData
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"close %@", aPath);
#endif
        if (mSFTP)
        {
            if ([aUserData closeHandle])
            {
                return 0;
            }
            else
            {
                return EIO;
            }
        }
        else
        {
            return ENXIO;
        }
    }
}


- (int)readFileAtPath:(NSString *)aPath buffer:(void *)aBuffer size:(int64_t)aSize offset:(int64_t)aOffset returnedSize:(int64_t *)aReturnedSize userData:(id)aUserData
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"read %@ (%lld, %lld)", aPath, aSize, aOffset);
#endif
        if (mSFTP)
        {
            sftp_file sHandle = [aUserData handle];
            int64_t   sLength = 0;
            int       sResult = 0;

            if (sftp_seek64(sHandle, aOffset))
            {
                return [self posixError];
            }

            while (sLength < aSize)
            {
                ssize_t sRet = sftp_read(sHandle, (char *)aBuffer + sLength, MIN(aSize - sLength, SSHFS_XFER_SIZE));

                if (sRet < 0)
                {
                    if (!sLength)
                    {
                        sResult = [self posixError];
                    }

                    break;
                }
                else if (sRet == 0)
                {
                    break;
                }
                else
                {
                    sLength += sRet;
                }
            }

            *aReturnedSize = sLength;

            return sResult;
        }
        else
        {
            return ENXIO;
        }
    }
}


- (int)setFileStat:(MRFSFileStat *)aFileStat bitmap:(int)aBitmap ofItemAtPath:(NSString *)aPath
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"setstat %@", aPath);
#endif
        if (mSFTP)
        {
            struct sftp_attributes_struct sFileAttr;
            int                           sRet;

            memset(&sFileAttr, 0, sizeof(sFileAttr));

            [self fillFileAttr:&sFileAttr fromFileStat:aFileStat bitmap:aBitmap];

            if (sFileAttr.flags)
            {
                sRet = sftp_setstat(mSFTP, [self remotePath:aPath], &sFileAttr);

                if (sRet)
                {
                    return [self posixError];
                }
            }

            return 0;
        }
        else
        {
            return ENXIO;
        }
    }
}


- (int)createDirectoryAtPath:(NSString *)aPath
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"mkdir %@", aPath);
#endif
        if (mSFTP)
        {
            int sRet;

            sRet = sftp_mkdir(mSFTP, [self remotePath:aPath], 0755);

            if (sRet)
            {
                return [self posixError];
            }
            else
            {
                return 0;
            }
        }
        else
        {
            return ENXIO;
        }
    }
}


- (int)createFileAtPath:(NSString *)aPath
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"creat %@", aPath);
#endif
        if (mSFTP)
        {
            sftp_file sHandle;

            sHandle = sftp_open(mSFTP, [self remotePath:aPath], (O_WRONLY | O_CREAT | O_EXCL), 0644);

            if (sHandle)
            {
                sftp_close(sHandle);

                return 0;
            }
            else
            {
                return [self posixError];
            }
        }
        else
        {
            return ENXIO;
        }
    }
}


- (int)removeDirectoryAtPath:(NSString *)aPath
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"rmdir %@", aPath);
#endif
        if (mSFTP)
        {
            int sRet;

            sRet = sftp_rmdir(mSFTP, [self remotePath:aPath]);

            if (sRet)
            {
                return [self posixError];
            }
            else
            {
                return 0;
            }
        }
        else
        {
            return ENXIO;
        }
    }
}


- (int)removeFileAtPath:(NSString *)aPath
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"unlink %@", aPath);
#endif
        if (mSFTP)
        {
            int sRet;

            sRet = sftp_unlink(mSFTP, [self remotePath:aPath]);

            if (sRet)
            {
                return [self posixError];
            }
            else
            {
                return 0;
            }
        }
        else
        {
            return ENXIO;
        }
    }
}


- (int)moveItemAtPath:(NSString *)aSourcePath toPath:(NSString *)aDestinationPath
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"rename %@ -> %@", aSourcePath, aDestinationPath);
#endif
        if (mSFTP)
        {
            int sRet;

            sRet = sftp_rename(mSFTP, [self remotePath:aSourcePath], [self remotePath:aDestinationPath]);

            if (sRet)
            {
                return [self posixError];
            }
            else
            {
                return 0;
            }
        }
        else
        {
            return ENXIO;
        }
    }
}


- (int)writeFileAtPath:(NSString *)aPath buffer:(const void *)aBuffer size:(int64_t)aSize offset:(int64_t)aOffset writtenSize:(int64_t *)aWrittenSize userData:(id)aUserData
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"write %@ (%lld, %lld)", aPath, aOffset, aSize);
#endif
        if (mSFTP)
        {
            sftp_file sHandle = [aUserData handle];
            int64_t   sLength = 0;
            int       sResult = 0;

            if (sftp_seek64(sHandle, aOffset))
            {
                return [self posixError];
            }

            while (sLength < aSize)
            {
                ssize_t sRet = sftp_write(sHandle, (char *)aBuffer + sLength, MIN(aSize - sLength, SSHFS_XFER_SIZE));

                if (sRet < 0)
                {
                    if (!sLength)
                    {
                        sResult = [self posixError];
                    }

                    break;
                }
                else
                {
                    sLength += sRet;
                }
            }

            *aWrittenSize = sLength;

            return sResult;
        }
        else
        {
            return ENXIO;
        }
    }
}


- (int)truncateFileAtPath:(NSString *)aPath offset:(int64_t)aOffset userData:(id)aUserData
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"truncate %@ (%lld)", aPath, aOffset);
#endif
        if (mSFTP)
        {
            struct sftp_attributes_struct sFileAttr;
            int                           sRet;

            memset(&sFileAttr, 0, sizeof(sFileAttr));

            sFileAttr.size  = aOffset;
            sFileAttr.flags = SSH_FILEXFER_ATTR_SIZE;

            sRet = sftp_setstat(mSFTP, [self remotePath:aPath], &sFileAttr);

            if (sRet)
            {
                return [self posixError];
            }
            else
            {
                return 0;
            }
        }
        else
        {
            return ENXIO;
        }
    }
}


- (int)getDestination:(NSString **)aDestinationPath ofSymbolicLinkAtPath:(NSString *)aPath
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"readlink %@", aPath);
#endif
        if (mSFTP)
        {
            char *sDestinationPath;

            sDestinationPath = sftp_readlink(mSFTP, [self remotePath:aPath]);

            if (sDestinationPath)
            {
                *aDestinationPath = [NSString stringWithUTF8String:sDestinationPath];

                return 0;
            }
            else
            {
                return [self posixError];
            }
        }
        else
        {
            return ENXIO;
        }
    }
}


- (int)createSymbolicLinkAtPath:(NSString *)aPath withDestinationPath:(NSString *)aDestinationPath
{
    @synchronized(self)
    {
#if SSHFS_LOG
        NSLog(@"symlink %@ -> %@", aDestinationPath, aPath);
#endif
        if (mSFTP)
        {
            int sRet;

            sRet = sftp_symlink(mSFTP, [aDestinationPath UTF8String], [self remotePath:aPath]);

            if (sRet)
            {
                return [self posixError];
            }
            else
            {
                return 0;
            }
        }
        else
        {
            return ENXIO;
        }
    }
}


@end
