#import "ios_view.h"
#import <GameController/GameController.h>
#include "kbd.h"
#include <pthread.h>

#define DIK_ESCAPE          0x01
#define DIK_RETURN          0x1C
#define DIK_LSHIFT          0x2A
#define DIK_SPACE           0x39
#define DIK_UP              0xC8
#define DIK_LEFT            0xCB
#define DIK_RIGHT           0xCD
#define DIK_DOWN            0xD0

typedef struct {
    CGRect rect;
    unsigned dik;
    const char *label;
    BOOL isDown;
    UITouch *activeTouch;
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
        self.metalLayer.contentsGravity = kCAGravityResizeAspect;
        self.backgroundColor = [UIColor blackColor];
        self.contentScaleFactor = [UIScreen mainScreen].scale;
    }
    return self;
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
    TouchButton _btnMoney;
    BOOL _gamepadConnected;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.multipleTouchEnabled = YES;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
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

    CGFloat safeBottom = 20.0;
    CGFloat safeSide = 25.0;

    CGFloat steerW = 75.0, steerH = 75.0;
    CGFloat steerY = h - steerH - safeBottom - 20.0;
    _btnLeft.rect = CGRectMake(safeSide, steerY, steerW, steerH);
    _btnLeft.dik = DIK_LEFT;
    _btnLeft.label = "<";

    _btnRight.rect = CGRectMake(safeSide + steerW + 16.0, steerY, steerW, steerH);
    _btnRight.dik = DIK_RIGHT;
    _btnRight.label = ">";

    CGFloat pedalW = 80.0, pedalH = 85.0;
    CGFloat gasX = w - safeSide - pedalW;
    CGFloat gasY = h - pedalH - safeBottom - 30.0;
    _btnGas.rect = CGRectMake(gasX, gasY, pedalW, pedalH);
    _btnGas.dik = DIK_UP;
    _btnGas.label = "GAS";

    CGFloat brakeX = gasX - pedalW - 20.0;
    CGFloat brakeY = gasY + 10.0;
    _btnBrake.rect = CGRectMake(brakeX, brakeY, pedalW, pedalH - 10.0);
    _btnBrake.dik = DIK_DOWN;
    _btnBrake.label = "BRAKE";

    CGFloat nosW = 65.0, nosH = 65.0;
    _btnNos.rect = CGRectMake(gasX - 15.0, gasY - nosH - 20.0, nosW, nosH);
    _btnNos.dik = DIK_LSHIFT;
    _btnNos.label = "NOS";

    CGFloat hbW = 65.0, hbH = 65.0;
    _btnHandbrake.rect = CGRectMake(brakeX - 15.0, gasY - hbH - 20.0, hbW, hbH);
    _btnHandbrake.dik = DIK_SPACE;
    _btnHandbrake.label = "HAND\nBRAKE";

    CGFloat topBtnW = 60.0, topBtnH = 34.0;
    _btnPause.rect = CGRectMake(safeSide, 15.0, topBtnW, topBtnH);
    _btnPause.dik = DIK_ESCAPE;
    _btnPause.label = "ESC";

    _btnEnter.rect = CGRectMake(safeSide + topBtnW + 12.0, 15.0, topBtnW, topBtnH);
    _btnEnter.dik = DIK_RETURN;
    _btnEnter.label = "ENTER";

    _btnMoney.rect = CGRectMake(w - safeSide - topBtnW - 10.0, 15.0, topBtnW + 10.0, topBtnH);
    _btnMoney.dik = 0;
    _btnMoney.label = "$$ MAX";

    [self setNeedsDisplay];
}

- (void)drawButton:(TouchButton *)btn inContext:(CGContextRef)ctx {
    CGRect r = btn->rect;
    CGContextSaveGState(ctx);

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:r.size.height * 0.35];
    if (btn->isDown) {
        CGContextSetRGBFillColor(ctx, 0.9, 0.5, 0.1, 0.65);
    } else {
        CGContextSetRGBFillColor(ctx, 0.1, 0.1, 0.15, 0.35);
    }
    [path fill];

    CGContextSetRGBStrokeColor(ctx, 1.0, 0.6, 0.2, btn->isDown ? 0.9 : 0.5);
    CGContextSetLineWidth(ctx, 1.5);
    [path stroke];

    NSString *text = [NSString stringWithUTF8String:btn->label];
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentCenter;

    NSDictionary *attr = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:r.size.height < 50 ? 12 : 15],
        NSForegroundColorAttributeName: [UIColor whiteColor],
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
    [self drawButton:&_btnMoney inContext:ctx];
}

- (TouchButton *)buttonAtPoint:(CGPoint)pt {
    TouchButton *buttons[] = {
        &_btnLeft, &_btnRight, &_btnGas, &_btnBrake,
        &_btnHandbrake, &_btnNos, &_btnPause, &_btnEnter, &_btnMoney
    };
    for (int i = 0; i < 9; i++) {
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

    if (btn->dik != 0) {
        kbd_set_key(KSRC_HOST, btn->dik, 1);
        kbd_post(0x0100 /* WM_KEYDOWN */, 0, 0);
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
        kbd_set_key(KSRC_HOST, btn->dik, 0);
        kbd_post(0x0101 /* WM_KEYUP */, 0, 0);
    }
    [self setNeedsDisplay];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *t in touches) {
        CGPoint pt = [t locationInView:self];
        TouchButton *btn = [self buttonAtPoint:pt];
        if (btn && !btn->isDown) {
            [self pressButton:btn touch:t];
        }
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *t in touches) {
        CGPoint pt = [t locationInView:self];
        TouchButton *btn = [self buttonAtPoint:pt];

        TouchButton *buttons[] = {
            &_btnLeft, &_btnRight, &_btnGas, &_btnBrake,
            &_btnHandbrake, &_btnNos, &_btnPause, &_btnEnter, &_btnMoney
        };
        for (int i = 0; i < 9; i++) {
            if (buttons[i]->activeTouch == t && buttons[i] != btn) {
                [self releaseButton:buttons[i]];
            }
        }
        if (btn && !btn->isDown) {
            [self pressButton:btn touch:t];
        }
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *t in touches) {
        TouchButton *buttons[] = {
            &_btnLeft, &_btnRight, &_btnGas, &_btnBrake,
            &_btnHandbrake, &_btnNos, &_btnPause, &_btnEnter, &_btnMoney
        };
        for (int i = 0; i < 9; i++) {
            if (buttons[i]->activeTouch == t) {
                [self releaseButton:buttons[i]];
            }
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

- (void)onFrameTick:(CADisplayLink *)link {
    metal_render_one_frame();
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

@end

@implementation NfsuAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
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
