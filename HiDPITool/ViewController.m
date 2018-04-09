//
//  ViewController.m
//  HiDPITool
//
//  Created by zll on 2018/4/9.
//  Copyright © 2018年 Godlike Studio. All rights reserved.
//

#import "ViewController.h"
#import "MGTemplateEngine.h"
#import "ICUTemplateMatcher.h"

#define WeakObj(o) try{}@finally{} __weak typeof(o) o##Weak = o;
#define StrongObj(o) autoreleasepool{} __strong typeof(o) o = o##Weak;

#define VENDOR_ID_CMD @"ioreg -l | grep \"DisplayVendorID\""   // 查询显示器VendorID命令

#define PRODUCT_ID_CMD @"ioreg -l | grep \"DisplayProductID\"" // 查询显示器VendorID命令

#define SIP_STATUS_CMD @"csrutil status"                       // 查询SIP状态命令

// System Integrity Protection status: enabled.

@interface ViewController ()
{
    NSString *configTemplatePath; // 模板头文件
}
@property (weak) IBOutlet NSTextField *classNameTF;    // 类名
@property (weak) IBOutlet NSComboBox *superClassCB;    // 父类选择框
@property (weak) IBOutlet NSView *canvasView;          // 画布设置视图
@property (weak) IBOutlet NSTextField *canvasWidthTF;  // 画布宽输入框
@property (weak) IBOutlet NSTextField *canvasHeightTF; // 画布高输入框
@property (weak) IBOutlet NSButton *tex1SelBtn;        // 纹理1选择按钮
@property (weak) IBOutlet NSButton *tex2SelBtn;        // 纹理2选择按钮
@property (weak) IBOutlet NSButton *tex3SelBtn;        // 纹理3选择按钮
@property (weak) IBOutlet NSButton *platformSelBtn;       // 视频选择按钮
@property (weak) IBOutlet NSButton *videoSelBtn;       // 视频选择按钮
@property (weak) IBOutlet NSButton *shaderSelBtn;      // 是否自动产生shader
@property (weak) IBOutlet NSPathControl *tex1PC;       // 纹理1路径显示
@property (weak) IBOutlet NSPathControl *tex2PC;       // 纹理2路径显示
@property (weak) IBOutlet NSPathControl *tex3PC;       // 纹理3路径显示
@property (weak) IBOutlet NSTextField *tex1NameTF;     // 纹理1名称输入框
@property (weak) IBOutlet NSTextField *tex2NameTF;     // 纹理2名称输入框
@property (weak) IBOutlet NSTextField *tex3NameTF;     // 纹理3名称输入框
@property (weak) IBOutlet NSTextField *videoInputTF;   // 纹理3名称输入框
@property (weak) IBOutlet NSPathControl *mp4PC;        // mp4路径
@property (weak) IBOutlet NSTextField *tex1DurationTF; // 纹理1时长输入框
@property (weak) IBOutlet NSTextField *tex2DurationTF; // 纹理2时长输入框
@property (weak) IBOutlet NSTextField *tex3DurationTF; // 纹理3时长输入框
@property (weak) IBOutlet NSTextField *tex1StartTF;
@property (weak) IBOutlet NSTextField *tex2StartTF;
@property (weak) IBOutlet NSTextField *tex3StartTF;
@property (weak) IBOutlet NSTextField *tex1EndTF;
@property (weak) IBOutlet NSTextField *tex2EndTF;
@property (weak) IBOutlet NSTextField *tex3EndTF;
@property (weak) IBOutlet NSView *videoSettingView;

@property (nonatomic, strong) NSPopover *texturePopover;    // 纹理悬浮窗
@property (strong) NSWindow *detachedWindow;                // 附加窗口
@property (strong) NSPanel *detachedHUDWindow;              // 附加显示面板

- (IBAction)generateAction:(id)sender;
- (IBAction)normalizedValueChanged:(id)sender;
- (IBAction)videoChecked:(id)sender;
- (IBAction)selectVideo:(id)sender;
- (IBAction)selectTexture:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

}

- (void)setRepresentedObject:(id)representedObject
{
    [super setRepresentedObject:representedObject];
}

