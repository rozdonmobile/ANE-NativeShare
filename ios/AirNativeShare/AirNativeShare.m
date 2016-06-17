//////////////////////////////////////////////////////////////////////////////////////
//
//  Copyright 2012 Freshplanet (http://freshplanet.com | opensource@freshplanet.com)
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//////////////////////////////////////////////////////////////////////////////////////

#import "AirNativeShare.h"
#import "CustomText.h"
#import "CustomLink.h"
#import "CustomPinterestActivity.h"
#import "CustomInstagramActivity.h"
#import "CustomImage.h"

FREContext myAirNativeShareCtx = nil;

@implementation AirNativeShare

@synthesize documentController;

+ (id)sharedInstance {
    
    static id sharedInstance = nil;
    if (sharedInstance == nil) {
        sharedInstance = [[self alloc] init];
    }
    
    return sharedInstance;
}

@end

#pragma mark - C interface

DEFINE_ANE_FUNCTION(AirNativeShareShowShare) {
    
    // setup
    
    NSMutableArray *activityItems = [[NSMutableArray alloc] init];
    
    CustomLink* link = nil;
    UIImage*    image = nil;
    NSString*   imagePath = nil;
    
    // text
    
    CustomText* caption = [[CustomText alloc] initWithFREObject:argv[0]];
    
    if (argc > 0) {
        
        // url
        
        FREObject       propertyValue;
        FREObject       exception;
        uint32_t        string1Length;
        const uint8_t*  string1;
        
        if (FREGetObjectProperty(argv[0], (const uint8_t*)"hasDefaultLink", &propertyValue, &exception) == FRE_OK) {
            
            NSLog(@"checking link");
            
            if (FPANE_FREObjectToBool(propertyValue)) {
                
                if (FREGetObjectProperty(argv[0], (const uint8_t*)"defaultLink", &propertyValue, &exception) == FRE_OK) {
                    
                    FREGetObjectAsUTF8(propertyValue, &string1Length, &string1);
                    link = [[CustomLink alloc] initWithFREObject:argv[0] andURLPath:[NSString stringWithUTF8String:(char*)string1]];
                }
            }
            
            NSLog(@"link: %@", link);
        }
        
        // image
        
        if (argc > 1) {
            
            NSLog(@"found bitmapData");
            
            FREBitmapData bitmapData;
            
            if (FREAcquireBitmapData(argv[1], &bitmapData) == FRE_OK) {
                
                // make data provider from buffer
                CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, bitmapData.bits32, (bitmapData.width * bitmapData.height * 4), NULL);
                
                // set up for CGImage creation
                int             bitsPerComponent    = 8;
                int             bitsPerPixel        = 32;
                int             bytesPerRow         = 4 * bitmapData.width;
                CGColorSpaceRef colorSpaceRef       = CGColorSpaceCreateDeviceRGB();
                CGBitmapInfo    bitmapInfo;
                
                if (!bitmapData.hasAlpha)
                    bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;
                else {
                    
                    if (bitmapData.isPremultiplied)
                        bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst;
                    else
                        bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaFirst;
                }
                
                CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
                CGImageRef imageRef = CGImageCreate(bitmapData.width, bitmapData.height, bitsPerComponent,
                                                    bitsPerPixel, bytesPerRow, colorSpaceRef,
                                                    bitmapInfo, provider, NULL, YES, renderingIntent);
                
                // make UIImage from CGImage
                image = [UIImage imageWithCGImage:imageRef];
                
                FREReleaseBitmapData(argv[1]);
                
                NSData* imageData = UIImagePNGRepresentation(image);
                imagePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"/insta.igo"];
                [imageData writeToFile:imagePath atomically:YES];
                
                if (argc < 4)
                    image = [UIImage imageWithContentsOfFile:imagePath];
                else {
                    
                    NSString* imageUrl = FPANE_FREObjectToNSString(argv[2]);
                    NSString* sourceUrl = FPANE_FREObjectToNSString(argv[3]);
                    
                    NSLog(@"image url %@", imageUrl);
                    
                    CustomImage* myImage = [[CustomImage alloc] initWithContentsOfFile:imagePath];
                    myImage.imageUrl = imageUrl;
                    myImage.sourceUrl = sourceUrl;
                    
                    image = myImage;
                }
            }
        }
    }
    
    if (caption) {
        
        [activityItems addObject:caption];
        NSLog(@"caption added");
    }
    
    if (link) {
        
        [activityItems addObject:link];
        NSLog(@"link added");
    }
    
    if (image) {
        
        [activityItems addObject:image];
        NSLog(@"image added");
    }

    // share
    
    CustomPinterestActivity* pinActivity = [[CustomPinterestActivity alloc] init];
    CustomInstagramActivity* instagramActivity = [[CustomInstagramActivity alloc] init];
    
    UIViewController* rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];

    UIActivityViewController* activityController = [[UIActivityViewController alloc] initWithActivityItems:activityItems
                                                                                     applicationActivities:@[instagramActivity, pinActivity]];
    
    // share callback
    
    [activityController setCompletionHandler:^(NSString *activityType, BOOL completed) {
    
        if (completed) {
            
            // IG
            
            if ([activityType isEqualToString:FPInstagramActivityType]) {
                
                UIDocumentInteractionController * documentController;
                documentController = [UIDocumentInteractionController interactionControllerWithURL: [NSURL fileURLWithPath:imagePath]];
                
                ((AirNativeShare*)[AirNativeShare sharedInstance]).documentController = documentController;
                
                // setting specific param
                documentController.UTI = @"com.instagram.exclusivegram";
                if (caption != nil)
                    documentController.annotation = [NSDictionary dictionaryWithObject:caption.twitterText forKey:@"InstagramCaption"];
                
                // Present the tweet composition view controller modally.
                id delegate = [[UIApplication sharedApplication] delegate];
                
                documentController.delegate = delegate;
                
                UIView *rootView = [[[[UIApplication sharedApplication] keyWindow] rootViewController] view];
                
                [documentController presentOpenInMenuFromRect:CGRectMake(0, 0, 100, 100) inView:rootView animated:YES];
            }
            
            NSString* shareType = @"Unknown";
            
            if (activityType == UIActivityTypeMessage)
                shareType = @"SMS";
            else if (activityType == UIActivityTypeMail)
                shareType = @"Mail";
            else if (activityType == UIActivityTypePostToFacebook)
                shareType = @"Facebook";
            else if (activityType == UIActivityTypePostToFlickr)
                shareType = @"Flickr";
            else if (activityType == UIActivityTypePostToVimeo)
                shareType = @"Vimeo";
            else if (activityType == UIActivityTypePostToTencentWeibo)
                shareType = @"TencentWeibo";
            else if (activityType == UIActivityTypePostToWeibo)
                shareType = @"Weibo";
            else if (activityType == UIActivityTypePostToTwitter)
                shareType = @"Twitter";
            else if ([activityType isEqualToString:FPInstagramActivityType])
                shareType = @"Instagram";
            else if ([activityType isEqualToString:FPPinterestActivityType])
                shareType = @"Pinterest";
            
            FPANE_DispatchEventWithInfo(myAirNativeShareCtx, @"NATIVE_SHARE_SUCCESS", shareType);
        } else
        {
            FPANE_DispatchEvent(myAirNativeShareCtx, @"NATIVE_SHARE_CANCELLED");
        }
    }];
    
    // present
    
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad)
        [rootViewController presentViewController:activityController animated:YES completion:nil];
    else {
        
        UIPopoverController *popup = [[UIPopoverController alloc] initWithContentViewController:activityController];
        UIView *view = rootViewController.view;
        
        [popup presentPopoverFromRect:CGRectMake(view.frame.size.width/2 - 50, view.frame.size.height/2 - 50, 100, 100)
                               inView:view
             permittedArrowDirections:0
                             animated:YES];
    }

    return nil;
}


