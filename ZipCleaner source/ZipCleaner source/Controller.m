//
//  Controller.m
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

#import "Controller.h"

NSString *PREFwarnDS_Store = @"Warn about .DS_Store";
NSString *PREFwarnResourceFiles = @"Warn about resource files";
NSString *PREFkeyDS_Store = @"Key for resource files";
NSString *PREFreportSuccess = @"Report successful removal";
int PREFshowProgressIndicatorBottomLimit = 10;

@implementation Controller

#pragma mark-
#pragma mark Starting up and shutting down

+ (void) initialize {

	// Register the application default values.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *zipCleanerDefaults = [NSMutableDictionary dictionary];

	[zipCleanerDefaults setObject: [NSString stringWithFormat:@"%d", warnResourceFilesPrefValue] forKey: PREFwarnResourceFiles];
	[zipCleanerDefaults setObject: [NSString stringWithFormat:@"%d", keyDS_Store] forKey: PREFkeyDS_Store];
	[zipCleanerDefaults setObject: [NSString stringWithFormat:@"%d", warnDS_StorePrefValue] forKey: PREFwarnDS_Store];
	[zipCleanerDefaults setObject: [NSString stringWithFormat:@"%d", reportSuccessPrefValue] forKey: PREFreportSuccess];

	[defaults registerDefaults: zipCleanerDefaults];
}

- (id) init {
	self = [super init];
	if (self != nil) {
		busyCleaning = NO;
		quitWhenDone = YES;
		cleaningDetails = [[NSMutableArray alloc] init];
		waitingList = [[NSMutableSet alloc] init];

		// Register with notificationcenter to hear when cleaning is finished.
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(cleaningFinished:)
													 name: @"RDJZipCleaningFinished"
												   object: nil];
	}
	return self;
}

- (void) awakeFromNib {

	// Set the user defined default values, if any.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	[prefWarnResourceFiles setIntValue: [defaults boolForKey: PREFwarnResourceFiles]];
	[prefKeyDS_Store selectItemWithTag: [defaults integerForKey: PREFkeyDS_Store]];
	[prefWarnDS_Store setIntValue: [defaults boolForKey: PREFwarnDS_Store]];
	[prefReportSuccess setIntValue: [defaults boolForKey: PREFreportSuccess]];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[pathToZip release];
	[waitingList release];
	[cleaningDetails release];
	[super dealloc];
}

#pragma mark-
#pragma mark Accessors

- (void) setBusyCleaning: (BOOL) aBool {
	busyCleaning = aBool;
}

- (BOOL) busyCleaning {
	return busyCleaning;
}

- (void) setShowProgressIndicator: (BOOL) aBool {
	showProgressIndicator = aBool;
}

- (BOOL) showProgressIndicator {
	return showProgressIndicator;
}

- (void) setQuitWhenDone: (BOOL) aBool {
	quitWhenDone = aBool;
}

- (BOOL) quitWhenDone {
	return quitWhenDone;
}


#pragma mark-
#pragma mark Main methods

- (IBAction) open: (id) sender {
// This method is called when the user selects "CleanÉ" from the menubar. The resulting open panel uses a custom view to determine if the user wants to
// remove all resource information or just the .DS_Store files. It is initially set based on whether or not the user presses the appropriate modifier key
// when selecting the command.
// The accessoryview is retained, because "In order to free up unused memory after closing the receiver, the accessory view is released after the panel is closed."

	BOOL removeOnlyDS_Store = [self removeOnlyDS_Store];
	[openPanelAccessoryView retain];
	id removeWhatMatrix = [[openPanelAccessoryView subviews] objectAtIndex: 0];
	
	[removeWhatMatrix selectCellWithTag: removeOnlyDS_Store];					// The first ("0") matrix item is the default, so it lines up with the bool values.

	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowsMultipleSelection: YES];
	[openPanel setCanChooseDirectories: YES];									// Allow the cleaning of entire folders.
	[openPanel setTitle: NSLocalizedString(@"Clean zip archive", nil)];
	[openPanel setMessage: NSLocalizedString(@"Choose zip archives to clean.", nil)];
	[openPanel setPrompt: NSLocalizedString(@"Clean", nil)];
	[openPanel setAccessoryView: openPanelAccessoryView];
    int result = [openPanel runModalForTypes: [NSArray arrayWithObjects: @"zip", NSFileTypeForHFSTypeCode('ZIP '), nil]];

	removeOnlyDS_Store = [removeWhatMatrix selectedTag];					// What did the user choose to remove?
	[openPanelAccessoryView release];

	if (result == NSOKButton) {
		[self setUpFiles:[openPanel filenames] removingOnlyDS_Store: removeOnlyDS_Store];
	}
	
}

