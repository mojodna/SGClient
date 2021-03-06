//
//  SGBackgroundLocationTests.m
//  SGClient
//
//  Copyright (c) 2009-2010, SimpleGeo
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without 
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, 
//  this list of conditions and the following disclaimer. Redistributions 
//  in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or 
//  other materials provided with the distribution.
//  
//  Neither the name of the SimpleGeo nor the names of its contributors may
//  be used to endorse or promote products derived from this software 
//  without specific prior written permission.
//   
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS 
//  BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
//  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, 
//  EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  Created by Derek Smith.
//

#import "SGLocationServiceTests.h"

#import <time.h>

#if __IPHONE_4_0 && __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_4_0  

@interface SGBackgroundLocationTests : SGLocationServiceTests
{
    @private
    SGRecord* cachedRecord;
}

- (NSArray*) getLocations;
- (void) updateLocationManager;
- (void) validateHistory:(SGRecord*)record;

@end

@implementation SGBackgroundLocationTests

- (void) setUp
{
    [super setUp];
    
    locationService.useGPS = NO;
    locationService.useWiFiTowers = NO;
    locationService.trackRecords = nil;
    
    cachedRecord = nil;
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
    CLLocation* location = nil;
    for(int i = [backgroundLocations count] - 1; i >= 0; i--) {
        location = [backgroundLocations objectAtIndex:i];
        [locationService locationManager:locationService.locationManager
                    didUpdateToLocation:location
                           fromLocation:oldLocation];
        oldLocation = location;
        [SGLocationServiceTests waitForWrite];
        [locationService.operationQueue waitUntilAllOperationsAreFinished];
    }    
}

- (void) testRecordPropertyBackgroundUpdates
{
    SGRecord* r1 = [self createRandomRecord];
    r1.recordId = @"history_record_1";
    
    // Make sure the record has a clean history
    [self.locationService deleteRecordAnnotation:r1];
    [SGLocationServiceTests waitForWrite];
    
    [self.requestIds setObject:[self expectedResponse:YES message:@"Should be able to add record."]
                        forKey:[self.locationService updateRecordAnnotation:r1]];
    locationService.trackRecords = [NSArray arrayWithObject:r1];

    [locationService enterBackground];   
    [self updateLocationManager];
    [SGLocationServiceTests waitForWrite];

    [locationService leaveBackground];
    [locationService becameActive];
 
    [self validateHistory:r1];
}

- (void) testCachedBackgroundUpdates
{
    cachedRecord = [self createRandomRecord];
    cachedRecord.recordId = @"cached_history_record_1";
    
    // Make sure the record has a clean history
    [self.locationService deleteRecordAnnotation:cachedRecord];
    [SGLocationServiceTests waitForWrite];
    
    [self.requestIds setObject:[self expectedResponse:YES message:@"Should be able to add record."]
                        forKey:[self.locationService updateRecordAnnotation:cachedRecord]];

        
    [locationService enterBackground];   
    [self updateLocationManager];
    [locationService leaveBackground];
    [locationService becameActive];
    
    [SGLocationServiceTests waitForWrite];

    [self validateHistory:cachedRecord];
}

- (void) validateHistory:(SGRecord*)record
{
    NSInteger expectedId = [record.recordId intValue];
    [self retrieveRecordResponseId:[self.locationService retrieveRecord:record.recordId layer:record.layer]];    
    [self.locationService.operationQueue waitUntilAllOperationsAreFinished];
    
    NSInteger recordId = [[(NSDictionary*)recentReturnObject recordId] intValue];
    STAssertEquals(recordId, expectedId, @"Expected %i recordId, but was %i", expectedId, recordId);
    
    SGHistoryQuery* historyQuery = [[SGHistoryQuery alloc] initWithRecord:record];
    historyQuery.limit = 100;
    [self.requestIds setObject:[self expectedResponse:YES message:@"Must return an object."] 
                        forKey:[self.locationService history:historyQuery]];
    [self.locationService.operationQueue waitUntilAllOperationsAreFinished];
    
    NSDictionary* geoJSONObject = (NSDictionary*)recentReturnObject;
    STAssertNotNil(geoJSONObject, @"Return object should not be nil.");
    STAssertTrue([geoJSONObject isGeometryCollection], @"The history endpoint should return a collection of geometries.");    
    
    NSArray* backgroundLocations = [self getLocations];
    NSArray* geometries = [geoJSONObject geometries];
    int backgroundLocationCount = [backgroundLocations count];
    STAssertTrue([geometries count] >= backgroundLocationCount , @"There were %i location update but %i were required.", [geometries count], backgroundLocationCount);
    
    // We don't care about the initial lon/lat
    for(int i = 0; i < backgroundLocationCount; i++) {
        NSDictionary* geometry = [geometries objectAtIndex:i];
        NSArray* coordinates = [geometry coordinates];
        CLLocation* location = [backgroundLocations objectAtIndex:i];
        
        double locationLat = location.coordinate.latitude;
        double locationLon = location.coordinate.longitude;
        double historyLat = [[coordinates objectAtIndex:1] doubleValue];
        double historyLon = [[coordinates objectAtIndex:0] doubleValue];
        
        STAssertTrue(locationLat == historyLat, @"Location lat was %f, but history was %f.", locationLat, historyLat);
        STAssertTrue(locationLon == historyLon, @"Locaiton lon was %f, but history was %f.", locationLon, historyLon);
    }
    
    [self deleteRecordResponseId:[self.locationService deleteRecordAnnotation:record]];    
}

- (NSArray*) locationService:(SGLocationService*)service recordsForBackgroundLocationUpdate:(CLLocation*)newLocation
{
    NSArray* records = nil;
    if(cachedRecord) {
        cachedRecord.latitude = newLocation.coordinate.latitude;
        cachedRecord.longitude = newLocation.coordinate.longitude;
        cachedRecord.created = [[NSDate date] timeIntervalSince1970];
        records = [NSArray arrayWithObject:cachedRecord];
    }
    
    return records;
}

- (BOOL) locationService:(SGLocationService*)service shouldCacheRecord:(id<SGRecordAnnotation>)record
{
    return cachedRecord != nil;
}

@end

#endif