DEFINE_ANE_FUNCTION(AirNativeShareInitPinterest)
{
    NSString * pinterestClientId = FPANE_FREObjectToNSString(argv[0]);
    NSString * pinterestSuffix = nil;
    if (argc > 1)
    {
        pinterestSuffix = FPANE_FREObjectToNSString(argv[1]);
    }
    
    [CustomPinterestActivity initWithClientId:pinterestClientId suffix:pinterestSuffix];

    return nil;
}

DEFINE_ANE_FUNCTION(AirNativeShareIsSupported)
{
    NSLog(@"check if supported");
    BOOL isSupported = NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1;
    NSLog(@"is supported");
    return FPANE_BOOLToFREObject(isSupported);
}


#pragma mark - ANE setup

void AirNativeShareContextInitializer(void* extData, const uint8_t* ctxType, FREContext ctx, uint32_t* numFunctionsToTest, const FRENamedFunction** functionsToSet)
{
    // Register the links btwn AS3 and ObjC. (dont forget to modify the nbFuntionsToLink integer if you are adding/removing functions)
    NSInteger nbFuntionsToLink = 3;
    *numFunctionsToTest = nbFuntionsToLink;
    
    FRENamedFunction* func = (FRENamedFunction*) malloc(sizeof(FRENamedFunction) * nbFuntionsToLink);
    
    func[0].name = (const uint8_t*) "AirNativeShareShowShare";
    func[0].functionData = NULL;
    func[0].function = &AirNativeShareShowShare;
    
    func[1].name = (const uint8_t*) "AirNativeShareInitPinterest";
    func[1].functionData = NULL;
    func[1].function = &AirNativeShareInitPinterest;

    func[2].name = (const uint8_t*) "AirNativeShareIsSupported";
    func[2].functionData = NULL;
    func[2].function = &AirNativeShareIsSupported;

    *functionsToSet = func;
    
    myAirNativeShareCtx = ctx;

}

void AirNativeShareContextFinalizer(FREContext ctx) { }

void AirNativeShareInitializer(void** extDataToSet, FREContextInitializer* ctxInitializerToSet, FREContextFinalizer* ctxFinalizerToSet)
{
	*extDataToSet = NULL;
	*ctxInitializerToSet = &AirNativeShareContextInitializer;
	*ctxFinalizerToSet = &AirNativeShareContextFinalizer;
}

void AirNativeShareFinalizer(void* extData) { }