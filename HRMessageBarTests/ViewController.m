//
//  ViewController.m
//  HRMessageBarTests
//
//  Created by Harry Richardson on 03/06/2015.
//  Copyright (c) 2015 Harry Richardson. All rights reserved.
//

#import "ViewController.h"
#import "HRMessageBarView.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Try running simulator in iPhone 4S in Portrait and then rotate to Landscape for this one
    HRMessageBarView *testMessageBarView = [HRMessageBarView messageWithTitle:@"This is the first message bar to appear!"
                                                                         type:HRMessageBarTypeSuccess];
    [testMessageBarView enqueue];
    
    
    
    // Also notice how the title gets truncated here, not the title explanation
    HRMessageBarView *uploadedMessageBarView = [HRMessageBarView messageWithTitle:@"Example operation"
                                                                           detail:@"Tap to resolve"
                                                                             type:HRMessageBarTypeError
                                                                  reuseIdentifier:nil
                                                                         duration:5];
    uploadedMessageBarView.titleExplanation = @"failed to complete";
    uploadedMessageBarView.encloseTitleInQuotes = YES;
    [uploadedMessageBarView enqueue];
}

@end