- (void) setUpFiles: (NSArray *) filenames removingOnlyDS_Store: (BOOL) removeOnlyDS_Store {
// This methods warns the user about what is going to happen, if needed. If it can cotinue, it adds the files to the waitingList and starts the processing,
// if that isn't going on already.

	if (![self continueAfterWarning: removeOnlyDS_Store]) { 
		if ([self quitWhenDone] && ![self busyCleaning]) {
			[NSApp terminate:self];
		} else {
			return;
		}
	}
	
	[self addToWaitingList: filenames removingOnlyDS_Store: removeOnlyDS_Store];

	if (![self busyCleaning]) {
		[progressIndicator setDoubleValue: 0.0];
		[self clearDetailsInfo];
		[self processFile];
	}
}


- (void) addToWaitingList: (NSArray *) filenames removingOnlyDS_Store: (BOOL) removeOnlyDS_Store {
// This method adds dropped files to the waitingList from which ZipCleaner gets the files it processes. First any folders are expanded.
// Then arrays are added tot the waitingList containing the filepath and whether or not all resource information should be removed.

	NSArray *completeFileList = [self produceCompleteFileListfromList: filenames];

	NSEnumerator *enumerator = [completeFileList objectEnumerator];
	NSString *currentFile;
	
	while (currentFile = [enumerator nextObject]) {
		[waitingList addObject: [NSArray arrayWithObjects: currentFile, [NSNumber numberWithBool: removeOnlyDS_Store], nil]];
	}
	
	// Determine whether or not to show the progressindicator and its length.
	int fileTotal = [waitingList count] + [cleaningDetails count];
	if (fileTotal > PREFshowProgressIndicatorBottomLimit) {
		[progressIndicator setMaxValue: (double) fileTotal];
		[self setShowProgressIndicator: YES];
	}

}

- (NSArray *) produceCompleteFileListfromList: (NSArray *) fileList {
// This method takes an array of file paths, and examines each. If the path is a file, it is added to an array completeFileList. 
// If it is a folder, the contents is added (examining it for other folders).
	
	int listLength = [fileList count];
	if (listLength == 0) {
		return fileList;
	}
	
	NSMutableArray *tempList = [NSMutableArray arrayWithArray: fileList];
	NSMutableArray *tempResult = [NSMutableArray array];

	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDirectoryEnumerator *dirEnum;
	NSDictionary *fileAttributes;
	
	int i;
	NSString *currentPath, *currentSubPath, *fullPath;
	for (i = 0; i < listLength; i++) {
		currentPath = [tempList objectAtIndex: i];
		fileAttributes = [fileManager fileAttributesAtPath: currentPath traverseLink: NO];
		if ([[fileAttributes fileType] isEqualToString: NSFileTypeDirectory]) {
			dirEnum = [fileManager enumeratorAtPath: currentPath];								// Get the entire folder contents, this includes subfolders.
			while (currentSubPath = [dirEnum nextObject]) {
				fullPath = [NSString stringWithFormat: @"%@/%@", currentPath, currentSubPath];	// Make a complete path.
				fileAttributes = [fileManager fileAttributesAtPath: fullPath  traverseLink: NO];
				if (![[fileAttributes fileType] isEqualToString: NSFileTypeDirectory]) {		// Don't add the subfoldrs.
					[tempResult addObject: fullPath];		
				}
			}
		} else {
			[tempResult addObject: currentPath];
		}
	}
	
	NSArray *completeFileList = [NSArray arrayWithArray: tempResult];
	return completeFileList;
}

