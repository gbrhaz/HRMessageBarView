# HRMessageBarView

A quick and easy-to-use framework for showing success and failure notifications..

iOS 7+ is supported on iPhone and iPad.

## Usage

``` objective-c
HRMessageBarView *message = [HRMessageBarView messageWithTitle:@"This is the first message bar to appear!"
                                                    	  type:HRMessageBarTypeSuccess];
[testMessageBarView enqueue];
```