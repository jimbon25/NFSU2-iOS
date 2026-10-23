#pragma once
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

@interface NfsuMetalView : UIView
@property (nonatomic, readonly) CAMetalLayer *metalLayer;
@end

@interface NfsuTouchOverlay : UIView
- (void)updateButtonLayout;
@end

@interface NfsuViewController : UIViewController
@property (nonatomic, strong) NfsuMetalView *metalView;
@property (nonatomic, strong) NfsuTouchOverlay *touchOverlay;
- (void)onFrameTick:(CADisplayLink *)link;
@end

@interface NfsuAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NfsuViewController *viewController;
@end

#ifdef __cplusplus
extern "C" {
#endif

void metal_set_layer(CAMetalLayer *layer);
void metal_render_one_frame(void);
void metal_ios_touch_point(float view_x, float view_y, float view_w, float view_h, int is_down, int is_move);
void nfsu2_grant_career_cash(uint32_t amount);

#ifdef __cplusplus
}
#endif
