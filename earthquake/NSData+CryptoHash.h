//
//  NSData+CryptoHash.h
//  earthquake
//
//  Created by Sébastien Stormacq on 02/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (CryptoHashing)

- (NSData *)md5Hash;
- (NSString *)md5HexHash;

- (NSData *)sha1Hash;
- (NSString *)sha1HexHash;

- (NSData *)sha256Hash;
- (NSString *)sha256HexHash;

- (NSData *)sha512Hash;
- (NSString *)sha512HexHash;

@end