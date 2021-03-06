//
//  MeshDataSync.m
//  commotion-meshbook
//
//  Created by Brad : Scal.io, LLC - http://scal.io
//

#import "MeshDataSync.h"

@implementation MeshDataSync

@synthesize downloadURL, downloadData, downloadPath;
@synthesize downloadDone, executing, finished;

//==========================================================
#pragma mark Initialization & Run Loop
//==========================================================
-(id) init {
    //NSLog(@"MeshDataSync: init");
    
	if (![super init]) return nil;
    
    NSString *downloadString = @"http://localhost:9090";
    //NSString *downloadString = @"http://google.com";
    
    // Construct the URL to be downloaded
	downloadURL = [[NSURL alloc] initWithString: downloadString];
	downloadData = [[NSMutableData alloc] init];
    
    //NSLog(@"downloadURL: %@",downloadURL);
    
    // Create the download path
    downloadPath = [[[NSString alloc] initWithFormat:@"Meshbook/%@.json", @"olsrd-all"]stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
	
	//NSLog(@"downloadPath: %@",downloadPath);
    
    return self;
}

-(void) main {
    //NSLog(@"MeshDataSync: main");
    
    if (![self isCancelled]) {
        
        [self willChangeValueForKey:@"isExecuting"];
        executing = YES;
        
        // Create the request.
        NSURLRequest *downloadRequest=[NSURLRequest requestWithURL: downloadURL];

        //NSURLRequest *downloadRequest=[NSURLRequest requestWithURL: downloadURL cachePolicy: NSURLRequestUseProtocolCachePolicy timeoutInterval: 10.0];
        
        //NSLog(@"%s: downloadRequest: %@", __FUNCTION__, downloadURL);
        NSURLConnection *downloadConnection = [[NSURLConnection alloc] initWithRequest:downloadRequest delegate:self];
        
        // IMPORTANT! The next line is what keeps the NSOperation alive for the duration of the NSURLConnection!
        [downloadConnection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [downloadConnection start];
        
        // Continue the download until operation is cancelled, finished or errors out
        if (downloadConnection) {
            //NSLog(@"connection established!");
            do {
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
            } while (!downloadDone);
            [self terminateOperation];
        } else {
            NSLog(@"couldn't establish connection for: %@", downloadURL);
            
            // Cleanup Operation so next one (if any) can run
            [self terminateOperation];
        }
    }
    else { // Operation has been cancelled, clean up
        [self terminateOperation];
    }
}


//==========================================================
#pragma mark Mesh Data Processing
//==========================================================
- (void) processMeshData:(NSMutableData *)responseData {
    
    //NSLog(@"processMeshData-processing response NSMutableData");
    
    // convert to JSON
    NSError *myError = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableLeaves error:&myError];
    
    // show all values
    for(id key in json) {
        
        //id value = [json objectForKey:key];
        
        //NSString *keyAsString = (NSString *)key;
        //NSString *valueAsString = (NSString *)value;
        
        //NSLog(@"key: %@", keyAsString);
        //NSLog(@"value: %@", valueAsString);
    }
    
    // extract specific value...
    NSArray *results = [json objectForKey:@"interfaces"];
    
    NSMutableDictionary *meshData;
    
    for (NSDictionary *result in results) {
        NSString *state = ([[result objectForKey:@"state"] isEqualToString:@"up"] ? @"Running" : @"Stopped");
        
        meshData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                    state, @"state",
                    nil];
        NSLog(@"state: %@", state);
    }
    
    // send notification to all listening classes that data is ready -- as a json dict
    [[NSNotificationCenter defaultCenter] postNotificationName:@"meshDataProcessingComplete" object:nil userInfo:meshData];
    
}


//==========================================================
#pragma mark NSURLConnection Delegates
//==========================================================

// NSURLConnectionDelegate method: handle the initial connection
-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse*)response {
    //NSLog(@"%s: didReceiveResponse", __FUNCTION__);
    [downloadData setLength:0];
}

// NSURLConnectionDelegate method: handle data being received during connection
-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [downloadData appendData:data];
    //NSLog(@"downloaded %lu bytes", [data length]);
}

// NSURLConnectionDelegate method: What to do once request is completed
-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
    //NSLog(@"%s: Download finished! File: %@", __FUNCTION__, downloadURL);
    /**
    //NSLog(@"%s: Download finished! File: %@", __FUNCTION__, downloadURL);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = [paths objectAtIndex:0];
    NSString *filePath = [downloadPath stringByReplacingOccurrencesOfString:@"http://" withString:@""];
    //NSString *filePath = @"Meshbook";
    
    NSString *targetPath = [docDir stringByAppendingPathComponent:filePath];
    BOOL isDir;
    
    // If target folder path doesn't exist, create it
    if (![fileManager fileExistsAtPath:[targetPath stringByDeletingLastPathComponent] isDirectory:&isDir]) {
        NSError *makeDirError = nil;
        [fileManager createDirectoryAtPath:[targetPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&makeDirError];
        if (makeDirError != nil) {
            NSLog(@"MAKE DIR ERROR: %@", [makeDirError description]);
            [self terminateOperation];
        }
    }
    
    NSError *saveError = nil;
    // Write the downloaded website homepage to the root Documents folder of the app
    [downloadData writeToFile:targetPath options:NSDataWritingAtomic error:&saveError];
    if (saveError != nil) {
        NSLog(@"Download save failed! Error: %@", [saveError description]);
        [self terminateOperation];
    }
    else {
        NSLog(@"file has been saved!: %@", targetPath);
    }
    downloadDone = true;
    **/
    
    [self processMeshData: downloadData];
}

// NSURLConnectionDelegate method: Handle the connection failing
-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"%s: didFailWithErrorError: %@ \n %@", __FUNCTION__, [error localizedDescription], [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);

    // send a nil dict to indicate the process failed
    [[NSNotificationCenter defaultCenter] postNotificationName:@"meshDataProcessingComplete" object:nil userInfo:nil];
    
    [self terminateOperation];
}

// Function to clean up the variables and mark Operation as finished
-(void) terminateOperation {
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    finished = YES;
    executing = NO;
    downloadDone = YES;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

//==========================================================
#pragma mark NSOperation state Delegate methods
//==========================================================

// NSOperation state methods
- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isExecuting {
    return executing;
}

- (BOOL)isFinished {
    return finished;
}


@end
