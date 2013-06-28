#ScrollingPDFViewer

##DESCRIPTION

This is a simple project to show long PDF documents in a UIScrollView. The approach is similar to a UITableView, where each pages are shown in views which are swapped around and reused for efficiency. Rendering is done in the background, managed via NSOperationQueue. This doesn't currently support zooming.

This is good if you want to build additional UI on a PDF and need control over the display. Otherwise, just use a UIWebView.

This was a fun little project, but it probably isn't suitable for dropping into a new project without some modification. On the plus side, it is small enough to modify as you like. It seems to perform well.

The included document, LargeDocument.pdf shows how the app performs when each page of the pdf takes a while to render. This app also works well with pdfs that have several hundred pages that each render very quickly (not included).


##License

The MIT License (MIT)

Copyright (c) 2013 Bridger Maxwell

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.