- (void) processFile {
// Main staging post. This methods takes a filepath from the waiting list and examines whether or not the resource information should be removed.

	[self setBusyCleaning: YES];

	// Get an item from the waitingList and split it between its components.
	NSArray *currentObject = [waitingList anyObject];
	NSString *currentFile = [currentObject objectAtIndex: 0];
	BOOL removeOnlyDS_Store = [[currentObject objectAtIndex: 1] boolValue];

	// Show progressIndicator if necessary, and increment it by one.
	if ([self showProgressIndicator]) {
		if (![windowProgressIndicator isVisible] && ![windowProgressIndicator isMiniaturized]) {
			[windowProgressIndicator makeKeyAndOrderFront: self];
		}

		[progressIndicator incrementBy: 1.0];
		[progressIndicatorText setStringValue: [NSString stringWithFormat: NSLocalizedString (@"Cleaning: %@", nil), [currentFile lastPathComponent]]];
		[windowProgressIndicator display];						// Force update of the window.
	}
	
	// Do some preflight checking.
	if ([self continueAfterPreprocessing: currentFile]) {
		[self clearFile: currentFile removingOnlyDS_Store: removeOnlyDS_Store];
	}

	[waitingList removeObject: currentObject];				// Item is processed, so remove from waitingList.

	// Send a notification that processing is done. The notifications are coalesced, so even if the user drops items on ZipCleaner while it is cleaning, 
	// there will be only one notification that says ZipCleaner is done.
	[[NSNotificationQueue defaultQueue] enqueueNotification: [NSNotification notificationWithName: @"RDJZipCleaningFinished" object: nil]
											   postingStyle: NSPostWhenIdle
											   coalesceMask: NSNotificationCoalescingOnName
												   forModes: nil];
}

- (BOOL) continueAfterPreprocessing: (NSString *) aFile {
// Check if basic conditions are available for processing the archive.

	NSFileManager *fileManager = [NSFileManager defaultManager];

	// Check to see if the disk of the current file is writable.
	if (![fileManager isWritableFileAtPath: aFile]) {
		[self appendToDetailsInfo: NSLocalizedString(@"Disk not writable.", nil) forFile: aFile];
		return NO;
	}

	// Check to see if the disk of the current file has enough free space to hold a temporary copy.
	NSNumber *freeSpace = [[fileManager fileSystemAttributesAtPath: aFile] objectForKey: NSFileSystemFreeSize];
	NSNumber *fileSize = [[fileManager fileAttributesAtPath: aFile traverseLink: TRUE] objectForKey: NSFileSize];
	if ([freeSpace compare: fileSize] != NSOrderedDescending) {
		[self appendToDetailsInfo: NSLocalizedString(@"Not enough space to create a temporary file.", nil) forFile: aFile];
		return NO;
	}

	return YES;

}

- (void) clearFile: (NSString *) aFile removingOnlyDS_Store: (BOOL) removeOnlyDS_Store {
// This method removes the appropriate bits by calling zip and adding the results of this to the cleaningDetails.

    NSTask *zipTask = [[NSTask alloc] init];
    [zipTask setLaunchPath: [self pathToZip]];

	NSArray *arguments;
	if (removeOnlyDS_Store) {
		arguments = [NSArray arrayWithObjects: @"-dq", aFile, @"*/.DS_Store", @"*/._.DS_Store", nil];
	} else {
		arguments = [NSArray arrayWithObjects: @"-dq", aFile, @"*/.DS_Store", @"*/Icon\x0D", @"__MACOSX/*", nil];	// __MACOSX contains the ._.DS_Store files and ._Icon^M files.
	}

    [zipTask setArguments: arguments];

    NSPipe *zipPipe = [NSPipe pipe];
    [zipTask setStandardError: zipPipe];

    NSFileHandle *file = [zipPipe fileHandleForReading];

    [zipTask launch];

    NSData *data = [file readDataToEndOfFile];

    NSMutableString *errorString = [[NSMutableString alloc] initWithData: data encoding: NSUTF8StringEncoding];
	
	if ([zipTask isRunning]) {
		[zipTask terminate];
	}
	[zipTask release];

	if ([errorString isEqualToString:@""]) {
		if (removeOnlyDS_Store) {
			[self appendToDetailsInfo: NSLocalizedString(@".DS_Store file(s) removed.", nil) forFile: aFile];
		} else {
			[self appendToDetailsInfo: NSLocalizedString(@"All resource information removed.", nil) forFile: aFile];
		}
	} else {
		[self reformulateErrorMessage: errorString];	// Because zip error messages are of the format "Zip error: <message> (<file>), rebuild them,
		[self appendToDetailsInfo: NSLocalizedString(errorString, nil) forFile: aFile];
	}

	[errorString release];
}

