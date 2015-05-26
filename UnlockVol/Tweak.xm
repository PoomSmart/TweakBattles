#import "../../PS.h"

BOOL unlock = NO;

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
	unlock = YES;
	%orig;
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