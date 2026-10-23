#import "ios_view.h"
#import <GameController/GameController.h>
#include "kbd.h"
#include <pthread.h>

#define DIK_ESCAPE          0x01
#define DIK_1               0x02
#define DIK_TAB             0x0F
#define DIK_R               0x13
#define DIK_RETURN          0x1C
#define DIK_LSHIFT          0x2A
#define DIK_M               0x32
#define DIK_LMENU           0x38
#define DIK_SPACE           0x39
#define DIK_UP              0xC8
#define DIK_LEFT            0xCB
#define DIK_RIGHT           0xCD
#define DIK_DOWN            0xD0

static inline uint8_t dik_to_vk(unsigned dik) {
    switch (dik) {
    case DIK_ESCAPE: return 0x1B; // VK_ESCAPE
    case DIK_RETURN: return 0x0D; // VK_RETURN
    case DIK_TAB:    return 0x09; // VK_TAB
    case DIK_M:      return 0x4D; // VK_M
    case DIK_R:      return 0x52; // VK_R
    case DIK_1:      return 0x31; // VK_1
    case DIK_UP:     return 0x26; // VK_UP
    case DIK_DOWN:   return 0x28; // VK_DOWN
    case DIK_LEFT:   return 0x25; // VK_LEFT
    case DIK_RIGHT:  return 0x27; // VK_RIGHT
    case DIK_SPACE:  return 0x20; // VK_SPACE
    case DIK_LSHIFT: return 0x10; // VK_SHIFT
    case DIK_LMENU:  return 0x12; // VK_MENU
    default:         return 0;
    }
}

static inline uint32_t dik_to_lparam(unsigned dik, int up) {
    uint32_t sc = dik & 0x7Fu;
    uint32_t ext = (dik & 0x80u) ? (1u << 24) : 0u;
    return 1u | (sc << 16) | ext | (up ? (3u << 30) : 0u);
}

typedef struct {
    CGRect rect;
    unsigned dik;
    const char *label;
    BOOL isDown;
    UITouch *activeTouch;
    CGFloat cornerRadius;
} TouchButton;

@implementation NfsuMetalView

+ (Class)layerClass {
    return [CAMetalLayer class];
}

- (CAMetalLayer *)metalLayer {
    return (CAMetalLayer *)self.layer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.metalLayer.device = MTLCreateSystemDefaultDevice();
        self.metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
        self.metalLayer.framebufferOnly = NO;
        self.metalLayer.contentsGravity = kCAGravityResize;
        self.backgroundColor = [UIColor blackColor];
        self.contentScaleFactor = [UIScreen mainScreen].scale;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat s = [UIScreen mainScreen].scale;
    self.metalLayer.contentsScale = s;
    self.metalLayer.contentsGravity = kCAGravityResize;
    if (self.bounds.size.width > 0 && self.bounds.size.height > 0) {
        self.metalLayer.drawableSize = CGSizeMake(self.bounds.size.width * s, self.bounds.size.height * s);
    }
}

@end

@implementation NfsuTouchOverlay {
    TouchButton _btnLeft;
    TouchButton _btnRight;
    TouchButton _btnGas;
    TouchButton _btnBrake;
    TouchButton _btnHandbrake;
    TouchButton _btnNos;
    TouchButton _btnPause;
    TouchButton _btnEnter;
    TouchButton _btnMap;
    TouchButton _btnSms;
    TouchButton _btnReset;
    TouchButton _btnMoney;
    BOOL _gamepadConnected;
    UIImpactFeedbackGenerator *_hapticFeedback;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.multipleTouchEnabled = YES;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        _hapticFeedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [_hapticFeedback prepare];

        [self updateButtonLayout];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onControllerConnected:)
                                                     name:GCControllerDidConnectNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onControllerDisconnected:)
                                                     name:GCControllerDidDisconnectNotification
                                                   object:nil];
        _gamepadConnected = [GCController controllers].count > 0;
    }
    return self;
}

- (void)onControllerConnected:(NSNotification *)note {
    _gamepadConnected = YES;
    [self setNeedsDisplay];
}

- (void)onControllerDisconnected:(NSNotification *)note {
    _gamepadConnected = [GCController controllers].count > 0;
    [self setNeedsDisplay];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateButtonLayout];
}

