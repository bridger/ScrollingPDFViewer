#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface PDFScrollView : UIScrollView <UIScrollViewDelegate> 

- (void)setPDFDocument:(CGPDFDocumentRef)PDFDocument;

@end
