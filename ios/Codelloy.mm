#import <React/RCTEventEmitter.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import <CodelloyReactNativeSpec/CodelloyReactNativeSpec.h>
#endif

// The path of the generated Swift header differs for static libraries and for frameworks.
#if __has_include(<CodelloyReactNative/CodelloyReactNative-Swift.h>)
#import <CodelloyReactNative/CodelloyReactNative-Swift.h>
#else
#import "CodelloyReactNative-Swift.h"
#endif

static NSString *const kLinkEvent = @"CodelloyLink";

// The module of the JavaScript layer on both architectures. Each method sends the call to CodelloyImpl.swift.
// The class is not Codelloy, because the native SDK has an Objective-C class with that name.
@interface RNCodelloy : RCTEventEmitter
@end

#ifdef RCT_NEW_ARCH_ENABLED
@interface RNCodelloy () <NativeCodelloySpec>
@end
#endif

@implementation RNCodelloy {
  CodelloyImpl *_impl;
}

RCT_EXPORT_MODULE()

- (instancetype)init {
  if (self = [super init]) {
    __weak RNCodelloy *weakSelf = self;
    _impl = [[CodelloyImpl alloc] initWithEmit:^(NSDictionary<NSString *, id> *link) {
      [weakSelf sendEventWithName:kLinkEvent body:link];
    }];
  }
  return self;
}

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

- (NSArray<NSString *> *)supportedEvents {
  return @[ kLinkEvent ];
}

- (void)startObserving {
  [_impl startObserving];
}

- (void)stopObserving {
  [_impl stopObserving];
}

// clang-format reads the export macros as C calls and breaks the Objective-C selectors.
// clang-format off
RCT_EXPORT_METHOD(configure:(NSString *)key
                  clipboard:(BOOL)clipboard
                  signalMatching:(BOOL)signalMatching
                  autoMatch:(BOOL)autoMatch
                  minConfidence:(NSString *)minConfidence
                  debug:(BOOL)debug
                  baseUrl:(NSString *)baseUrl
                  wrapper:(NSString *)wrapper)
{
  [_impl configureWithKey:key
                clipboard:clipboard
           signalMatching:signalMatching
                autoMatch:autoMatch
            minConfidence:minConfidence
                    debug:debug
                  baseUrl:baseUrl
                  wrapper:wrapper];
}

RCT_EXPORT_METHOD(match:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
  [_impl matchWithResolve:resolve
                   reject:^(NSString *code, NSString *message) {
                     reject(code, message, nil);
                   }];
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSDictionary *, getPendingLink)
{
  return [_impl pendingLink];
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSNumber *, handleLink:(NSString *)url)
{
  return @([_impl handleLink:url]);
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSString *, installId)
{
  return _impl.installId;
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSNumber *, resetForTesting)
{
  return @([_impl resetForTesting]);
}
// clang-format on

#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeCodelloySpecJSI>(params);
}
#endif

@end
