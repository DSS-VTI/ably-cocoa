//
//  ARTChannelOptions.h
//  ably
//
//  Created by Ricardo Pereira on 01/10/2015.
//  Copyright (c) 2015 Ably. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ARTTypes.h"

@class ARTCipherParams;

ART_ASSUME_NONNULL_BEGIN

@interface ARTChannelOptions : NSObject

@property (nonatomic, assign) BOOL isEncrypted;
@property (nonatomic, strong, art_nullable) ARTCipherParams *cipherParams;

+ (instancetype)unencrypted;

- (instancetype)initEncrypted:(ARTCipherParams *)cipherParams;

@end

ART_ASSUME_NONNULL_END