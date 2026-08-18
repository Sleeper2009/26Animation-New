#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

// ========================================================
// 1. INTERFACES & GLOBAL VARS
// ========================================================

@interface SBIconView : UIView
- (CGRect)bounds;
- (CGPoint)convertPoint:(CGPoint)point toView:(UIView *)view;
@end

@interface SBDeviceApplicationSceneView : UIView
@end

static CGRect gSourceIconFrame = (CGRect){{0, 0}, {0, 0}};
static BOOL gHasSourceFrame = NO;

// ========================================================
// 2. PREFERENCES & CONFIGURATION
// ========================================================

static BOOL enabled = YES;
static NSInteger speedMode = 1;

static CGFloat lgBounceAmount = 42.0;
static CGFloat lgPeakRadius = 120.0;
static CGFloat lgEndRadius = 20.0;

#define PREFS_DOMAIN @"com.tudepzai.appanimationprefs"
#define NOTIFY_CHANGE "com.tudepzai.appanimationprefs/reload"

static void loadPrefs() {
    CFPreferencesAppSynchronize((__bridge CFStringRef)PREFS_DOMAIN);

    Boolean validEnabled;
    Boolean bEnabled = CFPreferencesGetAppBooleanValue(CFSTR("enabled"), (__bridge CFStringRef)PREFS_DOMAIN, &validEnabled);
    enabled = validEnabled ? bEnabled : YES;

    Boolean validSpeed;
    CFIndex speedVal = CFPreferencesGetAppIntegerValue(CFSTR("speedMode"), (__bridge CFStringRef)PREFS_DOMAIN, &validSpeed);
    speedMode = validSpeed ? speedVal : 1;

    CFPropertyListRef bounceVal = CFPreferencesCopyAppValue(CFSTR("lgBounceAmount"), (__bridge CFStringRef)PREFS_DOMAIN);
    if (bounceVal) {
        if (CFGetTypeID(bounceVal) == CFNumberGetTypeID()) {
            CFNumberGetValue((CFNumberRef)bounceVal, kCFNumberDoubleType, &lgBounceAmount);
        }
        CFRelease(bounceVal);
    }

    CFPropertyListRef peakVal = CFPreferencesCopyAppValue(CFSTR("lgPeakRadius"), (__bridge CFStringRef)PREFS_DOMAIN);
    if (peakVal) {
        if (CFGetTypeID(peakVal) == CFNumberGetTypeID()) {
            CFNumberGetValue((CFNumberRef)peakVal, kCFNumberDoubleType, &lgPeakRadius);
        }
        CFRelease(peakVal);
    }

    CFPropertyListRef endVal = CFPreferencesCopyAppValue(CFSTR("lgEndRadius"), (__bridge CFStringRef)PREFS_DOMAIN);
    if (endVal) {
        if (CFGetTypeID(endVal) == CFNumberGetTypeID()) {
            CFNumberGetValue((CFNumberRef)endVal, kCFNumberDoubleType, &lgEndRadius);
        }
        CFRelease(endVal);
    }
}

static NSTimeInterval getAnimationDuration() {
    switch (speedMode) {
        case 0:  return 1.10;
        case 1:  return 0.70;
        case 2:  return 0.40;
        default: return 0.70;
    }
}

// ========================================================
// 3. LIQUID MORPH - PERSPECTIVE TRANSFORM THAT
// ========================================================

static CATransform3D LMPerspectiveTransformAtProgress(CGFloat t, CGRect iconFrame, CGRect screen,
                                                       CGFloat bounceAmount) {
    CGFloat screenW = screen.size.width;
    CGFloat screenH = screen.size.height;

    CGFloat iconCenterX = CGRectGetMidX(iconFrame);
    CGFloat iconCenterY = CGRectGetMidY(iconFrame);
    CGFloat screenCenterX = screenW / 2.0;
    CGFloat screenCenterY = screenH / 2.0;

    CGFloat normX = (iconCenterX - screenCenterX) / screenCenterX;
    CGFloat normY = (iconCenterY - screenCenterY) / screenCenterY;
    normX = MAX(-1.0, MIN(1.0, normX));
    normY = MAX(-1.0, MIN(1.0, normY));

    CGFloat startScaleX = MAX(0.05, iconFrame.size.width / screenW);
    CGFloat startScaleY = MAX(0.05, iconFrame.size.height / screenH);

    CGFloat eased = 1.0 - powf(1.0 - t, 3.0);

    CGFloat maxTiltRad = 0.62;
    CGFloat tiltFactor = powf(1.0 - t, 1.6);
    CGFloat rotateX = -normY * maxTiltRad * tiltFactor;
    CGFloat rotateY = normX * maxTiltRad * tiltFactor;

    CGFloat bounceDirection = (iconCenterY > screenCenterY) ? -1.0 : 1.0;
    CGFloat bounceNorm = bounceAmount / 100.0;
    CGFloat bounceEnvelope = sinf(MIN(t, 1.0) * (CGFloat)M_PI) * bounceNorm * 40.0 * bounceDirection;

    CGFloat scaleX = startScaleX + (1.0 - startScaleX) * eased;
    CGFloat scaleY = startScaleY + (1.0 - startScaleY) * eased;

    CGFloat offsetX = (iconCenterX - screenCenterX) * (1.0 - eased);
    CGFloat offsetY = (iconCenterY - screenCenterY) * (1.0 - eased) + bounceEnvelope * (1.0 - eased);

    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = -1.0 / 500.0;

    transform = CATransform3DTranslate(transform, offsetX, offsetY, 0);
    transform = CATransform3DRotate(transform, rotateX, 1.0, 0.0, 0.0);
    transform = CATransform3DRotate(transform, rotateY, 0.0, 1.0, 0.0);
    transform = CATransform3DScale(transform, scaleX, scaleY, 1.0);

    return transform;
}