- (void)updateButtonLayout {
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    if (w <= 0 || h <= 0) return;

    CGFloat safeLeft = 52.0;

    /* Steering buttons (Left side): Placed above radar minimap so radar is 100% visible */
    CGFloat steerSize = 62.0;
    CGFloat steerY = h - 215.0;
    _btnLeft.rect = CGRectMake(safeLeft - 10.0, steerY, steerSize, steerSize);
    _btnLeft.dik = DIK_LEFT;
    _btnLeft.label = "<";
    _btnLeft.cornerRadius = steerSize * 0.5;

    _btnRight.rect = CGRectMake(safeLeft - 10.0 + steerSize + 12.0, steerY, steerSize, steerSize);
    _btnRight.dik = DIK_RIGHT;
    _btnRight.label = ">";
    _btnRight.cornerRadius = steerSize * 0.5;

    /* Pedals & Action cluster (Right side): Ergonomic curve along outer edge */
    CGFloat gasW = 58.0;
    CGFloat gasH = 115.0;
    CGFloat gasX = w - gasW - 14.0;
    CGFloat gasY = h - gasH - 18.0;
    _btnGas.rect = CGRectMake(gasX, gasY, gasW, gasH);
    _btnGas.dik = DIK_UP;
    _btnGas.label = "GAS";
    _btnGas.cornerRadius = 20.0;

    CGFloat nosW = 58.0;
    CGFloat nosH = 58.0;
    CGFloat nosX = gasX;
    CGFloat nosY = gasY - nosH - 12.0;
    _btnNos.rect = CGRectMake(nosX, nosY, nosW, nosH);
    _btnNos.dik = DIK_LSHIFT;
    _btnNos.label = "NOS";
    _btnNos.cornerRadius = 18.0;

    CGFloat brakeW = 58.0;
    CGFloat brakeH = 72.0;
    CGFloat brakeX = gasX - brakeW - 14.0;
    CGFloat brakeY = h - brakeH - 18.0;
    _btnBrake.rect = CGRectMake(brakeX, brakeY, brakeW, brakeH);
    _btnBrake.dik = DIK_DOWN;
    _btnBrake.label = "BRAKE";
    _btnBrake.cornerRadius = 18.0;

    CGFloat hbW = 58.0;
    CGFloat hbH = 55.0;
    CGFloat hbX = brakeX;
    CGFloat hbY = brakeY - hbH - 12.0;
    _btnHandbrake.rect = CGRectMake(hbX, hbY, hbW, hbH);
    _btnHandbrake.dik = DIK_SPACE;
    _btnHandbrake.label = "HAND\nBRAKE";
    _btnHandbrake.cornerRadius = 18.0;

    /* Top bar: utility shortcuts with notch clearance */
    CGFloat topBtnH = 30.0;
    _btnPause.rect = CGRectMake(safeLeft, 14.0, 46.0, topBtnH);
    _btnPause.dik = DIK_ESCAPE;
    _btnPause.label = "ESC";
    _btnPause.cornerRadius = 8.0;

    _btnEnter.rect = CGRectMake(safeLeft + 52.0, 14.0, 54.0, topBtnH);
    _btnEnter.dik = DIK_RETURN;
    _btnEnter.label = "ENTER";
    _btnEnter.cornerRadius = 8.0;

    _btnMap.rect = CGRectMake(safeLeft + 112.0, 14.0, 46.0, topBtnH);
    _btnMap.dik = DIK_M;
    _btnMap.label = "MAP";
    _btnMap.cornerRadius = 8.0;

    _btnSms.rect = CGRectMake(safeLeft + 164.0, 14.0, 46.0, topBtnH);
    _btnSms.dik = DIK_TAB;
    _btnSms.label = "SMS";
    _btnSms.cornerRadius = 8.0;

    _btnReset.rect = CGRectMake(safeLeft + 216.0, 14.0, 52.0, topBtnH);
    _btnReset.dik = DIK_R;
    _btnReset.label = "RESET";
    _btnReset.cornerRadius = 8.0;

    _btnMoney.rect = CGRectMake(w - 85.0, 14.0, 72.0, topBtnH);
    _btnMoney.dik = 0;
    _btnMoney.label = "$$ MAX";
    _btnMoney.cornerRadius = 8.0;

    [self setNeedsDisplay];
}

