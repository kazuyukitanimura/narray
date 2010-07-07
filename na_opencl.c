/*
  na_opencl.c
  Numerical Array Extention on OpenCL for Ruby
    (C) Copyright 2010 by Kazuyuki TANIMURA

  This program is free software.
  You can distribute/modify this program
  under the same terms as Ruby itself.
  NO WARRANTY.
*/
#include <stdio.h>
#include "ruby.h"
#include "narray.h"
#ifdef __OPENCL__
#include "narray_local.h"
#include "na_opencl.h"

void
 na_opencl_do_loop_unary(cl_command_queue queue, int nd, char *p1, char *p2, struct slice *s1, struct slice *s2, cl_mem buf1, cl_mem buf2, void* kernel_func )
{
  int *si;
  int  i;
  int  ps1 = s1[0].pstep;
  int  ps2 = s2[0].pstep;

  i  = nd;
  si = ALLOCA_N(int,nd);
  s1[i].p = p1;
  s2[i].p = p2;
///////////////////////////////////////////////////
  size_t global_item_size = s2[0].n;
  cl_int ret;

  /* set OpenCL kernel arguments */
  ret = clSetKernelArg(kernel_func, 2, sizeof(cl_int), (void *)&ps1);
  ret = clSetKernelArg(kernel_func, 5, sizeof(cl_int), (void *)&ps2);
///////////////////////////////////////////////////
  for(;;) {
    /* set pointers */
    while (i > 0) {
      --i;
      s2[i].p = s2[i].pbeg + s2[i+1].p;
      s1[i].p = s1[i].pbeg + s1[i+1].p;
      si[i] = s1[i].n;
    }
///////////////////////////////////////////////////
    /* set OpenCL kernel arguments */
    ret = clSetKernelArg(kernel_func, 0, global_item_size*MAX(ps1,1)*sizeof(cl_char), NULL);
    ret = clSetKernelArg(kernel_func, 1, sizeof(cl_mem), (void *)&buf1);
    int b1 = (int)(s1[0].p-p1); 
    ret = clSetKernelArg(kernel_func, 3, sizeof(cl_int), &b1);
    ret = clSetKernelArg(kernel_func, 4, sizeof(cl_mem), (void *)&buf2);
    int b2 = (int)(s2[0].p-p2); 
    ret = clSetKernelArg(kernel_func, 6, sizeof(cl_int), &b2);

    /* execute OpenCL kernel */
    ret = clEnqueueNDRangeKernel(queue, kernel_func, 1, NULL, &global_item_size, NULL, 0, NULL, NULL);
    if (ret != CL_SUCCESS) {
      rb_raise(rb_eRuntimeError, "Failed executing kernel \n");
    }
///////////////////////////////////////////////////
    /* rank up */
    do {
      if ( ++i >= nd ) {
///////////////////////////////////////////////////
        /* run commands in queue and make sure all commands in queue is done */
        clFlush(queue); clFinish(queue);
///////////////////////////////////////////////////
        return;
      }
    } while ( --si[i] == 0 );
    /* next point */
    s1[i].p += s1[i].pstep;
    s2[i].p += s2[i].pstep;
  }
}

void
 na_opencl_do_loop_binary(cl_command_queue queue, int nd, char *p1, char *p2, char *p3, struct slice *s1, struct slice *s2, struct slice *s3, cl_mem buf1, cl_mem buf2, cl_mem buf3, void* kernel_func )
{
  int i;
  int ps1 = s1[0].pstep;
  int ps2 = s2[0].pstep;
  int ps3 = s3[0].pstep;
  int *si;

  si = ALLOCA_N(int,nd);
  i  = nd;
  s1[i].p = p1;
  s2[i].p = p2;
  s3[i].p = p3;
///////////////////////////////////////////////////
  size_t global_item_size = s2[0].n;
  cl_int ret;

  /* set OpenCL kernel arguments */
  ret = clSetKernelArg(kernel_func, 2, sizeof(int), (void *)&ps1);
  ret = clSetKernelArg(kernel_func, 5, sizeof(int), (void *)&ps2);
  ret = clSetKernelArg(kernel_func, 8, sizeof(int), (void *)&ps3);
///////////////////////////////////////////////////
  for(;;) {
    /* set pointers */
    while (i > 0) {
      --i;
      s3[i].p = s3[i].pbeg + s3[i+1].p;
      s2[i].p = s2[i].pbeg + s2[i+1].p;
      s1[i].p = s1[i].pbeg + s1[i+1].p;
      si[i] = s1[i].n;
    }
    /* rank 0 loop */
///////////////////////////////////////////////////
    /* set OpenCL kernel arguments */
    ret = clSetKernelArg(kernel_func, 0, global_item_size*MAX(ps1,1)*sizeof(cl_char), NULL);
    ret = clSetKernelArg(kernel_func, 1, sizeof(cl_mem), (void *)&buf1);
    int b1 = (int)(s1[0].p-p1); 
    ret = clSetKernelArg(kernel_func, 3, sizeof(cl_int), &b1);
    ret = clSetKernelArg(kernel_func, 4, sizeof(cl_mem), (void *)&buf2);
    int b2 = (int)(s2[0].p-p2); 
    ret = clSetKernelArg(kernel_func, 6, sizeof(cl_int), &b2);
    ret = clSetKernelArg(kernel_func, 7, sizeof(cl_mem), (void *)&buf3);
    int b3 = (int)(s3[0].p-p3); 
    ret = clSetKernelArg(kernel_func, 9, sizeof(cl_int), &b3);

    /* execute OpenCL kernel */
    ret = clEnqueueNDRangeKernel(queue, kernel_func, 1, NULL, &global_item_size, NULL, 0, NULL, NULL); //let OpenCL decide the local item size by feeding NULL to 6th arg
    if (ret != CL_SUCCESS) {
      rb_raise(rb_eRuntimeError, "Failed executing kernel \n");
    }
///////////////////////////////////////////////////
    /* rank up */
    do {
      if ( ++i >= nd ) {
///////////////////////////////////////////////////
        /* run commands in queue and make sure all commands in queue is done */
        clFlush(queue); clFinish(queue);
///////////////////////////////////////////////////
        return;
      }
    } while ( --si[i] == 0 );
    /* next point */
    s1[i].p += s1[i].pstep;
    s2[i].p += s2[i].pstep;
    s3[i].p += s3[i].pstep;
  }
} 