static CGFloat LMHumpRadius(CGFloat t, CGFloat iconRadius, CGFloat peakRadius, CGFloat endRadius) {
    if (t < 0.45) {
        CGFloat local = t / 0.45;
        return iconRadius + (peakRadius - iconRadius) * local;
    } else {
        CGFloat local = (t - 0.45) / 0.55;
        if (local > 1) local = 1;
        return peakRadius + (endRadius - peakRadius) * local;
    }
}

static void LMBuildKeyframes(CGRect iconFrame, CGRect screen, CGFloat bounceAmount,
                              CGFloat peakRadius, CGFloat endRadius,
                              NSArray **outTransforms, NSArray **outRadii) {
    NSInteger steps = 30;
    NSMutableArray *transforms = [NSMutableArray array];
    NSMutableArray *radii = [NSMutableArray array];
    CGFloat iconRadius = 13.0;

    for (NSInteger i = 0; i <= steps; i++) {
        CGFloat t = (CGFloat)i / (CGFloat)steps;
        CATransform3D tr = LMPerspectiveTransformAtProgress(t, iconFrame, screen, bounceAmount);
        [transforms addObject:[NSValue valueWithCATransform3D:tr]];
        [radii addObject:@(LMHumpRadius(t, iconRadius, peakRadius, endRadius))];
    }

    *outTransforms = transforms;
    *outRadii = radii;
}

// ========================================================
// 4. HOOK ICON VIEW - CHI GHI LAI VI TRI
// ========================================================

%hook SBIconView

- (void)setHighlighted:(BOOL)highlighted {
    %orig;

    if (!enabled || !highlighted) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = self.window;
        if (window && CGRectGetWidth(self.bounds) > 0) {
            gSourceIconFrame = [self convertRect:self.bounds toView:window];
            gHasSourceFrame = YES;
        }
    });
}

%end

// ========================================================
// 5. HOOK APP SCENE VIEW - LIQUID MORPH
// ========================================================

%hook SBDeviceApplicationSceneView

- (void)didMoveToWindow {
    %orig;

    if (!enabled || self.window == nil) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        NSTimeInterval duration = getAnimationDuration();
        CGRect screenBounds = [UIScreen mainScreen].bounds;

        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [self.layer removeAllAnimations];
        self.layer.mask = nil;
        [CATransaction commit];

        self.frame = screenBounds;
        self.alpha = 1.0;
        self.layer.masksToBounds = YES;
        self.layer.cornerCurve = kCACornerCurveContinuous;

        CGRect iconFrame = gHasSourceFrame ? gSourceIconFrame :
            CGRectMake(screenBounds.size.width / 2 - 30, screenBounds.size.height / 2 - 30, 60, 60);

        NSArray *transforms;
        NSArray *radii;
        LMBuildKeyframes(iconFrame, screenBounds, lgBounceAmount, lgPeakRadius, lgEndRadius,
                          &transforms, &radii);

        CAKeyframeAnimation *transformAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
        transformAnim.values = transforms;
        transformAnim.duration = duration;
        transformAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transformAnim.fillMode = kCAFillModeForwards;
        transformAnim.removedOnCompletion = NO;
        [self.layer addAnimation:transformAnim forKey:@"liquidmorph_transform"];
        self.layer.transform = [transforms.lastObject CATransform3DValue];

        CAKeyframeAnimation *radiusAnim = [CAKeyframeAnimation animationWithKeyPath:@"cornerRadius"];
        radiusAnim.values = radii;
        radiusAnim.duration = duration;
        radiusAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        radiusAnim.fillMode = kCAFillModeForwards;
        radiusAnim.removedOnCompletion = NO;
        [self.layer addAnimation:radiusAnim forKey:@"liquidmorph_radius"];
        self.layer.cornerRadius = [radii.lastObject floatValue];

        CABasicAnimation *fadeAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fadeAnim.fromValue = @0.0;
        fadeAnim.toValue = @1.0;
        fadeAnim.duration = duration * 0.18;
        fadeAnim.removedOnCompletion = YES;
        [self.layer addAnimation:fadeAnim forKey:@"liquidmorph_fade"];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((duration + 0.05) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.layer.masksToBounds = NO;
            self.layer.cornerRadius = 0.0;
            gHasSourceFrame = NO;
        });
    });
}

%end

// ========================================================
// 6. INITIALIZER
// ========================================================

%ctor {
    loadPrefs();

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        (CFNotificationCallback)loadPrefs,
        CFSTR(NOTIFY_CHANGE),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
}
