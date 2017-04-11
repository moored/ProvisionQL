#import "Shared.h"

NSImage *roundCorners(NSImage *image) {
    NSImage *existingImage = image;
    NSSize existingSize = [existingImage size];
    NSImage *composedImage = [[NSImage alloc] initWithSize:existingSize];
    
    [composedImage lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    
    NSRect imageFrame = NSRectFromCGRect(CGRectMake(0, 0, existingSize.width, existingSize.height));
    NSBezierPath *clipPath = [NSBezierPath bezierPathWithIOS7RoundedRect:imageFrame cornerRadius:existingSize.width*0.225];
    [clipPath setWindingRule:NSEvenOddWindingRule];
    [clipPath addClip];
    
    [image drawAtPoint:NSZeroPoint fromRect:NSMakeRect(0, 0, existingSize.width, existingSize.height) operation:NSCompositeSourceOver fraction:1];
    
    [composedImage unlockFocus];
    
    return composedImage;
}

int expirationStatus(NSDate *date, NSCalendar *calendar) {
	int result = 0;
	
	if (date) {
		NSDateComponents *dateComponents = [calendar components:NSDayCalendarUnit fromDate:[NSDate date] toDate:date options:0];
		if (dateComponents.day <= 0) {
			result = 0;
		} else if (dateComponents.day < 30) {
			result = 1;
		} else {
			result = 2;
		}
	}
    
	return result;
}

NSImage *imageFromApp(NSURL *URL, NSString *dataType, NSString *fileName) {
    NSImage *appIcon = nil;
    
    if([dataType isEqualToString:kDataType_app]) {
        // get the embedded icon for the iOS app
        appIcon = [[NSImage alloc] initWithContentsOfURL:[URL URLByAppendingPathComponent:fileName]];
    } else if([dataType isEqualToString:kDataType_ipa]) {
        // get the embedded icon from an app arcive using: unzip -p <URL> 'Payload/*.app/<fileName>' (piped to standard output)
        NSTask *unzipTask = [NSTask new];
        [unzipTask setLaunchPath:@"/usr/bin/unzip"];
        [unzipTask setStandardOutput:[NSPipe pipe]];
        [unzipTask setArguments:@[@"-l", [URL path], [NSString stringWithFormat:@"Payload/*.app/%@*.png", fileName]]];
        [unzipTask launch];
        [unzipTask waitUntilExit];
		NSString *fileList = [[NSString alloc] initWithData:[[[unzipTask standardOutput] fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
		NSLog(@"Arguments: %@", unzipTask.arguments);
		NSLog(@"resopnse code: %d", unzipTask.terminationStatus);
		NSLog(@"fileList: %@", fileList);

		NSError *error = nil;
		// Find all .png file names excluding the path
		NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[^\\\\/:*?\"<>|]+.png" options:0 error:&error];
		NSMutableArray *files = [NSMutableArray array];
		[regex enumerateMatchesInString:fileList options:0 range:NSMakeRange(0, fileList.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
			NSString *match = [fileList substringWithRange:result.range];
			[files addObject:match];				
		}];
		NSLog(@"Files: %@", files);
		fileName = [files firstObject];
		// If more than one get the highest resolution
		if ([files count] > 1) {
			NSArray *matches = @[@"3x", @"2x"];
			for (NSString *match in matches) {
				NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF contains[c] %@", match];
				NSArray *results = [files filteredArrayUsingPredicate:predicate];
				if ([results count]) {
					fileName = [results firstObject];
					break;
				}
			}
		}
		NSLog(@"File: %@", fileName);
		unzipTask = [NSTask new];
		[unzipTask setLaunchPath:@"/usr/bin/unzip"];
		[unzipTask setStandardOutput:[NSPipe pipe]];
		[unzipTask setArguments:@[@"-p", [URL path], [NSString stringWithFormat:@"Payload/*.app/%@", fileName]]];
		[unzipTask launch];
		[unzipTask waitUntilExit];

        appIcon = [[NSImage alloc] initWithData:[[[unzipTask standardOutput] fileHandleForReading] readDataToEndOfFile]];
    }
    return appIcon;
}

NSString *mainIconNameForApp(NSDictionary *appPropertyList) {
    id icons;
    NSString *iconName;
    
    //Check for CFBundleIcons (since 5.0)
    id iconsDict = [appPropertyList objectForKey:@"CFBundleIcons~ipad"];
	//If not found check for iPhone icons
	if (iconsDict == nil) {
		iconsDict = [appPropertyList objectForKey:@"CFBundleIcons"];
	}
    if([iconsDict isKindOfClass:[NSDictionary class]]) {
        id primaryIconDict = [iconsDict objectForKey:@"CFBundlePrimaryIcon"];
        if([primaryIconDict isKindOfClass:[NSDictionary class]]) {
            id tempIcons = [primaryIconDict objectForKey:@"CFBundleIconFiles"];
            if([tempIcons isKindOfClass:[NSArray class]]) {
                icons = tempIcons;
            }
        }
    }
    
    if(!icons) {
        //Check for CFBundleIconFiles (since 3.2)
        id tempIcons = [appPropertyList objectForKey:@"CFBundleIconFiles"];
        if([tempIcons isKindOfClass:[NSArray class]]) {
            icons = tempIcons;
        }
    }

    if(icons) {
        //Search some patterns for primary app icon (120x120)
        NSArray *matches = @[@"83.5", @"76", @"72", @"60", @"@2x"];
        
        for (NSString *match in matches) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF contains[c] %@",match];
            NSArray *results = [icons filteredArrayUsingPredicate:predicate];
            if([results count]) {
                iconName = [results firstObject];
                break;
            }
        }

        //If no one matches any pattern, just take first item
        if(!iconName) {
            iconName = [icons firstObject];
        }
    } else {
        //Check for CFBundleIconFile (legacy, before 3.2)
        NSString *legacyIcon = [appPropertyList objectForKey:@"CFBundleIconFile"];
        if([legacyIcon length]) {
            iconName = legacyIcon;
        }
    }

    //Load NSImage
    if([iconName length]) {
		if ([iconName.pathExtension isEqualToString:@"png"]) {
			iconName = [iconName stringByDeletingPathExtension];
		}
		NSLog(@"iconName: %@", iconName);
        return iconName;
    }
    
    return nil;
}
