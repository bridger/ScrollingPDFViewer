#import "ScrollingPDFViewerViewController.h"
#import "PDFScrollView.h"
#import <QuartzCore/QuartzCore.h>

@implementation ScrollingPDFViewerViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    /*
     Open the PDF document, extract the first page, and pass the page to the PDF scroll view.
     */
    NSURL *pdfURL = [[NSBundle mainBundle] URLForResource:@"LargeDocument" withExtension:@"pdf"];
    
    CGPDFDocumentRef PDFDocument = CGPDFDocumentCreateWithURL((__bridge CFURLRef)pdfURL);
    
    [(PDFScrollView *)self.view setPDFDocument:PDFDocument];

    CGPDFDocumentRelease(PDFDocument);
}


@end
