//
//  SGLocationManager.m
//  SGClient
//
//  Created by Derek Smith on 6/13/10.
//  Copyright 2010 SimpleGeo. All rights reserved.
//

#import "SGLocationManager.h"
#import "SGLocationService.h"

@interface SGLocationManager (Private) <SGLocationManagerDelegate>

- (BOOL) validResponseId:(NSString*)responseId;
- (void) updateRegions:(NSArray*)newRegion;

- (BOOL) isRegion:(NSDictionary*)regionOne equalToRegion:(NSDictionary*)regionTwo;
- (BOOL) isRegion:(NSDictionary*)region foundInSet:(NSArray*)regionSet;

@end

@implementation SGLocationManager
@synthesize regions;

- (id) init
{
    if(self = [super init]) {
        regions = nil;
        conformsToSGDelegate = NO;
        regionResponseId = nil;
    }
    
    return self;
}

- (void) setDelegate:(id<CLLocationManagerDelegate>)newDelegate
{
    conformsToSGDelegate = [newDelegate conformsToProtocol:@protocol(SGLocationManagerDelegate)];
    [super setDelegate:newDelegate];
}

#pragma mark -
#pragma mark CLLocationManager delegate methods 

- (void) locationManager:(CLLocationManager*)manager didUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation
{
    if(conformsToSGDelegate && !regionResponseId) {
        regionResponseId = [[[SGLocationService sharedLocationService] contains:newLocation.coordinate] retain];
    }
}

#pragma mark -
#pragma mark SGLocationService delegate methods 

- (void) locationService:(SGLocationService*)service succeededForResponseId:(NSString*)requestId responseObject:(NSObject*)responseObject
{
    if([self validResponseId:requestId]) {
        
        [self updateRegions:(NSArray*)responseObject];
        
        [regionResponseId release];
        regionResponseId = nil;
    }    
}

- (void) locationService:(SGLocationService*)service failedForResponseId:(NSString*)requestId error:(NSError*)error
{    
    if([self validResponseId:requestId]) {
        
        SGLog(@"SGLocationManager - Unable to retrieve region (%@)", [error description]);
     
        [regionResponseId release];
        regionResponseId = nil;
    }
}

#pragma mark -
#pragma mark Utility methods 

- (BOOL) validResponseId:(NSString*)responseId
{
    return regionResponseId && [regionResponseId isEqualToString:responseId];
}

- (void) updateRegions:(NSArray*)newRegions
{
    if(!regions)
        regions = [newRegions retain];
    else {
        NSMutableArray* addedRegions = [NSMutableArray array];
        NSMutableArray* removedRegions = [NSMutableArray array];

        for(NSDictionary* region in regions)
            if(![self isRegion:region foundInSet:newRegions])
                [removedRegions addObject:region];
        
        for(NSDictionary* region in newRegions)
            if(![self isRegion:region foundInSet:regions])
                [addedRegions addObject:region];
        
        if(conformsToSGDelegate) {
            if([addedRegions count])
                [(id<SGLocationManagerDelegate>)self.delegate locationManager:self didEnterRegions:addedRegions];
            
            if([removedRegions count])
                [(id<SGLocationManagerDelegate>)self.delegate locationManager:self didLeaveRegions:removedRegions];
        }
        
        [regions release];
        regions = [newRegions retain];
    }   
}

- (BOOL) isRegion:(NSDictionary*)region foundInSet:(NSArray*)regionSet
{
    return NO;
}

- (BOOL) isRegion:(NSDictionary*)regionOne equalToRegion:(NSDictionary*)regionTwo
{
    return NO;
}
          
- (void) dealloc
{
    [regionResponseId release];
    [regions release];
    [super dealloc];
}

@end