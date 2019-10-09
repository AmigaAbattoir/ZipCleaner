//
//  NSEvent-CarbonAdditions.h
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

#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>

@interface NSEvent (ModifierKeys)
+ (BOOL) isControlKeyDown;
+ (BOOL) isOptionKeyDown;
+ (BOOL) isCommandKeyDown;
+ (BOOL) isShiftKeyDown;
@end
