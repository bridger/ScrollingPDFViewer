#import "PDFScrollView.h"
#import "PDFPageView.h"
#import <QuartzCore/QuartzCore.h>


#define PAGE_SPACE 10 //Space between pages
#define MAX_INVISIBLE_PAGES 9 //Once we have more than this many pages off-screen, they become elligble for re-use

@interface IgnorableBlockOperation : NSBlockOperation
//An operation may have finished, but we decided we no longer need before it is able to report it's result back to the main thread. We can no longer cancel such an operation, so instead we set it as noLongerNeeded. This is only set/read from the main thread, so it is a safe way of determining if an operation's results should still be used.
@property (nonatomic) BOOL isNoLongerNeeded;
@end

@implementation IgnorableBlockOperation
- (void)setIsNoLongerNeeded:(BOOL)isNoLongerNeeded {
    _isNoLongerNeeded = isNoLongerNeeded;
    if (isNoLongerNeeded) {
        [self cancel];
    }
}
@end


//PageRecord contains information about each page in the PDF. This is to keep track of the associated objects (renderers, views) and so we only need to query the PDF document once to find out page sizes, etc.
@interface PageRecord : NSObject
@property CGRect pageRect;
@property CGFloat startYPosition;
@property (nonatomic, retain) PDFPageView *view;
@property (nonatomic, retain) IgnorableBlockOperation *renderOperation;
@end

@implementation PageRecord
- (id)initWithPageRect:(CGRect)pageRect startYPosition:(CGFloat)startYPosition {
    self = [super init];
    if (self) {
        _pageRect = pageRect;
        _startYPosition = startYPosition;
    }
    return self;
}
@end


@interface PDFScrollView () {
}

@property (nonatomic, retain) NSArray *pageRecords;
@property (nonatomic, retain) NSMutableIndexSet *visiblePages; //These pages are showing to the user
@property (nonatomic, retain) NSMutableIndexSet *invisiblePages; //Pages that are rendered and active as subviews, but are currently offscreen and are elligible to go into the reusepool
@property (nonatomic, retain) NSMutableArray *reusePool; //These are views that can be repurposed for new pages
@property (nonatomic, retain) NSOperationQueue *renderQueue; //This is a queue for rendering pages. It is serial because pages of a PDF can't be distributed among multiple threads
@property (nonatomic) NSUInteger totalAllocations;
@property CGFloat PDFScale;
@property CGSize documentSize;

@end



@implementation PDFScrollView
{
    CGPDFDocumentRef _PDFDocument;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.delegate = self;
        
        [self setReusePool:[NSMutableArray array]];
        [self setInvisiblePages:[NSMutableIndexSet indexSet]];
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:1]; //Make it serial. Rendering pages isn't safe across multiple threads
        [self setRenderQueue:queue];
        
        [self setShowsVerticalScrollIndicator:YES];
    }
    return self;
}

- (void)setPDFDocument:(CGPDFDocumentRef)PDFDocument
{
    //First, we ensure we are through with the PDF on the background threads before we mess with it on the main thread
    [[self renderQueue] cancelAllOperations];
    [[self renderQueue] waitUntilAllOperationsAreFinished];
    
    CGPDFDocumentRetain(PDFDocument);
    CGPDFDocumentRelease(_PDFDocument);
    _PDFDocument = PDFDocument;
    
    //Size up the document
    size_t pageCount = CGPDFDocumentGetNumberOfPages(_PDFDocument);
    NSMutableArray *pageRecords = [NSMutableArray arrayWithCapacity:pageCount];
    CGFloat currentHeight = 0;
    CGFloat maxWidth = 0;
    for (size_t currentPage = 1; currentPage <= pageCount; currentPage++) {
        CGPDFPageRef pdfPage = CGPDFDocumentGetPage(_PDFDocument, currentPage);
        
        CGRect pageRect = CGPDFPageGetBoxRect(pdfPage, kCGPDFMediaBox);
        
        maxWidth = MAX(maxWidth, pageRect.size.width);
        [pageRecords addObject:[[PageRecord alloc] initWithPageRect:pageRect startYPosition:currentHeight]];
        
        currentHeight += pageRect.size.height;
        if (currentPage != pageCount) {
            currentHeight += PAGE_SPACE;
        }
    }
    
    [self setPageRecords:pageRecords];
    [self setDocumentSize:CGSizeMake(maxWidth, currentHeight)];
    [self setPDFScale:self.frame.size.width/_documentSize.width];
    
    [self setContentSize:CGSizeMake(self.frame.size.width, currentHeight * _PDFScale)];
}

