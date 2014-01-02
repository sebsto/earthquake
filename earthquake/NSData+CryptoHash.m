//
//  NSData+CryptoHash.m
//  earthquake
//
//  Created by Sébastien Stormacq on 02/01/14.
//  Copyright (c) 2014 Sebastien Stormacq. All rights reserved.
//

#import "NSData+CryptoHash.h"

#if TARGET_OS_MAC && (TARGET_OS_IPHONE || MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4)

#define COMMON_DIGEST_FOR_OPENSSL
#import <CommonCrypto/CommonDigest.h>

#define MD5(data, len, md)      CC_MD5(data, len, md)
#define SHA1(data, len, md)     CC_SHA1(data, len, md)
#define SHA256(data, len, md)   CC_SHA256(data, len, md)
#define SHA512(data, len, md)   CC_SHA512(data, len, md)

#else

#import <openssl/md5.h>
#import <openssl/sha.h>

#endif

@implementation NSData (CryptoHashing)

- (NSData *)md5Hash
{
    unsigned char digest[MD5_DIGEST_LENGTH];
    
    MD5((const void*)[self bytes], (CC_LONG)[self length], digest);
    
    return [NSData dataWithBytes:&digest length:MD5_DIGEST_LENGTH];
}

- (NSString *)md5HexHash
{
    unsigned char digest[MD5_DIGEST_LENGTH];
    char finaldigest[2 * MD5_DIGEST_LENGTH];
    int i;
    
    MD5((const void*)[self bytes], (CC_LONG)[self length], digest);
    
    for (i = 0; i < MD5_DIGEST_LENGTH; i++)
    {
        sprintf(finaldigest + i * 2, "%02x", digest[i]);
    }
    
    return [NSString stringWithCString:finaldigest encoding:NSUTF8StringEncoding];
}

- (NSData *)sha1Hash
{
    unsigned char digest[SHA_DIGEST_LENGTH];
    
    SHA1((const void*)[self bytes], (CC_LONG)[self length], digest);
    
    return [NSData dataWithBytes:&digest length:SHA_DIGEST_LENGTH];
}

- (NSString *)sha1HexHash
{
    unsigned char digest[SHA_DIGEST_LENGTH];
    char finaldigest[2 * SHA_DIGEST_LENGTH];
    int i;
    
    SHA1([self bytes], (CC_LONG)[self length], digest);
    
    for (i = 0; i < SHA_DIGEST_LENGTH; i++)
    {
        sprintf(finaldigest + i * 2, "%02x", digest[i]);
    }
    
    return [NSString stringWithCString:finaldigest encoding:NSUTF8StringEncoding];
}

- (NSData *)sha256Hash
{
    unsigned char digest[SHA256_DIGEST_LENGTH];
    
    SHA256([self bytes], (CC_LONG)[self length], digest);
    
    return [NSData dataWithBytes:&digest length:SHA256_DIGEST_LENGTH];
}

- (NSString *)sha256HexHash
{
    unsigned char digest[SHA256_DIGEST_LENGTH];
    char finaldigest[2 * SHA256_DIGEST_LENGTH];
    int i;
    
    SHA256([self bytes], (CC_LONG)[self length], digest);
    
    for (i = 0; i < SHA256_DIGEST_LENGTH; i++)
    {
        sprintf(finaldigest + i * 2, "%02x", digest[i]);
    }
    
    return [NSString stringWithCString:finaldigest encoding:NSUTF8StringEncoding];
}

- (NSData *)sha512Hash
{
    unsigned char digest[SHA512_DIGEST_LENGTH];
    
    SHA512([self bytes], (CC_LONG)[self length], digest);
    
    return [NSData dataWithBytes:&digest length:SHA512_DIGEST_LENGTH];
}

- (NSString *)sha512HexHash
{
    unsigned char digest[SHA512_DIGEST_LENGTH];
    char finaldigest[2 * SHA512_DIGEST_LENGTH];
    int i;
    
    SHA512([self bytes], (CC_LONG)[self length], digest);
    
    for (i = 0; i < SHA512_DIGEST_LENGTH; i++)
    {
        sprintf(finaldigest + i * 2, "%02x", digest[i]);
    }
    
    return [NSString stringWithCString:finaldigest encoding:NSUTF8StringEncoding];
}

@end