- (void)drawButton:(TouchButton *)btn inContext:(CGContextRef)ctx {
    CGRect r = btn->rect;
    CGContextSaveGState(ctx);

    CGFloat cr = btn->cornerRadius > 0 ? btn->cornerRadius : (r.size.height * 0.35);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:cr];

    if (btn->isDown) {
        CGContextSetRGBFillColor(ctx, 1.0, 0.42, 0.05, 0.65);
        CGContextSetRGBStrokeColor(ctx, 1.0, 0.65, 0.2, 1.0);
    } else {
        /* Crystal-clear translucent glass fill so background and HUD stay legible */
        CGContextSetRGBFillColor(ctx, 0.08, 0.12, 0.18, 0.12);
        CGContextSetRGBStrokeColor(ctx, 1.0, 1.0, 1.0, 0.35);
    }
    [path fill];

    CGContextSetLineWidth(ctx, 1.1);
    [path stroke];

    NSString *text = [NSString stringWithUTF8String:btn->label];
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentCenter;

    NSDictionary *attr = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:r.size.height < 45 ? 10 : 12],
        NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:btn->isDown ? 1.0 : 0.85],
        NSParagraphStyleAttributeName: style
    };

    CGSize txtSize = [text sizeWithAttributes:attr];
    CGRect txtRect = CGRectMake(r.origin.x, r.origin.y + (r.size.height - txtSize.height) * 0.5,
                                r.size.width, txtSize.height);
    [text drawInRect:txtRect withAttributes:attr];

    CGContextRestoreGState(ctx);
}

- (void)drawRect:(CGRect)rect {
    if (_gamepadConnected) return;

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    [self drawButton:&_btnLeft inContext:ctx];
    [self drawButton:&_btnRight inContext:ctx];
    [self drawButton:&_btnGas inContext:ctx];
    [self drawButton:&_btnBrake inContext:ctx];
    [self drawButton:&_btnHandbrake inContext:ctx];
    [self drawButton:&_btnNos inContext:ctx];
    [self drawButton:&_btnPause inContext:ctx];
    [self drawButton:&_btnEnter inContext:ctx];
    [self drawButton:&_btnMap inContext:ctx];
    [self drawButton:&_btnSms inContext:ctx];
    [self drawButton:&_btnReset inContext:ctx];
    [self drawButton:&_btnMoney inContext:ctx];

    /* Version watermark below top-left buttons */
    NSString *ver = @"v1.2.6";
    NSDictionary *vAttr = @{
        NSFontAttributeName: [UIFont systemFontOfSize:10 weight:UIFontWeightMedium],
        NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.35]
    };
    [ver drawAtPoint:CGPointMake(52.0, 48.0) withAttributes:vAttr];
}

- (TouchButton *)buttonAtPoint:(CGPoint)pt {
    TouchButton *buttons[] = {
        &_btnLeft, &_btnRight, &_btnGas, &_btnBrake,
        &_btnHandbrake, &_btnNos, &_btnPause, &_btnEnter,
        &_btnMap, &_btnSms, &_btnReset, &_btnMoney
    };
    for (int i = 0; i < 12; i++) {
        if (CGRectContainsPoint(buttons[i]->rect, pt)) {
            return buttons[i];
        }
    }
    return NULL;
}

- (void)pressButton:(TouchButton *)btn touch:(UITouch *)touch {
    if (!btn || btn->isDown) return;
    btn->isDown = YES;
    btn->activeTouch = touch;

    if (_hapticFeedback) {
        [_hapticFeedback impactOccurred];
    }

    if (btn->dik != 0) {
        uint8_t vk = dik_to_vk(btn->dik);
        uint32_t lp = dik_to_lparam(btn->dik, 0);
        kbd_set_key(KSRC_HOST, btn->dik, 1);

        /* NOS fires both Left Shift and Left Alt (DIK_LMENU) */
        if (btn == &_btnNos) {
            kbd_set_key(KSRC_HOST, DIK_LMENU, 1);
        }

        /* SMS fires both Tab and 1 */
        if (btn == &_btnSms) {
            kbd_set_key(KSRC_HOST, DIK_1, 1);
        }

        if (vk) {
            kbd_post(0x0100 /* WM_KEYDOWN */, vk, lp);
            if (vk == 0x0D || vk == 0x1B || vk == 0x09) {
                kbd_post(0x0102 /* WM_CHAR */, vk, lp);
            } else if (btn == &_btnMap) {
                kbd_post(0x0102 /* WM_CHAR */, 'm', lp);
            } else if (btn == &_btnReset) {
                kbd_post(0x0102 /* WM_CHAR */, 'r', lp);
            }
        }
    } else if (btn == &_btnMoney) {
        nfsu2_grant_career_cash(99999999);
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [fb impactOccurred];
    }
    [self setNeedsDisplay];
}

