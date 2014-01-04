//
//  main.m
//  RegExpTest
//
//  Created by Sébastien Stormacq on 04/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        NSError* error;
        NSString* string = @" 15) play-2.2.2-RC1.zip                                              112902441 bytes";
        
        //first number
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\ [0-9]+"
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:&error];
        NSRange rangeOfFirstMatch = [regex rangeOfFirstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
        if (!NSEqualRanges(rangeOfFirstMatch, NSMakeRange(NSNotFound, 0))) {
            NSString *substringForFirstMatch = [[string substringWithRange:rangeOfFirstMatch] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];;
            NSLog(@"A===%@===", substringForFirstMatch);
        }
        

        //file name (assuming file name starts with a letter)
        regex = [NSRegularExpression regularExpressionWithPattern:@"([a-zA-Z].*\\ )(?=[0-9])"
                                                          options:NSRegularExpressionCaseInsensitive
                                                            error:&error];
        rangeOfFirstMatch = [regex rangeOfFirstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
        if (!NSEqualRanges(rangeOfFirstMatch, NSMakeRange(NSNotFound, 0))) {
            NSString *substringForFirstMatch = [[string substringWithRange:rangeOfFirstMatch] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];;
            NSLog(@"B===%@===", substringForFirstMatch);
        }
        
        
        //file size
        regex = [NSRegularExpression regularExpressionWithPattern:@"(\\ [0-9]+)"
                                                          options:NSRegularExpressionCaseInsensitive
                                                            error:&error];
        rangeOfFirstMatch = ((NSTextCheckingResult*)[[regex matchesInString:string options:0 range:NSMakeRange(0, [string length])] objectAtIndex:1]).range;
        if (!NSEqualRanges(rangeOfFirstMatch, NSMakeRange(NSNotFound, 0))) {
            NSString *substringForFirstMatch = [[string substringWithRange:rangeOfFirstMatch] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];;
            NSLog(@"C===%@===", substringForFirstMatch);
        }
        
    }
    return 0;
}

