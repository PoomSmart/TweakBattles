#import <substrate.h>

@interface TIInputMode : NSObject
@property(retain, nonatomic) NSString *normalizedIdentifier;
@end

@interface UIKeyboardInputMode : NSObject
@property(retain, nonatomic) NSString *identifier;
@property(retain, nonatomic) NSString *normalizedIdentifier;
@end

@interface UIKeyboardInputModeController : NSObject
+ (UIKeyboardInputModeController *)sharedInputModeController;
@property(retain, nonatomic) UIKeyboardInputMode *currentInputMode;
@end

extern "C" BOOL UIKeyboardPredictionEnabledForCurrentInputMode();
MSHook(BOOL, UIKeyboardPredictionEnabledForCurrentInputMode)
{
	UIKeyboardInputMode *currentInputMode = UIKeyboardInputModeController.sharedInputModeController.currentInputMode;
	NSString *identifier = currentInputMode.normalizedIdentifier;
	BOOL isEmoji = [identifier isEqualToString:@"emoji"];
	return isEmoji ? YES : _UIKeyboardPredictionEnabledForCurrentInputMode();
}

%group kbd

static CFCharacterSetRef emojiCharSet = NULL;
BOOL emojiCharSetExisted = NO;

typedef struct {
	uint16_t numBytes;
	uint16_t var1;
	uint16_t var2;
	uint8_t var3;
	char gap_7[1];
	char *character;
	char bytes[16];
} String;

CFStringRef (*KB__cf_string)(String *);

MSHook(CFStringRef, KB__cf_string, String *string)
{
	//char *bytes = string->bytes;
	char *character = string->character;
	if (character == NULL)
		character = string->bytes;
	CFStringRef cfString = CFStringCreateWithBytes(NULL, (const UInt8 *)character, string->numBytes, kCFStringEncodingUTF8, YES);
	if (cfString == NULL) {
		cfString = CFStringCreateWithBytes(NULL, (const UInt8 *)character, string->numBytes, kCFStringEncodingUTF16LE, YES);
		//cfString = NULL;
	}
	return cfString;
	//return _KB__cf_string(string);
}

%hook TIKeyboardInputManagerZephyr

- (BOOL)acceptsCharacter:(uint32_t)character
{
	BOOL accept = %orig;
	if (!accept) {
		if (emojiCharSet == NULL && !emojiCharSetExisted) {
			NSString *path = [[NSBundle bundleWithIdentifier:@"com.apple.TextInput"] pathForResource:@"TIUserDictionaryEmojiCharacterSet" ofType:@"bitmap"];
			NSCharacterSet *set = [NSCharacterSet characterSetWithContentsOfFile:path];
			if (set) {
				emojiCharSetExisted = YES;
				emojiCharSet = CFCharacterSetCreateCopy(kCFAllocatorDefault, (CFCharacterSetRef)set);
			}
		}
		if (emojiCharSetExisted) {
			Boolean emoji = CFCharacterSetIsCharacterMember(emojiCharSet, character);
			if (emoji)
				return YES;
		}
	}
	return accept;
}

- (id)autocorrectionList
{
	NSLog(@"%@", [self topCandidate]);
	id r = %orig;
	return r;
}

%end

%hook TIInputMode

- (Class)inputManagerClass
{
	NSString *identifier = self.normalizedIdentifier;
	BOOL isEmoji = [identifier isEqualToString:@"emoji"];
	return isEmoji ? %c(TIKeyboardInputManagerZephyr) : %orig;
}

%end

%end

%ctor
{
	NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
	NSUInteger count = args.count;
	if (count != 0) {
		NSString *executablePath = args[0];
		if (executablePath) {
			BOOL isApplication = [executablePath rangeOfString:@"/Application"].location != NSNotFound;
			BOOL isSpringBoard = [[executablePath lastPathComponent] isEqualToString:@"SpringBoard"];
			BOOL is_kbd = [[executablePath lastPathComponent] isEqualToString:@"kbd"];
			if ((isApplication || isSpringBoard) && !is_kbd) {
				MSHookFunction(UIKeyboardPredictionEnabledForCurrentInputMode, MSHake(UIKeyboardPredictionEnabledForCurrentInputMode));
			}
			if (is_kbd) {
				MSImageRef ref = MSGetImageByName("/System/Library/TextInput/libTextInputCore.dylib");
				KB__cf_string = (CFStringRef (*)(String *))MSFindSymbol(ref, "__ZN2KB9cf_stringERKNS_6StringE");
				MSHookFunction(KB__cf_string, MSHake(KB__cf_string));
				%init(kbd);
			}
		}
	}
}