- (void)layoutTableRows
{
    if ([[self pageRecords] count] > 0) {
#define EXTRA_MARGIN 100 //This determines how much off-screen space we consider on-screen enough that we render it. This way, we render a view just before it is visible
        
        CGFloat currentStartY = ([self contentOffset].y - EXTRA_MARGIN) / _PDFScale;
        CGFloat currentEndY = ([self contentOffset].y + [self frame].size.height + EXTRA_MARGIN * 2) / _PDFScale;
        
        NSInteger pageToDisplay = [self findPageForOffsetY:currentStartY inRange:NSMakeRange(0, [[self pageRecords] count])];
        
        NSMutableIndexSet* newVisiblePages = [[NSMutableIndexSet alloc] init];
        
        CGFloat yOrigin;
        CGFloat rowHeight;
        do
        {
            [newVisiblePages addIndex:pageToDisplay];
            
            PageRecord *record = [[self pageRecords] objectAtIndex:pageToDisplay];
            
            yOrigin = [record startYPosition];
            rowHeight = [record pageRect].size.height;
            
            if (![record view]) {
                CGRect pageFrame = CGRectMake(0, yOrigin * _PDFScale, self.bounds.size.width, rowHeight * _PDFScale);
                PDFPageView *view;
                if ([[self reusePool] count] > 0) {
                    NSLog(@"Creating a new page: %d. Used the pool. Total Allocations: %d", pageToDisplay, [self totalAllocations]);
                    view = [[self reusePool] lastObject];
                    [[self reusePool] removeLastObject];
                    [view setFrame:pageFrame];
                } else {
                    [self setTotalAllocations:[self totalAllocations] + 1];
                    //NSLog(@"Creating a new page: %d. Total Allocations: %d", pageToDisplay, [self totalAllocations]);
                    view = [[PDFPageView alloc] initWithFrame:pageFrame];
                }
                
                [record setView:view];
                [self insertSubview:view atIndex:0];
                [view setNeedsDisplay];
                
                IgnorableBlockOperation *renderOperation = [IgnorableBlockOperation blockOperationWithBlock:^{
                    if (![renderOperation isCancelled]) {
                        CGPDFPageRef pdfPage = CGPDFDocumentGetPage(_PDFDocument, pageToDisplay +1);
                        
                        CGRect pageRect = CGRectMake(0, 0, pageFrame.size.width, pageFrame.size.height);
                        UIGraphicsBeginImageContext(pageFrame.size);
                        CGContextRef context = UIGraphicsGetCurrentContext();
                        
                        // First fill the background with white.
                        CGContextSetRGBFillColor(context, 1.0,1.0,1.0,1.0);
                        CGContextFillRect(context, pageFrame);
                        
                        CGContextSaveGState(context);
                        // Flip the context so that the PDF page is rendered right side up.
                        CGContextTranslateCTM(context, 0.0, pageRect.size.height);
                        CGContextScaleCTM(context, 1.0, -1.0);
                        
                        // Scale the context so that the PDF page is rendered at the correct size for the zoom level.
                        CGContextScaleCTM(context, _PDFScale,_PDFScale);
                        if ([renderOperation isCancelled]) {
                            UIGraphicsEndImageContext();
                            return;
                        }
                        CGContextDrawPDFPage(context, pdfPage);
                        CGContextRestoreGState(context);
                        
                        if ([renderOperation isCancelled]) {
                            UIGraphicsEndImageContext();
                            return;
                        }
                        UIImage *backgroundImage = UIGraphicsGetImageFromCurrentImageContext();
                        UIGraphicsEndImageContext();
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (![renderOperation isCancelled] && ![renderOperation isNoLongerNeeded]) {
                                [[record view] setBackgroundImage:backgroundImage];
                                [[record view] setNeedsDisplay];
                            }
                        });
                    }
                }];
                
                [renderOperation setQueuePriority:NSOperationQueuePriorityNormal];
                [record setRenderOperation:renderOperation];
                [[self renderQueue] addOperation:renderOperation];
            } else {
                //Make sure the render priority is above any other invisible views
                [[record renderOperation] setQueuePriority:NSOperationQueuePriorityNormal];
            }
            
            pageToDisplay++;
        }
        while (yOrigin + rowHeight < currentEndY && pageToDisplay < [[self pageRecords] count]);
        
        [self returnNonVisiblePagesToThePool:newVisiblePages];
    }
}

