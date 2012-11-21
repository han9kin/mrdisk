/*
 *  ObjCUtil.h
 *  MrDisk
 *
 *  Created by han9kin on 2011-05-23.
 *
 */

#import <Foundation/Foundation.h>


#pragma mark -
#pragma mark marking the method is abstract and responsible to subclasses


#define SubclassResponsibility()                                        \
    do                                                                  \
    {                                                                   \
        NSLog(@"SubclassResponsibility -[%@ %@] not implemented.",      \
              NSStringFromClass([self class]),                          \
              NSStringFromSelector(_cmd));                              \
        abort();                                                        \
    } while (0)


#pragma mark -
#pragma mark making singleton class


#define SYNTHESIZE_SINGLETON_CLASS(aClassName, aAccessor) SYNTHESIZE_SINGLETON_CLASS_WITH_RETURNTYPE(aClassName, aClassName *, aAccessor)

#define SYNTHESIZE_SINGLETON_CLASS_WITH_RETURNTYPE(aClassName, aReturnType, aAccessor)  \
                                                                                        \
    static aClassName *aAccessor = nil;                                                 \
                                                                                        \
+ (aReturnType)aAccessor                                                                \
{                                                                                       \
    static id sTmpObj;                                                                  \
                                                                                        \
    @synchronized(self)                                                                 \
    {                                                                                   \
        if (!aAccessor)                                                                 \
        {                                                                               \
            sTmpObj = [[self alloc] init];                                              \
        }                                                                               \
    }                                                                                   \
                                                                                        \
    return aAccessor;                                                                   \
}                                                                                       \
                                                                                        \
+ (id)allocWithZone:(NSZone *)aZone                                                     \
{                                                                                       \
    @synchronized(self)                                                                 \
    {                                                                                   \
        if (!aAccessor)                                                                 \
        {                                                                               \
            aAccessor = [super allocWithZone:aZone];                                    \
            return aAccessor;                                                           \
        }                                                                               \
    }                                                                                   \
                                                                                        \
    return nil;                                                                         \
}                                                                                       \
                                                                                        \
- (id)copyWithZone:(NSZone *)aZone                                                      \
{                                                                                       \
    return self;                                                                        \
}                                                                                       \
                                                                                        \
- (id)retain                                                                            \
{                                                                                       \
    return self;                                                                        \
}                                                                                       \
                                                                                        \
- (NSUInteger)retainCount                                                               \
{                                                                                       \
    return NSUIntegerMax;                                                               \
}                                                                                       \
                                                                                        \
- (oneway void)release                                                                  \
{                                                                                       \
}                                                                                       \
                                                                                        \
- (id)autorelease                                                                       \
{                                                                                       \
    return self;                                                                        \
}
