//
//  Controller.h
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

#import <Cocoa/Cocoa.h>
#import "NSEvent-CarbonAdditions.h"

typedef enum modifier_Keys {
    modifierCommand = 1,
    modifierControl = 2,
	modifierOption = 3,
	modifierShift = 4
} modifierKeys;

extern NSString *PREFwarnResourceFiles;
extern NSString *PREFkeyDS_Store;
extern NSString *PREFwarnDS_Store;
extern NSString *PREFreportSuccess;
extern int PREFshowProgressIndicatorBottomLimit;

typedef enum default_pref_values {
    warnResourceFilesPrefValue = 1,
    keyDS_Store = modifierOption,
    warnDS_StorePrefValue = 0,
	reportSuccessPrefValue = 0,
} defaultPrefValues;


@interface Controller : NSObject
{
    IBOutlet NSTextField *fileNameProgressIndicator;
    IBOutlet NSPopUpButton *prefKeyDS_Store;
    IBOutlet NSButton *prefReportSuccess, *prefWarnDS_Store, *prefWarnResourceFiles;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSWindow *detailsWindow, *dropWindow, *windowProgressIndicator;
	IBOutlet NSTextView *detailsTextView;
    IBOutlet NSTextField *dropInfoText, *progressIndicatorText;
    IBOutlet NSView *openPanelAccessoryView;
	NSMutableSet *waitingList;
	NSMutableArray *cleaningDetails;
	NSString *pathToZip;
	NSWindow *cleaningDoneWindow;
	NSAlert *anAlert;
	BOOL busyCleaning, quitWhenDone, showProgressIndicator;
}

#pragma mark-
#pragma mark Starting up and shutting down
+ (void) initialize;
- (id) init;
- (void) awakeFromNib;
- (void) dealloc;

#pragma mark-
#pragma mark Accessors
- (void) setBusyCleaning: (BOOL) aBool;
- (BOOL) busyCleaning;
- (void) setShowProgressIndicator: (BOOL) aBool;
- (BOOL) showProgressIndicator;
- (void) setQuitWhenDone: (BOOL) aBool;
- (BOOL) quitWhenDone;

#pragma mark-
#pragma mark Main methods
- (IBAction) open: (id) sender;
- (void) setUpFiles: (NSArray *) filenames removingOnlyDS_Store: (BOOL) removeOnlyDS_Store;
- (void) addToWaitingList: (NSArray *) filenames removingOnlyDS_Store: (BOOL) removeOnlyDS_Store;
- (NSArray *) produceCompleteFileListfromList: (NSArray *) fileList;
- (void) processFile;
- (BOOL) continueAfterPreprocessing: (NSString *) aFile;
- (void) clearFile: (NSString *) aFile removingOnlyDS_Store: (BOOL) removeOnlyDS_Store;
- (IBAction) stopCleaning: (id) sender;
- (void) cleaningFinished: (NSNotification *) note;
- (void) alertDidEnd: (NSAlert *) alert returnCode: (int) returnCode contextInfo: (void *) contextInfo;

#pragma mark-
#pragma mark Check conditions
- (BOOL) removeOnlyDS_Store;
- (BOOL) continueAfterWarning: (BOOL) removeOnlyDS_Store;
- (NSString *) pathToZip;

#pragma mark-
#pragma mark Details methods
- (void) clearDetailsInfo;
- (void) appendToDetailsInfo: (NSString *) details forFile: (NSString *) aFile;
- (void) showDetails;

- (void) reformulateErrorMessage: (NSMutableString *) errorMessage;

#pragma mark-
#pragma mark Preferences methods
- (IBAction) prefChanged: (id) sender;
- (IBAction) prefRestore: (id) sender;

#pragma mark-
#pragma mark Application delegate
- (BOOL) applicationOpenUntitledFile: (NSApplication *) theApplication;
- (void) application: (NSApplication *) sender openFiles: (NSArray *) filenames;

@end

@interface NSMutableArray (ZipCleaner)
- (void) removeDuplicates;
@end