- (NSString *)ToHex:(uint16_t)resolution
{
    NSString *nLetterValue;
    NSString *str =@"";
    uint16_t ttmpig;
    for (int i = 0; i<9; i++) {
        ttmpig=resolution%16;
        resolution=resolution/16;
        switch (ttmpig)
        {
            case 10:
                nLetterValue =@"A";break;
            case 11:
                nLetterValue =@"B";break;
            case 12:
                nLetterValue =@"C";break;
            case 13:
                nLetterValue =@"D";break;
            case 14:
                nLetterValue =@"E";break;
            case 15:
                nLetterValue =@"F";break;
            default:
                nLetterValue = [NSString stringWithFormat:@"%u",ttmpig];
        }
        str = [nLetterValue stringByAppendingString:str];
        if (resolution == 0) {
            break;
        }
    }
    return str;
}

- (void)check:(void (^)(BOOL isValid))callback
{
    if ([_classNameTF.stringValue isEqualToString:@""])
    {
        [self showAlert:@[@"确定", @"取消"] message:@"类名不能为空!" informativeText:@"请填写类名" alertStyle:NSAlertStyleWarning isModal:NO callback:^(NSInteger btnIdx) {
            if (callback) callback(NO);
        }];
        return;
    }
}

- (void)showAlert:(NSArray *)btnTitles
          message:(NSString *)message
  informativeText:(NSString *)informativeText
       alertStyle:(NSAlertStyle)style
          isModal:(BOOL)isModal
         callback:(void (^)(NSInteger btnIdx))callback
{
    NSAlert *alert = [[NSAlert alloc] init];
    for (NSString *title in btnTitles)
    {
        [alert addButtonWithTitle:title];
    }
    [alert setMessageText:message];
    [alert setInformativeText:informativeText];
    [alert setAlertStyle:style];

    if (isModal)
    {
        NSModalResponse response = [alert runModal];
        if (callback) callback(response - 1000);
    }
    else
    {
        [alert beginSheetModalForWindow:[[NSApplication sharedApplication] mainWindow] completionHandler:^(NSModalResponse returnCode) {
            if (callback) callback(returnCode - 1000);
        }];
    }
}

- (IBAction)generateAction:(id)sender {
    MGTemplateEngine *engine = [MGTemplateEngine templateEngine];
    //    [engine setDelegate:self];
    [engine setMatcher:[ICUTemplateMatcher matcherWithTemplateEngine:engine]];

    // Set up any needed global variables.
    // Global variables persist for the life of the engine, even when processing multiple templates.
    configTemplatePath = [[NSBundle mainBundle] pathForResource:@"DisplayProductID-Templater" ofType:nil];

    NSMutableArray *textureAttributes = [NSMutableArray new];
    /*
    if (![_tex1NameTF.stringValue isEqualToString:@""])
    {
        NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:_tex1NameTF.stringValue, @"attr", @"GPUImagePicture", @"type", iosPlatform?[_tex1PC.stringValue lastPathComponent]: _tex1PC.stringValue, @"resource", nil];
        [textureAttributes addObject:dic];
    }
    if (![_tex2NameTF.stringValue isEqualToString:@""])
    {
        NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:_tex2NameTF.stringValue, @"attr", @"GPUImagePicture", @"type",  iosPlatform?[_tex2PC.stringValue lastPathComponent]:_tex2PC.stringValue, @"resource", nil];
        [textureAttributes addObject:dic];
    }
    if (![_tex3NameTF.stringValue isEqualToString:@""])
    {
        NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:_tex3NameTF.stringValue, @"attr", @"GPUImagePicture", @"type", iosPlatform? [_tex3PC.stringValue lastPathComponent]:_tex3PC.stringValue, @"resource", nil];
        [textureAttributes addObject:dic];
    }
    if (![_videoInputTF.stringValue isEqualToString:@""])
    {
        NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:_videoInputTF.stringValue, @"attr", @"GPUImageMovie", @"type", iosPlatform?[_mp4PC.stringValue lastPathComponent]:_mp4PC.stringValue, @"resource", nil];
        [textureAttributes addObject:dic];
    }
     */
    // Set up some variables for this specific template.
    NSDictionary *variables = [NSDictionary dictionaryWithObjectsAndKeys:
                               _classNameTF.stringValue, @"ClassName",
                               _superClassCB.stringValue, @"SuperClassName",
                               textureAttributes, @"TextureAttributes",
                               nil];

    // Process the template and display the results.
    NSString *resultH = [engine processTemplateInFileAtPath:configTemplatePath withVariables:variables];

    //    NSLog(@"Processed template:\r%@", result);
    // DisplayVendorID-XXXX

    NSString *bundle = [[NSBundle mainBundle] resourcePath];
    NSString *vendorID = nil;
    NSString *productID = nil;
    NSString *filtersLocation = [[bundle substringToIndex:[bundle rangeOfString:@"Library"].location] stringByAppendingPathComponent:[NSString stringWithFormat:@"Desktop/DisplayVendorID-%@", vendorID]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:filtersLocation])
    {
        NSError * error = nil;
        BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:filtersLocation
                                                 withIntermediateDirectories:YES
                                                                  attributes:nil
                                                                       error:&error];
        if (!success || error) {
            NSLog(@"[创建文件夹失败]! %@", error);
            return;
        }
    }

    NSString *path = [filtersLocation stringByAppendingPathComponent:[NSString stringWithFormat:@"DisplayProductID-%@", productID]];
    NSError *error;
    BOOL isSuccess = [resultH writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];

    if (isSuccess)
    {
        NSLog(@"success");
    }
    else
    {
        NSLog(@"fail");
        if (error)
        {
            NSLog(@"[文件创建异常]:%@", error);
        }
    }
}

