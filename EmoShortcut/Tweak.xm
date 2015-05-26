#import "../../PS.h"

@interface TIUserDictionaryEntryValue : NSObject
@property(retain, nonatomic) NSString *shortcut;
@end

@interface TIUserDictionaryTransaction : NSObject
@property(retain, nonatomic) TIUserDictionaryEntryValue *valueToInsert;
@end

%hook TIUserDictionaryWord

+ (int)validateTransaction:(TIUserDictionaryTransaction *)transaction existingEntries:(id)arg2
{
	NSString *shortcut = transaction.valueToInsert.shortcut;
	int validation = %orig;
	NSLog(@"%@ %d", shortcut, validation);
	return validation == 9 ? 0 : validation;
}

%end

/*%hook ListUserWordsController

- (void)reloadSections
{
	NSLog(@"%@", [[self dictionaryController] entries]);
	%orig;
}

%end*/

/*%hook TIUserDictionaryController

- (id)entries
{
	NSLog(@"before %@", [self cachedEntries]);
	id entries = %orig;
	NSLog(@"after %@", [self cachedEntries]);
	return entries;
}

%end*/

%hook UILocalizedIndexedCollation

- (NSInteger)sectionForObject:(id)obj collationStringSelector:(SEL)sel
{
	//NSLog(@"%@", obj);
	NSInteger r = %orig;
	//NSLog(@"%d", r);
	return r;
}

%end

%ctor
{
	dlopen("/System/Library/PrivateFrameworks/TextInput.framework/TextInput", RTLD_LAZY);
	dlopen("/System/Library/PreferenceBundles/KeyboardSettings.bundle/KeyboardSettings", RTLD_LAZY);
	%init;
}