- (IBAction) stopCleaning: (id) sender {
// This method is called if the user stops the cleaning by pressing the button on the progress indicator. It removes all the remaining items from the waitingList
// and adds them to the cleaningDetails with the message that they were not processed. It then sends a notification that cleaning is finished.
	NSEnumerator *enumerator = [waitingList objectEnumerator];
	id currentObject;
	NSString *currentFile;
	
	while (currentObject = [enumerator nextObject]) {
		currentFile = [currentObject objectAtIndex: 0];	// filepath
		[self appendToDetailsInfo: NSLocalizedString(@"Cleaning stopped.", nil) forFile: currentFile];
		[waitingList removeObject: currentObject];
	}

	// Send a notification that processing is done. The notifications are coalesced, so even if the user drops items on ZipCleaner while it is cleaning, 
	// there will be only one notification that says ZipCleaner is done.
	[[NSNotificationQueue defaultQueue] enqueueNotification: [NSNotification notificationWithName: @"RDJZipCleaningFinished" object: nil]
											   postingStyle: NSPostWhenIdle
											   coalesceMask: NSNotificationCoalescingOnName
												   forModes: nil];
}

- (void) cleaningFinished: (NSNotification *) note {
// Receives the notification that ZipCleaner is finished with a batch. If the user drops more files after the notification has been send, but before the alert
// is shown, we will continue processing. Otherwise dismiss the progressindicator if necessary and show an alert telling the user ZipCleaner is finished.

	if ([waitingList count]) {															// Continue processing if there are still files on the waitingList.
		[self processFile];
	} else {
		if ([windowProgressIndicator isVisible] || [windowProgressIndicator isMiniaturized]) {
			[windowProgressIndicator close];
		}

		if ([prefReportSuccess intValue]) {

			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText: [NSString stringWithString: NSLocalizedString(@"Finished cleaning", nil)]];
			[alert setInformativeText: [NSString stringWithString: NSLocalizedString(@"Finished cleaning text", nil)]];
			[alert addButtonWithTitle: NSLocalizedString(@"Done", nil)];
			[alert addButtonWithTitle: NSLocalizedString(@"Show details", nil)];
			[alert setAlertStyle: NSWarningAlertStyle];

			[alert beginSheetModalForWindow: nil modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
		} else {

			// Check whether ZipCleaner should quit. If not, do some resetting.
			if ([self quitWhenDone]) {
				[NSApp terminate:self];
			} else {
				[self setBusyCleaning: NO];		
				[self clearDetailsInfo];
			}
		}
	}
}

- (void) alertDidEnd: (NSAlert *) alert returnCode: (int) returnCode contextInfo: (void *) contextInfo {
// This method is called when the user makes a choice in the results alert. First the alert is released. Depending on the user's choice, detail information is shown.
// If new files have been dropped, the progressindicator is reset and the files are processed.

	[alert release];

	if (returnCode == NSAlertSecondButtonReturn) {
		[self showDetails];
		[self setQuitWhenDone: NO];
	}
	[self clearDetailsInfo];

	if ([waitingList count]) {
		[progressIndicator setDoubleValue: 0.0];
		[progressIndicator setMaxValue: (double) [waitingList count]];					// maxValue must be updated, because it was set before detailsInfo was cleared.
		[self processFile];
	} else if ([self quitWhenDone]) {
		[NSApp terminate:self];
	} else {
		[self setBusyCleaning: NO];		
		[self clearDetailsInfo];
	}
}


#pragma mark-
#pragma mark Check conditions

- (BOOL) removeOnlyDS_Store {
// This method checks to see if the user pressed the modifier key needed to remove the resource information from an archive. (This key can also be "no modifier".)
// A call to a carbon using category of NSEvent is used, because cocoa doesn't register modifier keys pressed during the launch of an application.

	BOOL removeOnlyDS_Store = NO;
	switch ([[prefKeyDS_Store selectedItem] tag]) {									// See which key is set in the preferences for removing only .DS_Store files.
		case modifierCommand:
			if ([NSEvent isCommandKeyDown]) { removeOnlyDS_Store = YES; }
			break;
		case modifierControl:
			if ([NSEvent isControlKeyDown]) { removeOnlyDS_Store = YES; }
			break;
		case modifierOption:
			if ([NSEvent isOptionKeyDown]) { removeOnlyDS_Store = YES; }
			break;
		case modifierShift:
			if ([NSEvent isShiftKeyDown]) { removeOnlyDS_Store = YES; }
	}
	return removeOnlyDS_Store;
}

