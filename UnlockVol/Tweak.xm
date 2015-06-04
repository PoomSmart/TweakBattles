#import "../../PS.h"
#import <notify.h>

@interface SBUserAgent : NSObject
+ (SBUserAgent *)sharedUserAgent;
- (void)undimScreen;
@end

@interface SBAwayController : NSObject
+ (SBAwayController *)sharedAwayController;
- (BOOL)isLocked;
- (BOOL)isDimmed;
- (void)attemptUnlockFromSource:(int)source;
@end

@interface SBLockScreenViewController : NSObject
- (BOOL)isInScreenOffMode;
@end

@interface SBLockScreenManager : NSObject
+ (SBLockScreenManager *)sharedInstance;
- (BOOL)isUILocked;
- (SBLockScreenViewController *)lockScreenViewController;
- (void)unlockUIFromSource:(int)source withOptions:(NSDictionary *)options;
@end

BOOL unlock = NO;

static BOOL boolForKey(NSString *key, BOOL orig)
{
	id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
	return value ? [value boolValue] : orig;
}

#define screenOff boolForKey(@"UnlockVol_screenOff", YES)
#define wakeDevice boolForKey(@"UnlockVol_wakeDevice", NO)
#define enabled boolForKey(@"UnlockVol_enabled", YES)

static BOOL isUILocked()
{
	BOOL uiLocked = NO;
	if (%c(SBLockScreenManager)) {
		SBLockScreenManager *manager = (SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance];
		uiLocked = [manager isUILocked];
	}
	else if (%c(SBAwayController)) {
		SBAwayController *cont = (SBAwayController *)[%c(SBAwayController) sharedAwayController];
		uiLocked = [cont isLocked];
	}
	return uiLocked;
}

static BOOL isInScreenOffMode()
{
	BOOL _screenOff = NO;
	if (%c(SBLockScreenManager)) {
		SBLockScreenManager *manager = (SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance];
		SBLockScreenViewController *lock = [manager lockScreenViewController];
		_screenOff = [lock isInScreenOffMode];
	}
	else if (%c(SBAwayController)) {
		SBAwayController *cont = (SBAwayController *)[%c(SBAwayController) sharedAwayController];
		_screenOff = [cont isDimmed];
		/*int notify_token;
		static uint64_t state = UINT64_MAX;
		notify_register_dispatch("com.apple.springboard.hasBlankedScreen", &notify_token, dispatch_get_main_queue(), ^(int token) {
    		notify_get_state(token, &state);
    	});
    	_screenOff = state == 1;*/
	}
	return _screenOff;
}

static void turnOnScreenIfNeeded()
{
	if (!wakeDevice || !enabled)
		return;
	if (isInScreenOffMode() && isUILocked()) {
		if (%c(SBLockScreenManager)) {
			SBLockScreenManager *manager = (SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance];
			NSDictionary *options = @{ @"SBUIUnlockOptionsTurnOnScreenFirstKey" : [NSNumber numberWithBool:YES] };
			[manager unlockUIFromSource:6 withOptions:options];
		}
		else /*if (%c(SBAwayController))*/ {
			/*SBAwayController *cont = (SBAwayController *)[%c(SBAwayController) sharedAwayController];
			[cont attemptUnlockFromSource:0];*/
			SBUserAgent *agent = (SBUserAgent *)[%c(SBUserAgent) sharedUserAgent];
			[agent undimScreen];
		}
	}
}

%group ModernOS

%hook SBLockScreenManager

- (BOOL)isUILocked
{
	return unlock ? NO : %orig;
}

%end

%end

%group LegacyOS

%hook SBAwayController

- (BOOL)isLocked
{
	return unlock ? NO : %orig;
}

%end

%end

%hook VolumeControl

- (void)_changeVolumeBy:(float)vol
{
	unlock = enabled;
	if (!screenOff && isInScreenOffMode())
		unlock = NO;
	%orig;
	turnOnScreenIfNeeded();
	unlock = NO;
}

%end

%ctor
{
	if (isiOS7Up) {
		%init(ModernOS);
	} else {
		%init(LegacyOS);
	}
	%init;
}