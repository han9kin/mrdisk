/*
 *  TableView.m
 *  MrDisk
 *
 *  Created by han9kin on 2011-05-23.
 *
 */

#import "TableView.h"


@implementation TableView


- (void)rightMouseDown:(NSEvent *)aEvent
{
    [super rightMouseDown:aEvent];

    NSInteger sRow = [self rowAtPoint:[self convertPoint:[aEvent locationInWindow] fromView:nil]];

    if (sRow >= 0)
    {
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:sRow] byExtendingSelection:NO];
    }
    else
    {
        [self deselectAll:self];
    }

    if ([[self delegate] respondsToSelector:@selector(showActionInTableView:)])
    {
        [[self delegate] performSelector:@selector(showActionInTableView:) withObject:self];
    }
}


@end