- (BOOL) continueAfterWarning: (BOOL) removeOnlyDS_Store {
// Depending on the preferences set, this method can show a warning about the files that will be removed from the archive.

	NSAlert *alert;
	int alertResult, requestedWarnings;
	
	if (removeOnlyDS_Store) {
		requestedWarnings = [prefWarnDS_Store intValue];
	} else {
		requestedWarnings = [prefWarnDS_Store intValue] + [prefWarnResourceFiles intValue];
	}
	
	switch (requestedWarnings) {
		case 0:
			return YES;																// Return YES if no alers were specified.
		case 1:
			alert = [[NSAlert alloc] init];
			[alert addButtonWithTitle: NSLocalizedString(@"Cancel", nil)];
			if ([prefWarnDS_Store intValue]) {
				[alert setMessageText: [NSString stringWithString: NSLocalizedString(@"Warning DS_Store", nil)]];
				[alert setInformativeText: [NSString stringWithString: NSLocalizedString(@"Warning text DS_Store", nil)]];
				[alert addButtonWithTitle: NSLocalizedString(@"Clear DS_Store", nil)];
			} else {
				[alert setMessageText: [NSString stringWithString: NSLocalizedString(@"Warning resource files", nil)]];
				[alert setInformativeText: [NSString stringWithString: NSLocalizedString(@"Warning text resource files", nil)]];
				[alert addButtonWithTitle: NSLocalizedString(@"Clear resource files", nil)];
			}
			[alert setAlertStyle: NSCriticalAlertStyle];
			alertResult = [alert runModal];
			[alert release];
			break;
		case 2:
			alert = [[NSAlert alloc] init];
			[alert setMessageText: [NSString stringWithString: NSLocalizedString(@"Warning resource files", nil)]];
			[alert setInformativeText: [NSString stringWithString: NSLocalizedString(@"Warning text resource files", nil)]];
			[alert addButtonWithTitle: NSLocalizedString(@"Cancel", nil)];
			[alert addButtonWithTitle: NSLocalizedString(@"Clear resource forks", nil)];
			[alert setAlertStyle: NSCriticalAlertStyle];
			alertResult = [alert runModal];
			[alert release];
			break;
		default:
			return NO;
	}
	if (alertResult == NSAlertSecondButtonReturn) {
		return YES;																// Only return YES if the user explicitly asks for removal.
	} else {
		return NO;
	}
}

- (NSString *) pathToZip {
// This is not an accessor method, but close to it. It combines setting and return pathToZip, the path to the zip executable.
// If the system has zip at "/usr/bin/zip", this will be used, otherwise a version of zip included in the bundle of ZipCleaner is used.
	[pathToZip release];
	
	pathToZip = [[NSString alloc] initWithString:@"/usr/bin/zip"];
	if (![[NSFileManager defaultManager] fileExistsAtPath:pathToZip]) {
		[pathToZip release];
		pathToZip = [[NSBundle mainBundle] pathForResource:@"zip" ofType:@""];
	}
	[pathToZip retain];
	return pathToZip;
}


#pragma mark-
#pragma mark Details methods

- (void) clearDetailsInfo {
	[cleaningDetails removeAllObjects];
}

- (void) appendToDetailsInfo: (NSString *) details forFile: (NSString *) aFile {
// This method adds the filepath and the results of the removal operation separated by a null-string. This way, ZipCleaner can sort them more easily.
// Later the null-string will be replaced by a newline.
	[cleaningDetails addObject: [NSString stringWithFormat:@"%@\0%@", aFile, details]];
}

