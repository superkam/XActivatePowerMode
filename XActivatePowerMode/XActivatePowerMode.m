//
//  XActivatePowerMode.m
//  XActivatePowerMode
//
//  Created by QFish on 12/1/15.
//  Copyright © 2015 QFish. All rights reserved.
//

#import "XActivatePowerMode.h"
#import "Emitter.h"
#import "Rocker.h"

NSString * const kXActivatePowerModeEmitEnabled = @"qfi.sh.xcodeplugin.activatepowermodeemit.enabled";
NSString * const kXActivatePowerModeRollEnabled = @"qfi.sh.xcodeplugin.activatepowermoderoll.enabled";

static XActivatePowerMode * __sharedPlugin = nil;

@interface XActivatePowerMode()

@property (nonatomic, weak, readwrite) NSMenuItem * menuItemEmitter;
@property (nonatomic, weak, readwrite) NSMenuItem * menuItemRoller;

@property (nonatomic, strong, readwrite) NSBundle * bundle;

@property (nonatomic, strong, readwrite) Rocker * rocker;
@property (nonatomic, strong, readwrite) Emitter * emitter;

@end

@implementation XActivatePowerMode

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    __sharedPlugin = [[XActivatePowerMode alloc] initWithBundle:plugin];
}

+ (instancetype)sharedPlugin
{
    return __sharedPlugin;
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init])
    {
        self.bundle = plugin;
        self.emitter = [Emitter new];
        self.rocker = [Rocker new];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didApplicationFinishLaunchingNotification:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
        
    }
    return self;
}

- (void)didApplicationFinishLaunchingNotification:(NSNotification*)noti
{
    //removeObserver
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationDidFinishLaunchingNotification object:nil];
    
    // Create menu items, initialize UI, etc.
    // Sample Menu Item:
    [self setupMenu];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setActivatePowerModeEmitEnabled:[self isEmitModeEnabled]];
        [self setActivatePowerModeRollEnabled:[self isRollModeEnabled]];
    });
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - NSTextView

- (void)textDidChange:(NSNotification *)n
{
    if ( ![[NSApp keyWindow].firstResponder isKindOfClass:NSClassFromString(@"DVTSourceTextView")] )
        return;
    
    if ( [n.object isKindOfClass:NSTextView.class] )
    {
        NSTextView * textView = (NSTextView *)n.object;
        
        NSInteger editingLocation = [[[textView selectedRanges] objectAtIndex:0] rangeValue].location;
        NSUInteger count = 0;
        NSRect targetRect = *[textView.layoutManager rectArrayForCharacterRange:NSMakeRange(editingLocation, 0)
                                                   withinSelectedCharacterRange:NSMakeRange(editingLocation, 0)
                                                                inTextContainer:textView.textContainer
                                                                      rectCount:&count];
        if ([self isEmitModeEnabled]) {
            [self.emitter emitAtPosition:targetRect.origin onView:textView];
        }
        if ([self isRollModeEnabled]) {
            [self.rocker roll:textView];
        }
    }
}

#pragma mark - Methods

- (void)setActivatePowerModeEmitEnabled:(BOOL)enabled
{
    [self updateUserDefaultsWithEmitEnabled:enabled];
    [self updateMenuTitles];
    
    if ( enabled || [self isRollModeEnabled])
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(textDidChange:)
                                                     name:NSTextDidChangeNotification
                                                   object:nil];
    }
    else
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:NSTextDidChangeNotification
                                                      object:nil];
    }
}

- (void)setActivatePowerModeRollEnabled:(BOOL)enabled
{
    [self updateUserDefaultsWithRollEnabled:enabled];
    [self updateMenuTitles];
    
    if ( enabled || [self isEmitModeEnabled])
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(textDidChange:)
                                                     name:NSTextDidChangeNotification
                                                   object:nil];
    }
    else
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:NSTextDidChangeNotification
                                                      object:nil];
    }
}

#pragma mark - UserDefaults

- (BOOL)isEmitModeEnabled
{
    NSNumber * enabled = [[NSUserDefaults standardUserDefaults] objectForKey:kXActivatePowerModeEmitEnabled];
    
    if ( enabled == nil )
    {
        [self updateUserDefaultsWithEmitEnabled:YES];
        return YES;
    }
    
    return [enabled boolValue];
}

- (BOOL)isRollModeEnabled
{
    NSNumber * enabled = [[NSUserDefaults standardUserDefaults] objectForKey:kXActivatePowerModeRollEnabled];
    
    if ( enabled == nil )
    {
        [self updateUserDefaultsWithRollEnabled:YES];
        return YES;
    }
    
    return [enabled boolValue];
}

- (void)updateUserDefaultsWithEmitEnabled:(BOOL)enabled
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kXActivatePowerModeEmitEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)updateUserDefaultsWithRollEnabled:(BOOL)enabled
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kXActivatePowerModeRollEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Menus

- (void)setupMenu
{
    NSMenuItem * mainItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
    
    if ( mainItem )
    {
        [[mainItem submenu] addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem * menuItemEmit = [[NSMenuItem alloc] init];
        menuItemEmit.action = @selector(toggleEmitterEnabled:);
        menuItemEmit.target = self;
        menuItemEmit.title = @"Power Mode - Toggle Emitter";
        [[mainItem submenu] addItem:menuItemEmit];
        
        self.menuItemEmitter = menuItemEmit;
        
        NSMenuItem * menuItemRoll = [[NSMenuItem alloc] init];
        menuItemRoll.action = @selector(toggleRollerEnabled:);
        menuItemRoll.target = self;
        menuItemRoll.title = @"Power Mode - Toggle Roller";
        [[mainItem submenu] addItem:menuItemRoll];
        
        self.menuItemEmitter = menuItemEmit;
        self.menuItemRoller = menuItemRoll;
        
        [self updateMenuTitles];
    }
}

- (void)toggleEmitterEnabled:(id)sender
{
    [self setActivatePowerModeEmitEnabled:![self isEmitModeEnabled]];
}

- (void)toggleRollerEnabled:(id)sender
{
    [self setActivatePowerModeRollEnabled:![self isRollModeEnabled]];
}

- (void)updateMenuTitles
{
    self.menuItemEmitter.state = [self isEmitModeEnabled];
    self.menuItemRoller.state = [self isRollModeEnabled];
}

@end
