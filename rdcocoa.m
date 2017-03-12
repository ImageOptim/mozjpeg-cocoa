
#ifdef COCOA_SUPPORTED

#include "cdjpeg.h"   /* Common decls for cjpeg/djpeg applications */
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

typedef struct cocoa_source_struct {
    struct cjpeg_source_struct pub;
    unsigned char *rgbx_data;
    int width, height;
    int row;
} cocoa_source_struct;


METHODDEF(void)
finish_input_cocoa (j_compress_ptr cinfo, cjpeg_source_ptr sinfo);

METHODDEF(JDIMENSION)
get_pixel_rows_cocoa (j_compress_ptr cinfo, cjpeg_source_ptr sinfo);

METHODDEF(void)
start_input_cocoa (j_compress_ptr cinfo, cjpeg_source_ptr sinfo);


GLOBAL(cjpeg_source_ptr)
jinit_read_cocoa(j_compress_ptr cinfo)
{
    cocoa_source_struct *source = (*cinfo->mem->alloc_small)((j_common_ptr) cinfo, JPOOL_IMAGE, sizeof(cocoa_source_struct));

    memset(source, 0, sizeof(*source));

    /* Fill in method ptrs, except get_pixel_rows which start_input sets */
    source->pub.start_input = start_input_cocoa;
    source->pub.finish_input = finish_input_cocoa;

    return &source->pub;
}

METHODDEF(void)
start_input_cocoa (j_compress_ptr cinfo, cjpeg_source_ptr sinfo)
{
    cocoa_source_struct *source = (cocoa_source_struct *)sinfo;

    unsigned char *pixel_data;
    int width, height;
    @autoreleasepool {
        NSFileHandle *fh = [[NSFileHandle alloc] initWithFileDescriptor:fileno(source->pub.input_file)];
        NSData *data = [fh readDataToEndOfFile];
        CGImageRef image = [[NSBitmapImageRep imageRepWithData:data] CGImage];
        [fh release];

        if (!image) {
            ERREXIT(cinfo,JERR_UNSUPPORTED_FORMAT);
        }

        width = CGImageGetWidth(image);
        height = CGImageGetHeight(image);

        pixel_data = calloc(width*height,3);

        CGColorSpaceRef colorspace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);

        CGContextRef context = CGBitmapContextCreate(pixel_data,
                                                     width, height,
                                                     8, width*4,
                                                     colorspace,
                                                     (CGBitmapInfo)kCGImageAlphaNoneSkipLast);

        CGColorSpaceRelease(colorspace);

        if (!context) {
            ERREXIT(cinfo,JERR_UNSUPPORTED_FORMAT);
        }

        CGContextDrawImage(context, CGRectMake(0.0, 0.0, width, height), image);
        CGContextRelease(context);
    }

    cinfo->in_color_space = JCS_RGB;
    cinfo->input_components = 3;
    cinfo->input_gamma = 0.45455;
    source->width = width;
    source->height = height;
    source->rgbx_data = pixel_data;

    cinfo->image_width = width;
    cinfo->image_height = height;

    sinfo->get_pixel_rows = get_pixel_rows_cocoa;
    source->pub.buffer = (*cinfo->mem->alloc_sarray)((j_common_ptr)cinfo, JPOOL_IMAGE, (JDIMENSION)(width*cinfo->input_components), 1);
    source->pub.buffer_height = 1;
}

METHODDEF(JDIMENSION)
get_pixel_rows_cocoa (j_compress_ptr cinfo, cjpeg_source_ptr sinfo)
{
    cocoa_source_struct *source = (cocoa_source_struct *)sinfo;

    unsigned char *row_start = &source->rgbx_data[source->width*4 * source->row++];
    for(int i=0; i < source->width; i++) {
        source->pub.buffer[0][i*3+0] = row_start[i*4+0];
        source->pub.buffer[0][i*3+1] = row_start[i*4+1];
        source->pub.buffer[0][i*3+2] = row_start[i*4+2];
    }

    return 1;
}

METHODDEF(void)
finish_input_cocoa (j_compress_ptr cinfo, cjpeg_source_ptr sinfo)
{
    cocoa_source_struct *source = (cocoa_source_struct *)sinfo;
    free(source->rgbx_data);
}

#endif
