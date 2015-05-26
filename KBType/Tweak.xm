#import "../../PS.h"

@interface UIWindow (Private)
@property int interfaceOrientation;
@end

@interface UIKBTree : NSObject
@end

@interface UIKeyboardAutomatic : UIView
@end

@interface UIKeyboard : UIView
@end

@interface _UIKBCompatInputView : UIView
@end

@interface UIInputSetHostView : UIView
@end

@interface UIInputSetContainerView : UIView
@end

@interface UIInputWindowController : UIViewController
@end

@interface UIKeyboardInputMode : NSObject
@property(retain, nonatomic) NSString *identifier;
@end

@interface UIKBScreenTraits : NSObject
@property(readonly) int idiom;
@property(retain, readonly) UIScreen *screen;
@property CGFloat keyboardWidth;
@end

@interface TIKeyboardLayoutFactory : NSObject {
	void *_layoutsLibraryHandle;
}
+ (TIKeyboardLayoutFactory *)sharedKeyboardFactory;
+ (NSString *)layoutsFileName;
@property(readonly, nonatomic) void *layoutsLibraryHandle;
@property(retain) NSMutableDictionary *internalCache;
- (UIKBTree *)keyboardWithName:(NSString *)name inCache:(NSMutableDictionary *)cache;
@end

NSString *(*UIKeyboardGetKBStarName)(NSString *, UIKBScreenTraits *, int, int);

//BOOL overrideIdiom = NO;

%hook UIKBScreenTraits

// A dirty workaround fixing keyboard width
- (id)initWithScreen:(UIScreen *)screen orientation:(int)orientation
{
	self = %orig(screen, [screen respondsToSelector:@selector(_interfaceOrientation)] ? screen._interfaceOrientation : orientation);
	//NSLog(@"%@ (%d) -> %f", NSStringFromCGRect(screen.bounds), orientation, self.keyboardWidth);
	return self;
}

/*- (UIUserInterfaceIdiom)idiom
{
	return overrideIdiom ? 1 : %orig;
}*/

%end

static NSArray *_widths_portrait = nil;
static NSArray *widths_portrait()
{
	return @[
		@768.0f,
		@414.0f,
		@375.0f,
		@320.0f
	];
}

static NSArray *_widths_landscape = nil;
static NSArray *widths_landscape()
{
	return @[
		@1024.0f,
		@736.0f,
		@667.0f,
		@568.0f,
		@480.0f
	];
}

int variant = 3;

// iPhone 4/4s: 320, 480 (0)
// iPhone 5/5c/5s, iPod 5: 320, 568 (1)
// iPhone 6: 375, 667 (2)
// iPhone 6 plus: 414, 736 (3)
// iPad: 1024, 768 (4)

extern "C" CGFloat newWidth(CGFloat width)
{
	BOOL portrait = [_widths_portrait containsObject:@(width)];
	BOOL landscape = [_widths_landscape containsObject:@(width)];
	if (portrait) {
		switch (variant) {
			case 0:
				return 320.0f;
			case 1:
				return 320.0f;
			case 2:
				return 375.0f;
			case 3:
				return 414.0f;
			case 4:
				return 1024.0f;
		}
	}
	else if (landscape) {
		switch (variant) {
			case 0:
				return 480.0f;
			case 1:
				return 568.0f;
			case 2:
				return 667.0f;
			case 3:
				return 736.0f;
			case 4:
				return 768.0f;
		}
	}
	return width;
}

BOOL overridePrefix = NO;

%hook TIKeyboardLayoutFactory

- (NSString *)keyboardPrefixForWidth:(CGFloat)width
{
	CGFloat _newWidth = newWidth(width);
	//NSLog(@"%f -> %f", width, _newWidth);
	return overridePrefix ? %orig(_newWidth) : %orig;
}

%end

%hook UIInputSetContainerView