- (void)releaseButton:(TouchButton *)btn {
    if (!btn || !btn->isDown) return;
    btn->isDown = NO;
    btn->activeTouch = nil;

    if (btn->dik != 0) {
        uint8_t vk = dik_to_vk(btn->dik);
        uint32_t lp = dik_to_lparam(btn->dik, 1);
        kbd_set_key(KSRC_HOST, btn->dik, 0);

        if (btn == &_btnNos) {
            kbd_set_key(KSRC_HOST, DIK_LMENU, 0);
        }

        if (btn == &_btnSms) {
            kbd_set_key(KSRC_HOST, DIK_1, 0);
        }

        if (vk) {
            kbd_post(0x0101 /* WM_KEYUP */, vk, lp);
        }
    }
    [self setNeedsDisplay];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *t in touches) {
        CGPoint pt = [t locationInView:self];
        TouchButton *btn = [self buttonAtPoint:pt];
        if (btn) {
            if (!btn->isDown) [self pressButton:btn touch:t];
        } else {
            metal_ios_touch_point(pt.x, pt.y, self.bounds.size.width, self.bounds.size.height, 1, 0);
        }
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *t in touches) {
        CGPoint pt = [t locationInView:self];
        TouchButton *btn = [self buttonAtPoint:pt];

        TouchButton *buttons[] = {
            &_btnLeft, &_btnRight, &_btnGas, &_btnBrake,
            &_btnHandbrake, &_btnNos, &_btnPause, &_btnEnter,
            &_btnMap, &_btnSms, &_btnReset, &_btnMoney
        };
        for (int i = 0; i < 12; i++) {
            if (buttons[i]->activeTouch == t && buttons[i] != btn) {
                [self releaseButton:buttons[i]];
            }
        }
        if (btn) {
            if (!btn->isDown) [self pressButton:btn touch:t];
        } else {
            metal_ios_touch_point(pt.x, pt.y, self.bounds.size.width, self.bounds.size.height, 1, 1);
        }
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *t in touches) {
        CGPoint pt = [t locationInView:self];
        TouchButton *buttons[] = {
            &_btnLeft, &_btnRight, &_btnGas, &_btnBrake,
            &_btnHandbrake, &_btnNos, &_btnPause, &_btnEnter,
            &_btnMap, &_btnSms, &_btnReset, &_btnMoney
        };
        BOOL wasButton = NO;
        for (int i = 0; i < 12; i++) {
            if (buttons[i]->activeTouch == t) {
                [self releaseButton:buttons[i]];
                wasButton = YES;
            }
        }
        if (!wasButton) {
            metal_ios_touch_point(pt.x, pt.y, self.bounds.size.width, self.bounds.size.height, 0, 0);
        }
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

@end

@implementation NfsuViewController {
    CADisplayLink *_displayLink;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    extern void metal_early_init(void);
    metal_early_init();

    self.metalView = [[NfsuMetalView alloc] initWithFrame:self.view.bounds];
    self.metalView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.metalView];

    metal_set_layer(self.metalView.metalLayer);

    self.touchOverlay = [[NfsuTouchOverlay alloc] initWithFrame:self.view.bounds];
    self.touchOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.touchOverlay];

    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onFrameTick:)];
    if (@available(iOS 15.0, *)) {
        _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(60.0, 120.0, 60.0);
    }
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    self.metalView.frame = b;
    self.touchOverlay.frame = b;
}

- (void)onFrameTick:(CADisplayLink *)link {
    metal_render_one_frame();
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures {
    return UIRectEdgeAll;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

@end

@implementation NfsuAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [application setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.viewController = [[NfsuViewController alloc] init];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];

    extern int nfsu2_boot_game(void);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        nfsu2_boot_game();
    });
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    /* Release all keys on background */
    kbd_release_source(KSRC_HOST);
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    /* Resume rendering */
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([NfsuAppDelegate class]));
    }
}