//
//	DropView.m
//  ZipCleaner
//
//  Copyright 2007, Roger Jolly.
//
//
//	Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above
//	copyright notice and this permission notice appear in all copies.
//
//	The software is provided "as is" and the author disclaims all warranties with regard to this software including all implied warranties of
//	merchantability and fitness. in no event shall the author be liable for any special, direct, indirect, or consequential damages or any damages
//	whatsoever resulting from loss of use, data or profits, whether in an action of contract, negligence or other tortious action, arising out of
//	or in connection with the use or performance of this software.

#import "DropView.h"

@implementation DropView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
		[self registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];
		[dropIconButton setFocusRingType: NSFocusRingTypeNone];
	}
	return self;
}

- (void)drawRect:(NSRect)rect
{
	[dropIconButton setFocusRingType: NSFocusRingTypeNone];
}

- (void) updateDragInfoText {
	if ([controller removeOnlyDS_Store]) {
		[dropInfoText setStringValue: NSLocalizedString(@"Only .DS_Store files will be removed.", nil)];
	} else {
		[dropInfoText setStringValue: NSLocalizedString(@"All resource information will be removed.", nil)];
	}
}

- (BOOL)acceptsFirstResponder {
	return YES;
}

- (void) flagsChanged: (NSEvent *) theEvent {
	[self updateDragInfoText];
}

- (BOOL) validateMenuItem: (NSMenuItem *) menuItem {
// Called to check if the drop window menu item should be shown. 
	if ([[self window] isVisible]) {
		return NO;
	} else {
		return YES;
	}
}

- (IBAction) showWindow: (id) sender {
	if (![[self window] isKeyWindow]) {
		[[self window] makeKeyAndOrderFront: sender];
	}
}

// Dragging support

- (void) concludeDragOperation: (id <NSDraggingInfo>) sender {
	[self updateDragInfoText];
	[dropIconButton highlight: FALSE];
}

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>) sender {
	[self updateDragInfoText];
	[dropIconButton highlight: TRUE];
	if (![[self window] isKeyWindow]) {
		[[self window] makeKeyAndOrderFront: sender];
	}
	return NSDragOperationGeneric;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
	[self updateDragInfoText];
	[dropIconButton highlight: FALSE];
}


- (NSDragOperation) draggingUpdated: (id <NSDraggingInfo>) sender {
	NSPasteboard *pboard = [sender draggingPasteboard];
	if ([pboard stringForType: NSFilenamesPboardType]) {
		[self updateDragInfoText];
	return NSDragOperationGeneric;
	}
	return NSDragOperationNone;
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>) sender {
	NSPasteboard *pboard = [sender draggingPasteboard];
	NSArray *filenames = [[pboard stringForType: NSFilenamesPboardType] propertyList];
	[controller application: NSApp openFiles: filenames];
	return YES;
}


@end