- (void)setFrame:(CGRect)frame
{
	if (frame.size.width > 0.0f) {
		CGFloat origX = newWidth(frame.size.width);
		CGFloat factor = UIScreen.mainScreen.bounds.size.width / origX;
		CGAffineTransform t = CGAffineTransformMakeScale(factor, factor);
		self.transform = t;
		%orig;
		return;
	}
	%orig;
}

%end

%group iMessages

// iMessages' CKMessageEntryView is problematic.

@interface CKMessageEntryView : UIView
@end

@interface CKTranscriptController : UIViewController
@property(retain, nonatomic) CKMessageEntryView *entryView;
@end

BOOL overrideWidth = NO;

%hook UIScreen

- (CGRect)bounds
{
	CGRect bounds = %orig;
	if (overrideWidth) {
		CGFloat newBoundsWidth = newWidth(bounds.size.width);
		CGRect newBounds = CGRectMake(bounds.origin.x, bounds.origin.y, newBoundsWidth, bounds.size.height);
		return newBounds;
	}
	return bounds;
}

- (CGRect)_referenceBounds
{
	CGRect bounds = %orig;
	if (overrideWidth) {
		CGFloat newBoundsWidth = newWidth(bounds.size.width);
		CGRect newBounds = CGRectMake(bounds.origin.x, bounds.origin.y, newBoundsWidth, bounds.size.height);
		return newBounds;
	}
	return bounds;
}

%end

%hook CKMessageEntryView

- (BOOL)translatesAutoresizingMaskIntoConstraints
{
	return NO;
}

- (void)setTranslatesAutoresizingMaskIntoConstraints:(BOOL)arg1
{
	%orig(NO);
}

%end

%hook CKTranscriptController

- (BOOL)getContainerWidth:(CGFloat *)width offset:(CGFloat *)offset
{
	CGFloat aWidth;
	overrideWidth = YES;
	BOOL orig = %orig(&aWidth, offset);
	overrideWidth = NO;
	if (orig) {
		CGFloat _newWidth = newWidth(aWidth);
		*width = _newWidth;
		if (*offset > 0.0f) {
			if (self.view) {
				CGRect viewRect = self.view.bounds;
				CGFloat viewWidth = viewRect.size.width;
				CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
				CGFloat factor = newWidth(screenWidth) / screenWidth;
				CGFloat newViewWidth = factor * viewWidth;
				CGFloat delta = newViewWidth - viewWidth;
				*offset -= delta;
				*width += delta;
			}
		}
	}
	return orig;
}

- (CGSize)_idealSizeForEntryView
{
	CGSize size = %orig;
	CGFloat _newWidth = newWidth(size.width);
	CGSize newSize = CGSizeMake(_newWidth, size.height);
	return newSize;
}

%end

%end

MSHook(NSString *, UIKeyboardGetKBStarName, NSString *inputMode, UIKBScreenTraits *traits, int keyboardType, int keyboardBias)
{
	//overrideIdiom = YES;
	overridePrefix = YES;
	NSString *name = _UIKeyboardGetKBStarName(inputMode, traits, keyboardType, keyboardBias);
	//overrideIdiom = NO;
	overridePrefix = NO;
	//NSLog(@"kb name: %@", name);
	return name;
}

%ctor
{
	_widths_landscape = widths_landscape();
	_widths_portrait = widths_portrait();
	dlopen("/System/Library/PrivateFrameworks/TextInput.framework/TextInput", RTLD_LAZY);
	MSImageRef ref = MSGetImageByName("/System/Library/Frameworks/UIKit.framework/UIKit");
	UIKeyboardGetKBStarName = (NSString *(*)(NSString *, UIKBScreenTraits *, int, int))MSFindSymbol(ref, "_UIKeyboardGetKBStarName");
	MSHookFunction(UIKeyboardGetKBStarName, MSHake(UIKeyboardGetKBStarName));
	%init;
	if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.MobileSMS"]) {
		%init(iMessages);
	}
}