- (void) showDetails {
// This methods fills the detailswindow with the latest details and shows it, if it isn't visible already.

	[cleaningDetails removeDuplicates];		// Remove any duplicate items from the array. (This can happen if the user drops a file more than once.)
	[cleaningDetails sortUsingSelector: @selector(localizedCompare:)];	// Because NSString already knows how to sort, we can leave it to that class.

	// Add all the details information to a string.
	NSMutableString *tempString = [NSMutableString string];
	int i;
	for (i=0; i < [cleaningDetails count]; i++) {
		[tempString appendFormat: @"%@\n\n", [cleaningDetails objectAtIndex: i]];
	}
	
	// Replace all the null-characters with newlines.
	[tempString replaceOccurrencesOfString: @"\0" withString: @"\n" options: NSLiteralSearch range: NSMakeRange(0, [tempString length])];

	// Replace any text now occupying the details window, with the new information
	int length = [[detailsTextView textStorage] length];
	[detailsTextView replaceCharactersInRange: NSMakeRange(0,length) withString: tempString];
	
	// Scroll to the top of the scrollview, before showing it.
	[detailsTextView setSelectedRange: NSMakeRange(0,0)];											// Put cursor at beginning of textview.
	[[[detailsTextView enclosingScrollView] documentView] scrollPoint: NSMakePoint (0.0, 0.0)];		// Set scrollview to beginning of textview.
	[detailsWindow makeKeyAndOrderFront: self];
}

- (void) reformulateErrorMessage: (NSMutableString *) errorMessage {
// Change the error messages zip gives to something more useable by removing the first part, saving the real error message and throwing away the last part.
// which contains the file path, because we know that already.
	NSString *tempString = [NSString string];
	NSScanner *aScanner = [NSScanner scannerWithString: errorMessage];

	[aScanner scanUpToString:@"zip error: " intoString: NULL];
	[aScanner scanString:@"zip error: " intoString: NULL];
	[aScanner scanUpToString:@" (" intoString: &tempString];
	
	[errorMessage setString: tempString];
}


#pragma mark-
#pragma mark Preferences methods
// See also initialize and awakeFromNib.

- (IBAction) prefChanged: (id) sender {
// This method saves the preferences after the user has changed them.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	[defaults setBool: [prefWarnResourceFiles intValue] forKey: PREFwarnResourceFiles];
	[defaults setInteger: [[prefKeyDS_Store selectedItem]tag] forKey: PREFkeyDS_Store];
	[defaults setBool: [prefWarnDS_Store intValue] forKey: PREFwarnDS_Store];
	[defaults setBool: [prefReportSuccess intValue] forKey: PREFreportSuccess];
}

- (IBAction) prefRestore: (id) sender {
// This method restores the application's preferences.

	[prefWarnResourceFiles setIntValue: warnResourceFilesPrefValue];
	[prefKeyDS_Store selectItemWithTag: keyDS_Store];
	[prefWarnDS_Store setIntValue: warnDS_StorePrefValue];
	[prefReportSuccess setIntValue: reportSuccessPrefValue];
	
	// Call the method that saves changed preferences.
	[self prefChanged: self];
}


#pragma mark-
#pragma mark Application delegate

- (BOOL) applicationOpenUntitledFile: (NSApplication *) theApplication {
// This method is only invoked when no window is open and the user clicks on dock-icon or application in Finder. 
// Because ZipCleaner doesn't show a window after launching the application, this method is called when ZipCleaner opens without a file to process.
// In that case, the application will remain open even after processing any files dragged to ZipCleaner.
	[self setQuitWhenDone: FALSE];
	
	// Prepare the drop window and show it.
	if ([self removeOnlyDS_Store]) {
		[dropInfoText setStringValue: NSLocalizedString(@"Only .DS_Store files will be removed.", nil)];
	} else {
		[dropInfoText setStringValue: NSLocalizedString(@"All resource information will be removed.", nil)];
	}

	[dropWindow makeKeyAndOrderFront: self];
	return YES;
}

- (void) application: (NSApplication *) sender openFiles: (NSArray *) filenames {
// This method is called when one or more files are dragged to ZipCleaner. It just sees if the user wants to remove all resource information or not and then
// passes this with the filenames along.
	[self setUpFiles: filenames removingOnlyDS_Store: [self removeOnlyDS_Store]];
}

@end

#pragma mark-
@implementation	NSMutableArray (ZipCleaner)

- (void) removeDuplicates {
// This method removes duplicate entries from an array by transforming it in a nsset and turning that back into the array.
	NSSet *tempSet = [NSSet setWithArray: self];
	[self removeAllObjects];
	NSEnumerator *enumerator = [tempSet objectEnumerator];
	id currentObject;
	
	while (currentObject = [enumerator nextObject]) {
		[self addObject: currentObject];
	}
}
@end