- (void)selectFile:(void (^)(NSInteger, NSString *))callback panel:(NSOpenPanel *)panel result:(NSInteger)result {
    NSString *filePath = nil;
    if (result == NSModalResponseOK)
    {
        filePath = [panel.URLs.firstObject path];
    }
    if (callback) callback(result, filePath);
}

- (void)selectFile:(void (^)(NSInteger response, NSString *filePath))callback isPresent:(BOOL)isPresent
{
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    //是否可以创建文件夹
    panel.canCreateDirectories = YES;
    //是否可以选择文件夹
    panel.canChooseDirectories = YES;
    //是否可以选择文件
    panel.canChooseFiles = NO;

    //是否可以多选
    [panel setAllowsMultipleSelection:NO];

    __weak typeof(self) weakSelf = self;
    if (!isPresent)
    {
        //显示
        [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf selectFile:callback panel:panel result:result];
        }];
    }
    else
    {
        // 悬浮电脑主屏幕上
        [panel beginWithCompletionHandler:^(NSInteger result) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf selectFile:callback panel:panel result:result];
        }];
    }
}

- (void)updatePathControl:(NSPathControl *)pathCtl
                selectBtn:(NSButton *)btn
                 filePath:(NSString *)filePath
{
    btn.hidden = YES;
    pathCtl.hidden = NO;
    pathCtl.URL = [NSURL fileURLWithPath:filePath];
}

- (IBAction)selectVideo:(id)sender
{
    @WeakObj(self);
    [self selectFile:^(NSInteger response, NSString *filePath) {
        @StrongObj(self);
        if (response == NSModalResponseOK)
        {
            [self updatePathControl:self.mp4PC selectBtn:self.videoSelBtn filePath:filePath];
        }
    } isPresent:NO];
}

- (IBAction)selectTexture:(id)sender
{
    @WeakObj(self);
    [self selectFile:^(NSInteger response, NSString *filePath) {
        @StrongObj(self);
        if (response == NSModalResponseOK)
        {
            switch (((NSButton *)sender).tag) {
                case 1:
                {
                    [self updatePathControl:self.tex1PC selectBtn:self.tex1SelBtn filePath:filePath];
                }
                    break;
                case 2:
                {
                    [self updatePathControl:self.tex2PC selectBtn:self.tex2SelBtn filePath:filePath];
                }
                    break;
                case 3:
                {
                    [self updatePathControl:self.tex3PC selectBtn:self.tex3SelBtn filePath:filePath];
                }
                    break;
                default:
                    break;
            }
        }
    } isPresent:NO];
}

@end
