//
//  NSEvent-CarbonAdditions.m
//
//	DropWindow.h
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

#import "NSEvent-CarbonAdditions.h"
// This implements a category to NSEvent for checking the modifier keys pressed. This is necessary, because cocoa doesn't set an nsevent during the launch
// of an application.

@implementation NSEvent (ModifierKeys)

+ (BOOL) isControlKeyDown
{
    return (GetCurrentKeyModifiers() & controlKey) != 0;
}

+ (BOOL) isOptionKeyDown
{
    return (GetCurrentKeyModifiers() & optionKey) != 0;
}

+ (BOOL) isCommandKeyDown
{
    return (GetCurrentKeyModifiers() & cmdKey) != 0;
}

+ (BOOL) isShiftKeyDown
{
    return (GetCurrentKeyModifiers() & shiftKey) != 0;
}

@end
