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
static BOOL enableIconInteraction = YES;
static NSInteger iconAnimationStyle = 0;
static NSInteger animationStyle = 0;
static NSInteger speedMode = 1;

#define PREFS_DOMAIN @"com.tudepzai.appanimationprefs"
#define NOTIFY_CHANGE "com.tudepzai.appanimationprefs/reload"

static void loadPrefs() {
    CFPreferencesAppSynchronize((__bridge CFStringRef)PREFS_DOMAIN);
    
    Boolean validEnabled;
    Boolean bEnabled = CFPreferencesGetAppBooleanValue(CFSTR("enabled"), (__bridge CFStringRef)PREFS_DOMAIN, &validEnabled);
    enabled = validEnabled ? bEnabled : YES;

    Boolean validIcon;
    Boolean bIcon = CFPreferencesGetAppBooleanValue(CFSTR("enableIconInteraction"), (__bridge CFStringRef)PREFS_DOMAIN, &validIcon);
    enableIconInteraction = validIcon ? bIcon : YES;

    Boolean validIconStyle;
    CFIndex iconStyleVal = CFPreferencesGetAppIntegerValue(CFSTR("iconAnimationStyle"), (__bridge CFStringRef)PREFS_DOMAIN, &validIconStyle);
    iconAnimationStyle = validIconStyle ? iconStyleVal : 0;

    Boolean validStyle;
    CFIndex styleVal = CFPreferencesGetAppIntegerValue(CFSTR("animationStyle"), (__bridge CFStringRef)PREFS_DOMAIN, &validStyle);
    animationStyle = validStyle ? styleVal : 0;

    Boolean validSpeed;
    CFIndex speedVal = CFPreferencesGetAppIntegerValue(CFSTR("speedMode"), (__bridge CFStringRef)PREFS_DOMAIN, &validSpeed);
    speedMode = validSpeed ? speedVal : 1;
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
// 3. HOOK ICON VIEW (SAFE & THREAD-SAFE)
// ========================================================

%hook SBIconView

- (void)setHighlighted:(BOOL)highlighted {
    %orig;

    if (!enabled) return;

    // Đảm bảo chạy trên Main Thread để tránh Crash
    dispatch_async(dispatch_get_main_queue(), ^{
        if (highlighted) {
            UIWindow *window = self.window;
            if (window && CGRectGetWidth(self.bounds) > 0) {
                gSourceIconFrame = [self convertRect:self.bounds toView:window];
                gHasSourceFrame = YES;
            }
        }

        if (!enableIconInteraction) return;

        if (highlighted) {
            if (iconAnimationStyle == 0) {
                [UIView animateWithDuration:0.12 delay:0.0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
                    CGAffineTransform scale = CGAffineTransformMakeScale(0.80, 0.80);
                    CGAffineTransform rotate = CGAffineTransformMakeRotation(-0.25);
                    self.transform = CGAffineTransformConcat(scale, rotate);
                } completion:nil];
            }
        } else {
            if (iconAnimationStyle == 0) {
                [UIView animateWithDuration:0.5
                                      delay:0.0
                     usingSpringWithDamping:0.45
                      initialSpringVelocity:0.8
                                    options:UIViewAnimationOptionAllowUserInteraction
                                 animations:^{
                    self.transform = CGAffineTransformIdentity;
                } completion:nil];
            }
        }
    });
}

%end

// ========================================================
// 4. HOOK APP SCENE VIEW (CLEAN MEMORY & NO SAFE MODE)
// ========================================================

%hook SBDeviceApplicationSceneView

