/*
 *  DiskCell.m
 *  MrDisk
 *
 *  Created by han9kin on 2011-05-24.
 *
 */

#import "DiskCell.h"
#import "FileSystem.h"


@implementation DiskCell


- (void)setup
{
    mNameFieldCell = [[NSTextFieldCell alloc] initTextCell:@""];
    [mNameFieldCell setFont:[NSFont controlContentFontOfSize:13]];

    mURLFieldCell = [[NSTextFieldCell alloc] initTextCell:@""];
    [mURLFieldCell setFont:[NSFont fontWithName:@"Monaco" size:10]];
}


- (id)init
{
    self = [super init];

    if (self)
    {
        [self setup];
    }

    return self;
}


- (id)initWithCoder:(NSCoder *)aCoder
{
    self = [super initWithCoder:aCoder];

    if (self)
    {
        [self setup];
    }

    return self;
}


- (id)initImageCell:(NSImage *)aImage
{
    self = [super initImageCell:aImage];

    if (self)
    {
        [self setup];
    }

    return self;
}


- (id)initTextCell:(NSString *)aString
{
    self = [super initTextCell:aString];

    if (self)
    {
        [self setup];
    }

    return self;
}


- (void)setRepresentedObject:(id)aObject
{
    [super setRepresentedObject:aObject];

    if ([aObject isKindOfClass:[FileSystem class]])
    {
        [mNameFieldCell setStringValue:[aObject name]];
        [mURLFieldCell setStringValue:[[aObject url] absoluteString]];
    }
}


- (void)setHighlighted:(BOOL)aHighlighted;
{
    [super setHighlighted:aHighlighted];

    [mNameFieldCell setHighlighted:aHighlighted];
    [mURLFieldCell setHighlighted:aHighlighted];
}


- (void)drawWithFrame:(NSRect)aRect inView:(NSView *)aControlView
{
    [mNameFieldCell drawWithFrame:NSMakeRect(aRect.origin.x + 17, aRect.origin.y + 5, aRect.size.width - 34, 17) inView:aControlView];
    [mURLFieldCell drawWithFrame:NSMakeRect(aRect.origin.x + 17, aRect.origin.y + 26, aRect.size.width - 34, 14) inView:aControlView];
}


@end
