//
//  TCWindow.m
//  Fonster
//
//  Created by Joachim Bengtsson on 2013-10-09.
//  Copyright (c) 2013 ThirdCog. All rights reserved.
//

#import "TCWindow.h"

static CGRect gLastFrame;

@interface TCWindow () <UIGestureRecognizerDelegate>
{
    UIToolbar *_toolbar;
    UIView *_background;
    UIButton *_resizeWidget;
    UIButton *_closeWidget;
    CGRect _startFrame;
    CGRect _nonMaximizedFrame;
    UIAttachmentBehavior *_movementSpring;
    UIDynamicItemBehavior *_physics;
}
@end

@implementation TCWindow
- (id)initWithFrame:(CGRect)frame rootViewController:(UIViewController*)rootViewController;
{
    if(!CGRectEqualToRect(gLastFrame, CGRectZero))
        frame = gLastFrame;
    
    if(!(self = [super initWithFrame:frame]))
        return nil;
    
    _rootViewController = rootViewController;
    
    self.backgroundColor = [UIColor clearColor];
    _toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 30)];
    _background = [[UIView alloc] initWithFrame:self.bounds];
    _background.frame = CGRectInset(_background.frame, -2, -2);
    _background.backgroundColor = [[UIColor blueColor] colorWithAlphaComponent:0.05];
    _background.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    _resizeWidget = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
    _resizeWidget.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.1];
    [_resizeWidget addTarget:self action:@selector(maximize:) forControlEvents:UIControlEventTouchUpInside];
    _closeWidget = [UIButton buttonWithType:UIButtonTypeCustom];
    _closeWidget.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.1];
    [_closeWidget addTarget:self action:@selector(close:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_background];
    [self addSubview:_toolbar];
    [self addSubview:_resizeWidget];
    [self addSubview:_closeWidget];
    [self addSubview:_rootViewController.view];
    
    UIPanGestureRecognizer *move = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(move:)];
    move.delegate = self;
    [_toolbar addGestureRecognizer:move];
    
    UIPanGestureRecognizer *resize = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resize:)];
    resize.delegate = self;
    [_resizeWidget addGestureRecognizer:resize];
    
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect toolbarF, contentF;
    CGRectDivide(self.bounds, &toolbarF, &contentF, _toolbar.frame.size.height, CGRectMinYEdge);
    _toolbar.frame = toolbarF;
    self.rootViewController.view.frame = contentF;
    
    CGRect resizeF, _;
    CGRectDivide(toolbarF, &resizeF, &_, _resizeWidget.frame.size.width, CGRectMaxXEdge);
    resizeF.size.height = _resizeWidget.frame.size.height;
    _resizeWidget.frame = resizeF;
    
    CGRect closeF;
    CGRectDivide(toolbarF, &closeF, &_, _resizeWidget.frame.size.width, CGRectMinXEdge);
    _closeWidget.frame = closeF;
}

- (BOOL)canBecomeFirstResponder;
{
    return YES;
}

- (NSArray*)keyCommands
{
    return @[
        [UIKeyCommand keyCommandWithInput:@"w" modifierFlags:UIKeyModifierCommand action:@selector(close:)],
    ];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    return ![self isMaximized];
}

- (void)move:(UIPanGestureRecognizer*)grec
{
    UIDynamicAnimator *animator = [self.delegate animatorForWindow:self];
    
    if(grec.state == UIGestureRecognizerStateBegan) {
        [self.delegate windowRequestsForeground:self];
        CGRect r = _startFrame = self.frame;
        r = CGRectOffset(r, r.size.width/2, r.size.height/2);
        _movementSpring = [[UIAttachmentBehavior alloc] initWithItem:self attachedToAnchor:r.origin];
        _movementSpring.length = 0;
        _movementSpring.damping = 1;
        [animator addBehavior:_movementSpring];
        if(!_physics) {
            _physics = [[UIDynamicItemBehavior alloc] initWithItems:@[self]];
            _physics.resistance = 20;
            [animator addBehavior:_physics];
        }
    } else if(grec.state == UIGestureRecognizerStateChanged) {
        CGRect r = self.frame;
        CGPoint diff = [grec translationInView:self];
        r.origin = (CGPoint){
            _startFrame.origin.x + diff.x,
            _startFrame.origin.y + diff.y
        };
        gLastFrame = r;
        r = CGRectOffset(r, r.size.width/2, r.size.height/2);
        _movementSpring.anchorPoint = r.origin;
        // Physics is buggy; if it's disabled, set position manually.
        if(!animator) {
            self.frame = gLastFrame;
        }
    } else if(grec.state == UIGestureRecognizerStateEnded || grec.state == UIGestureRecognizerStateCancelled) {
        UIPushBehavior *push = [[UIPushBehavior alloc] initWithItems:@[self] mode:UIPushBehaviorModeInstantaneous];
        push.magnitude = 1;
        push.pushDirection = CGVectorMake([grec velocityInView:self].x*0.2, [grec velocityInView:self].y*0.2);
        [animator addBehavior:push];
        [animator removeBehavior:_movementSpring];
        _movementSpring = nil;
    }
}

- (void)resize:(UIPanGestureRecognizer*)grec
{
    if(grec.state == UIGestureRecognizerStateBegan) {
        [self.delegate windowRequestsForeground:self];
        _startFrame = self.frame;
    } else if(grec.state == UIGestureRecognizerStateChanged) {
        CGPoint diff = [grec translationInView:self];
        CGRect r2 = CGRectMake(
            _startFrame.origin.x,
            _startFrame.origin.y + diff.y,
            _startFrame.size.width + diff.x,
            _startFrame.size.height - diff.y
        );
        gLastFrame = self.frame = r2;
    }
}

- (IBAction)close:(id)sender
{
    [[self.delegate animatorForWindow:self] removeBehavior:_physics];
    [self.delegate windowRequestsClose:self];
}

- (BOOL)isMaximized
{
    return self.autoresizingMask == (UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth);
}

- (IBAction)maximize:(id)sender
{
    int fullscreenMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    [[self.delegate animatorForWindow:self] removeBehavior:_physics];
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.65 initialSpringVelocity:20 options:0 animations:^{
        if(self.autoresizingMask != fullscreenMask) {
            _nonMaximizedFrame = self.frame;
            self.frame = self.superview.bounds;
            self.autoresizingMask = fullscreenMask;
        } else {
            self.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleRightMargin;
            self.frame = _nonMaximizedFrame;
        }
    } completion:^(BOOL finished) {
        [[self.delegate animatorForWindow:self] addBehavior:_physics];
    }];
}

@end