- (void)didMoveToWindow {
    %orig;

    if (!enabled || self.window == nil) return;

    // Đẩy xử lý Animation vào Main Thread sạch
    dispatch_async(dispatch_get_main_queue(), ^{
        NSTimeInterval duration = getAnimationDuration();
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        CGFloat screenH = screenBounds.size.height;
        CGFloat screenW = screenBounds.size.width;

        // Dọn dẹp animation cũ chống tràn bộ nhớ
        [self.layer removeAllAnimations];

        // ----------------------------------------------------
        // KIỂU 0: LAN TỪ GÓC PHẢI
        // ----------------------------------------------------
        if (animationStyle == 0) {
            self.layer.cornerRadius = 38.0;
            self.layer.cornerCurve = kCACornerCurveContinuous;
            self.layer.masksToBounds = YES;

            CGFloat dx = screenW / 2;
            CGFloat dy = -(screenH / 2);

            CGAffineTransform scale = CGAffineTransformMakeScale(0.01, 0.01);
            CGAffineTransform translate = CGAffineTransformMakeTranslation(dx, dy);

            self.transform = CGAffineTransformConcat(scale, translate);
            self.alpha = 0.0;

            [UIView animateWithDuration:duration
                                  delay:0.0
                 usingSpringWithDamping:0.85
                  initialSpringVelocity:0.5
                                options:UIViewAnimationOptionCurveEaseInOut
                             animations:^{
                self.alpha = 1.0;
                self.transform = CGAffineTransformIdentity;
            } completion:^(BOOL finished) {
                self.layer.cornerRadius = 0.0;
            }];
        } 
        // ----------------------------------------------------
        // KIỂU 1: TRẢI KHĂN 3D
        // ----------------------------------------------------
        else if (animationStyle == 1) {
            self.frame = screenBounds;
            self.alpha = 0.0;

            self.layer.cornerRadius = 38.0;
            self.layer.cornerCurve = kCACornerCurveContinuous;
            self.layer.masksToBounds = YES; 

            CGPoint iconCenter = gHasSourceFrame ? 
                CGPointMake(CGRectGetMidX(gSourceIconFrame), CGRectGetMidY(gSourceIconFrame)) : 
                CGPointMake(screenW / 2, screenH / 2);

            CGFloat offsetX = iconCenter.x - (screenW / 2);
            CGFloat offsetY = iconCenter.y - (screenH / 2);
            CGFloat startScaleX = gHasSourceFrame ? (gSourceIconFrame.size.width / screenW) : 0.15;

            CATransform3D p = CATransform3DIdentity;
            p.m34 = -1.0 / 300.0;

            CATransform3D tStart = p;
            tStart = CATransform3DTranslate(tStart, offsetX, offsetY, -200);
            tStart = CATransform3DRotate(tStart, M_PI_2 * 0.8, 1.0, 0.0, 0.0);
            tStart = CATransform3DScale(tStart, startScaleX, 0.05, 1.0);

            self.layer.transform = tStart;

            [UIView animateWithDuration:duration * 0.50
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                self.alpha = 1.0;
                CATransform3D tWave = p;
                tWave = CATransform3DTranslate(tWave, offsetX * 0.3, offsetY * 0.3, 30);
                tWave = CATransform3DRotate(tWave, -M_PI / 8.0, 1.0, 0.0, 0.0);
                tWave = CATransform3DScale(tWave, 0.92, 0.78, 1.0);
                self.layer.transform = tWave;
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:duration * 0.50
                                      delay:0.0
                     usingSpringWithDamping:0.75
                      initialSpringVelocity:0.6
                                    options:UIViewAnimationOptionCurveEaseInOut
                                 animations:^{
                    self.layer.transform = CATransform3DIdentity;
                    self.frame = screenBounds;
                } completion:^(BOOL fin) {
                    self.layer.cornerRadius = 0.0;
                    gHasSourceFrame = NO;
                }];
            }];
        }
        // ----------------------------------------------------
        // KIỂU 2: 26ANIM (KHẮC PHỤC HOÀN TOÀN CRASH SAFE MODE)
        // ----------------------------------------------------
        else if (animationStyle == 2) {
            self.frame = screenBounds;
            self.alpha = 1.0;

            self.layer.cornerRadius = 38.0;
            self.layer.cornerCurve = kCACornerCurveContinuous;
            self.layer.masksToBounds = YES;

            CGPoint iconCenter = gHasSourceFrame ? 
                CGPointMake(CGRectGetMidX(gSourceIconFrame), CGRectGetMidY(gSourceIconFrame)) : 
                CGPointMake(screenW / 2, screenH / 2);

            CGFloat offsetX = iconCenter.x - (screenW / 2);
            CGFloat offsetY = iconCenter.y - (screenH / 2);

            CATransform3D p = CATransform3DIdentity;
            p.m34 = -1.0 / 400.0;

            CATransform3D t0 = p;
            t0 = CATransform3DTranslate(t0, offsetX, offsetY, -150);
            t0 = CATransform3DScale(t0, 0.12, 0.12, 1.0);

            CATransform3D t1 = p;
            t1 = CATransform3DTranslate(t1, screenW * 0.05, 0, -35);
            t1 = CATransform3DRotate(t1, -M_PI / 6.5, 0.0, 1.0, 0.0);
            t1 = CATransform3DScale(t1, 0.88, 0.93, 1.0);

            CATransform3D t2 = p;
            t2 = CATransform3DTranslate(t2, 0, 0, -10);
            t2 = CATransform3DScale(t2, 0.965, 0.975, 1.0);

            CATransform3D t3 = CATransform3DIdentity;

            CAKeyframeAnimation *anim3D = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
            anim3D.values = @[
                [NSValue valueWithCATransform3D:t0],
                [NSValue valueWithCATransform3D:t1],
                [NSValue valueWithCATransform3D:t2],
                [NSValue valueWithCATransform3D:t3]
            ];
            anim3D.keyTimes = @[@0.0, @0.38, @0.72, @1.0];
            anim3D.duration = duration;
            anim3D.timingFunctions = @[
                [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
                [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]
            ];

            // FIX SAFE MODE: Bật tự động xóa animation khi hoàn tất để giải phóng RAM
            anim3D.removedOnCompletion = YES;
            anim3D.fillMode = kCAFillModeForwards;

            [self.layer addAnimation:anim3D forKey:@"26anim_transform"];
            self.layer.transform = t3;

            // Xử lý ẩn bo góc an toàn bằng UIView Animation chính chủ
            [UIView animateWithDuration:0.15 delay:duration - 0.1 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.layer.cornerRadius = 0.0;
            } completion:^(BOOL finished) {
                gHasSourceFrame = NO;
            }];
        }
    });
}

%end

// ========================================================
// 5. INITIALIZER
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
