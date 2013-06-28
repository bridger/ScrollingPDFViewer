#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#define PAGE_SPACE 10

@interface PDFScrollView : UIScrollView <UIScrollViewDelegate> 

- (void)setPDFDocument:(CGPDFDocumentRef)PDFDocument;

@end