void
 Init_na_opencl()
{
  cl_program program = NULL;
  cl_platform_id platform_id = NULL;
  cl_uint ret_num_devices;
  cl_uint ret_num_platforms;
  cl_int ret;

  char fileName[] = KERNEL_SRC_FILE;
  FILE *fp;
  char *kernel_src_code;
  size_t kernel_src_size;
  const char buildOptions[] = HDRDIR;

  /* load kernel source code */
  fp = fopen(fileName, "r");
  if (!fp) {
    rb_raise(rb_eIOError, "Failed loading %s\n", fileName);
  }
  kernel_src_code = (char*)malloc(MAX_SOURCE_SIZE);
  kernel_src_size = fread( kernel_src_code, 1, MAX_SOURCE_SIZE, fp);
  fclose( fp );

  /* get platform device info */
  clGetPlatformIDs(1, &platform_id, &ret_num_platforms);
  clGetDeviceIDs( platform_id, CL_DEVICE_TYPE_DEFAULT, 1, &device_id, &ret_num_devices);

  /* create OpenCL context */
  context = clCreateContext( NULL, 1, &device_id, NULL, NULL, &ret);

  /* create kernel program from the kernel source code */
  program = clCreateProgramWithSource(context, 1, (const char **)&kernel_src_code, (const size_t *)&kernel_src_size, &ret);
  free(kernel_src_code);

  /* build the kernel program */
  ret = clBuildProgram(program, 1, &device_id, buildOptions, NULL, NULL);
  if (ret != CL_SUCCESS) {
    switch (ret) {
      case CL_INVALID_PROGRAM:
        fprintf(stderr, "program is not a valid program object.\n");break;
      case CL_INVALID_VALUE:
        fprintf(stderr, "device_list is NULL and num_devices is greater than zero, or if device_list is not NULL and num_devices is zero.\nor\npfn_notify is NULL but user_data is not NULL.\n");break;
      case CL_INVALID_DEVICE:
        fprintf(stderr, "OpenCL devices listed in device_list are not in the list of devices associated with program.\n");break;
      case CL_INVALID_BINARY:
        fprintf(stderr, "program is created with clCreateWithProgramWithBinary and devices listed in device_list do not have a valid program binary loaded.\n");break;
      case CL_INVALID_BUILD_OPTIONS:
        fprintf(stderr, "the build options specified by options are invalid.\n");break;
      case CL_INVALID_OPERATION:
        fprintf(stderr, "the build of a program executable for any of the devices listed in device_list by a previous call to clBuildProgram for program has not completed.\nor\nthere are kernel objects attached to program.\n");break;
      case CL_COMPILER_NOT_AVAILABLE:
        fprintf(stderr, "program is created with clCreateProgramWithSource and a compiler is not available i.e. CL_DEVICE_COMPILER_AVAILABLE specified in the table of OpenCL Device Queries for clGetDeviceInfo is set to CL_FALSE.\n");break;
      case CL_BUILD_PROGRAM_FAILURE:
        fprintf(stderr, "there is a failure to build the program executable. This error will be returned if clBuildProgram does not return until the build has completed.\n");break;
      case CL_OUT_OF_HOST_MEMORY:
        fprintf(stderr, "there is a failure to allocate resources required by the OpenCL implementation on the host.\n");break;
    }
    size_t len;
    char log[2048];
    clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, sizeof(log), log, &len);
    rb_raise(rb_eRuntimeError, "Failed building %s\n%s\n%s\n", fileName, log);
  }

  /* create OpenCL kernels */
  CREATE_OPENCL_KERNELS(program, ret);

//  /* releasing OpenCL objetcs */
//  ret = clReleaseKernel((cl_kernel)AddBFuncs[NA_LINT]); //for dev
//  ret = clReleaseKernel((cl_kernel)SbtBFuncs[NA_LINT]); //for dev
//  ret = clReleaseKernel((cl_kernel)MulBFuncs[NA_LINT]); //for dev
//  ret = clReleaseKernel((cl_kernel)DivBFuncs[NA_LINT]); //for dev
//  ret = clReleaseKernel((cl_kernel)ModBFuncs[NA_LINT]); //for dev
//  ret = clReleaseKernel((cl_kernel)MulAddFuncs[NA_LINT]); //for dev
//  ret = clReleaseKernel((cl_kernel)MulSbtFuncs[NA_LINT]); //for dev
//  ret = clReleaseProgram(program); //for dev
//  ret = clReleaseContext(context); //for dev

}
#endif
