#import "PDFPageView.h"
#import <QuartzCore/QuartzCore.h>

@implementation PDFPageView
{
    CGPDFPageRef pdfPage;
    UIColor *randomColor;
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
    }
    return self;
}


// Set the CGPDFPageRef for the view.
- (void)setPage:(CGPDFPageRef)newPage
{
    CGPDFPageRelease(self->pdfPage);
    self->pdfPage = CGPDFPageRetain(newPage);
}


-(void)drawRect:(CGRect)r
{
    CGContextRef context = UIGraphicsGetCurrentContext ();
    CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
    CGContextFillRect (context, self.bounds);

    if ([self backgroundImage]) {
        [[self backgroundImage] drawAtPoint:CGPointZero];
    }
}

// Clean up.
- (void)dealloc
{
    CGPDFPageRelease(pdfPage);
}

@end