// We have a set of pages that used to be visible ([self visiblePages]). We compare this with the new
// list of visible pages, and return any old ones to the pool
- (void)returnNonVisiblePagesToThePool:(NSMutableIndexSet*)currentVisiblePages
{
    [[self visiblePages] removeIndexes:currentVisiblePages];
    //Now [self visiblePages] contains pages that are newly invisible
    
    [[self visiblePages] enumerateIndexesUsingBlock:^(NSUInteger page, BOOL *stop) {
        //We lower the priority of the invisible pages, but we don't cancel them until they are purged
        PageRecord *record = [[self pageRecords] objectAtIndex:page];
        [[record renderOperation] setQueuePriority:NSOperationQueuePriorityVeryLow];
    }];
    [[self invisiblePages] addIndexes:[self visiblePages]];
    [self setVisiblePages:currentVisiblePages];
    
    if ([[self invisiblePages] count] > MAX_INVISIBLE_PAGES) {
        NSLog(@"We currently have %i pages invisible. We will replenish the pool, which has %i", [[self invisiblePages] count], [[self reusePool] count]);
        
        //Purge some invisible pages to the reusePool
        //Now that we have reached the max number of invisible pages, any pages that are > (MAX_INVISIBLE_PAGES / 3) away, we purge them. This leaves at most (MAX_INVISIBLE_PAGES / 3) in the invisible pages.
        
        NSUInteger maxDistance = MAX_INVISIBLE_PAGES / 3;
        NSInteger firstVisiblePage = [currentVisiblePages firstIndex];
        NSInteger lastVisiblePage = [currentVisiblePages lastIndex];
        
        NSMutableIndexSet *purgedPages = [NSMutableIndexSet indexSet];
        [[self invisiblePages] enumerateIndexesUsingBlock:^(NSUInteger page, BOOL *stop) {
            if (ABS(firstVisiblePage - (NSInteger)page) > maxDistance &&
                ABS(lastVisiblePage - (NSInteger)page) > maxDistance) {
                //Purge!
                [purgedPages addIndex:page];
                
                PageRecord *purgeRecord = [[self pageRecords] objectAtIndex:page];
                [[purgeRecord renderOperation] setIsNoLongerNeeded:YES]; //If it hasn't already started, it will no longer render
                [purgeRecord setRenderOperation:NULL];
                if ([purgeRecord view]) {
                    [[self reusePool] addObject:[purgeRecord view]];
                    [[purgeRecord view] removeFromSuperview];
                    [[purgeRecord view] setBackgroundImage:NULL]; //Release the rendered image, if any
                    [purgeRecord setView:NULL];
                }
            }
        }];
        
        [[self invisiblePages] removeIndexes:purgedPages];
        
        NSLog(@"We now have %i pages invisible. Now the pool has %i", [[self invisiblePages] count], [[self reusePool] count]);
    }
}


- (NSInteger)findPageForOffsetY:(CGFloat)yPosition inRange:(NSRange)range
{
    if ([[self pageRecords] count] == 0) return 0;
    
    PageRecord* pageRecord = [[PageRecord alloc] init];
    [pageRecord setStartYPosition:yPosition];
    
    NSInteger returnValue = [[self pageRecords] indexOfObject:pageRecord inSortedRange:NSMakeRange(0, [[self pageRecords] count]) options:NSBinarySearchingInsertionIndex usingComparator:^NSComparisonResult(PageRecord* pageRecord1, PageRecord* pageRecord2) {
        if ([pageRecord1 startYPosition] < [pageRecord2 startYPosition])
            return NSOrderedAscending;
        return NSOrderedDescending;
    }];
    
    if (returnValue == 0) return 0;
    return returnValue - 1;
}

- (void) setContentOffset:(CGPoint)contentOffset
{
    [super setContentOffset: contentOffset];
    [self layoutTableRows];
}

- (void)dealloc
{
    [[self renderQueue] cancelAllOperations];
    [[self renderQueue] waitUntilAllOperationsAreFinished];
    // Clean up.
    CGPDFDocumentRelease(_PDFDocument);
}


@end
