#import <UIKit/UIKit.h>

@interface SBIconView : UIView
@end

%hook SBIconView

// Hook vào sự kiện chạm/mở ứng dụng trên iOS 16
- (void)setHighlighted:(BOOL)highlighted {
    %orig;
    
    if (highlighted) {
        // Khi bắt đầu bấm mở App: Icon thu nhỏ lại 80% và xoay nghiêng -15 độ
        [UIView animateWithDuration:0.15 animations:^{
            CGAffineTransform scale = CGAffineTransformMakeScale(0.80, 0.80);
            CGAffineTransform rotate = CGAffineTransformMakeRotation(-0.25);
            self.transform = CGAffineTransformConcat(scale, rotate);
        }];
    } else {
        // Khi ứng dụng bung ra: Icon bật nảy xoay lại vị trí cũ theo nhịp Spring (đàn hồi)
        [UIView animateWithDuration:0.6
                              delay:0.0
             usingSpringWithDamping:0.35 // Độ nảy đàn hồi (càng nhỏ nảy càng nhiều)
              initialSpringVelocity:0.9  // Tốc độ bật ban đầu
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

%end
