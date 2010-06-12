//
//  SGBackgroundLocationTests.m
//  SGClient
//
//  Created by Derek Smith on 5/24/10.
//  Copyright 2010 SimpleGeo. All rights reserved.
//

#import "SGLocationServiceTests.h"

#import <time.h>

#if __IPHONE_4_0 >= __IPHONE_OS_VERSION_MAX_ALLOWED

@interface SGBackgroundLocationTests : SGLocationServiceTests
{
    
}

- (NSArray*) getLocations;
- (void) updateLocationManager;

@end

@implementation SGBackgroundLocationTests

- (void) setUp
{
    [super setUp];
    
    locatorService.useGPS = NO;
    locatorService.useWiFiTowers = NO;
    locatorService.backgroundRecords = nil;
}

- (NSArray*) getLocations
{
    NSArray* backgroundLocations = [NSArray arrayWithObjects:
                                    [[CLLocation alloc] initWithLatitude:11.0 longitude:20.0],
                                    [[CLLocation alloc] initWithLatitude:11.0 longitude:-20.0],
                                    [[CLLocation alloc] initWithLatitude:-11.0 longitude:-20.0],
                                    [[CLLocation alloc] initWithLatitude:11.0 longitude:-20.0],
                                    nil];
    return backgroundLocations;
}

- (void) updateLocationManager
{
    NSArray* backgroundLocations = [self getLocations];
    CLLocation* oldLocation = nil;
    for(CLLocation* location in backgroundLocations) {
        [locatorService locationManager:locatorService.locationManager
                    didUpdateToLocation:location
                           fromLocation:oldLocation];
        oldLocation = location;
        [locatorService.operationQueue waitUntilAllOperationsAreFinished];
        WAIT_FOR_WRITE();
    }    
}

- (void) testCachedBackgroundUpdates
{
    SGRecord* r1 = [self createRandomRecord];
    r1.recordId = @"history_record_1";
    
    // Make sure the record has a clean history
    [self.locatorService deleteRecordAnnotation:r1];
    WAIT_FOR_WRITE();
    
    [self.requestIds setObject:[self expectedResponse:YES message:@"Should be able to add record."]
                        forKey:[self.locatorService updateRecordAnnotation:r1]];
    locatorService.backgroundRecords = [NSArray arrayWithObject:r1];

    [locatorService enterBackground];   
    [self updateLocationManager];
    [locatorService leaveBackground];
    [locatorService becameActive];
        
    NSInteger expectedId = [r1.recordId intValue];
    [self retrieveRecordResponseId:[self.locatorService retrieveRecord:r1.recordId layer:r1.layer]];    
    [self.locatorService.operationQueue waitUntilAllOperationsAreFinished];
    
    NSInteger recordId = [[(NSDictionary*)recentReturnObject recordId] intValue];
    STAssertEquals(recordId, expectedId, @"Expected %i recordId, but was %i", expectedId, recordId);
    
    [self.requestIds setObject:[self expectedResponse:YES message:@"Must return an object."] forKey:[r1 getHistory:100]];
    [self.locatorService.operationQueue waitUntilAllOperationsAreFinished];
    
    NSDictionary* geoJSONObject = (NSDictionary*)recentReturnObject;
    STAssertNotNil(geoJSONObject, @"Return object should not be nil.");
    STAssertTrue([geoJSONObject isGeometryCollection], @"The history endpoint should return a collection of geometries.");    
    
    NSArray* backgroundLocations = [self getLocations];
    NSArray* geometries = [geoJSONObject geometries];
    int backgroundLocationCount = [backgroundLocations count];
    STAssertTrue([geometries count] == (backgroundLocationCount + 1), @"There were %i background location updates.", [geometries count]);
    
    // We don't care about the initial lon/lat
    for(int i = 0; i < backgroundLocationCount; i++) {
        NSDictionary* geometry = [geometries objectAtIndex:backgroundLocationCount - i - 1];
        NSArray* coordinates = [geometry coordinates];
        CLLocation* location = [backgroundLocations objectAtIndex:i];
        
        double locationLat = location.coordinate.latitude;
        double locationLon = location.coordinate.longitude;
        double historyLat = [[coordinates objectAtIndex:1] doubleValue];
        double historyLon = [[coordinates objectAtIndex:0] doubleValue];
        
        STAssertTrue(locationLat == historyLat, @"Location lat was %f, but history was %f.", locationLat, historyLat);
        STAssertTrue(locationLon == historyLon, @"Locaiton lon was %f, but history was %f.", locationLon, historyLon);
    }
    
    [self deleteRecordResponseId:[self.locatorService deleteRecordAnnotation:r1]];
}

@end

#endif