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

/* global variables */
cl_device_id device_id;
cl_context context;
//size_t work_item_sizes[3];
//size_t work_group_size;
size_t global_item_size, local_item_size;

cl_event event;
cl_ulong acctime;
cl_int count;
void checkTime(cl_event ev)
{
  cl_ulong start,end;
  clWaitForEvents(1,&ev);
  clGetEventProfilingInfo(ev,CL_PROFILING_COMMAND_START, sizeof(cl_ulong), &start,NULL);
  clGetEventProfilingInfo(ev,CL_PROFILING_COMMAND_END,   sizeof(cl_ulong), &end,  NULL);
  //printf("%10.5f [ms]\n",(end-start)/1000000.0);
  acctime+=(end-start);
  printf("%10.5f [ms]\n",acctime/1000000.0/(++count));
}

void
 na_opencl_do_IndGenKernel(cl_command_queue queue, int len, int type, cl_mem buf, int i, int start, int step)
{
  int argn = 0;

  /* set OpenCL kernel arguments */
  clSetKernelArg(IndGenKernels[type], argn++, sizeof(cl_int), (void *)&len);
  clSetKernelArg(IndGenKernels[type], argn++, sizeof(cl_mem), (void *)&buf);
  clSetKernelArg(IndGenKernels[type], argn++, sizeof(cl_int), (void *)&i);
  clSetKernelArg(IndGenKernels[type], argn++, sizeof(cl_int), (void *)&start);
  clSetKernelArg(IndGenKernels[type], argn++, sizeof(cl_int), (void *)&step);

  /* execute OpenCL kernel */
  OPENCL_EXKRNL(queue, IndGenKernels[type], &event);
//checkTime(event);

  /* run commands in queue and make sure all commands in queue is done */
  clFinish(queue);
}

static void
 na_opencl_do_unary_Kernel(cl_command_queue queue, cl_kernel kernel, int len, cl_mem buf1, int i1, size_t b1, cl_mem buf2, int i2, size_t b2)
{
  int argn = 0;

  /* set OpenCL kernel arguments */
  clSetKernelArg(kernel, argn++, sizeof(cl_int), (void *)&len);
  clSetKernelArg(kernel, argn++, sizeof(cl_mem), (void *)&buf1);
  clSetKernelArg(kernel, argn++, sizeof(cl_int), (void *)&i1);
  clSetKernelArg(kernel, argn++, sizeof(cl_int), (void *)&b1);
  clSetKernelArg(kernel, argn++, sizeof(cl_mem), (void *)&buf2);
  clSetKernelArg(kernel, argn++, sizeof(cl_int), (void *)&i2);
  clSetKernelArg(kernel, argn++, sizeof(cl_int), (void *)&b2);

  /* execute OpenCL kernel */
  OPENCL_EXKRNL(queue, kernel, NULL);

  /* run commands in queue and make sure all commands in queue is done */
  clFinish(queue);
}

void
 na_opencl_do_SetKernel(cl_command_queue queue, int len, int type1, cl_mem buf1, int i1, int type2, cl_mem buf2, int i2)
{
  size_t b = 0;

  na_opencl_do_unary_Kernel(queue, SetKernels[type1][type2], len, buf1, i1, b, buf2, i2, b);
}

void
 na_opencl_do_loop_unary(cl_command_queue queue, int nd, char *p1, char *p2, struct slice *s1, struct slice *s2, cl_mem buf1, cl_mem buf2, cl_kernel kernel)
{
  int *si;
  int i;
  int ps1 = s1[0].pstep;
  int ps2 = s2[0].pstep;

  i  = nd;
  si = ALLOCA_N(int,nd);
  s1[i].p = 0;//p1;
  s2[i].p = 0;//p2;

  for(;;) {
    /* set pointers */
    while (i > 0) {
      --i;
      s2[i].p = s2[i].pbeg + s2[i+1].p;
      s1[i].p = s1[i].pbeg + s1[i+1].p;
      si[i] = s1[i].n;
    }
///////////////////////////////////////////////////
    na_opencl_do_unary_Kernel(queue, kernel, s2[0].n, buf1, ps1, (size_t)s1[0].p, buf2, ps2, (size_t)s2[0].p);
///////////////////////////////////////////////////
    /* rank up */
    do {
      if ( ++i >= nd ) return;
    } while ( --si[i] == 0 );
    /* next point */
    s1[i].p += s1[i].pstep;
    s2[i].p += s2[i].pstep;
  }
}

void
 na_opencl_do_loop_binary(cl_command_queue queue, int nd, char *p1, char *p2, char *p3, struct slice *s1, struct slice *s2, struct slice *s3, cl_mem buf1, cl_mem buf2, cl_mem buf3, cl_kernel kernel)
{
  int i;
  int ps1 = s1[0].pstep;
  int ps2 = s2[0].pstep;
  int ps3 = s3[0].pstep;
  int *si;

  si = ALLOCA_N(int,nd);
  i  = nd;
  s1[i].p = 0;//p1;
  s2[i].p = 0;//p2;
  s3[i].p = 0;//p3;
  int argn = 0;

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
    clSetKernelArg(kernel, argn++, sizeof(cl_int), (void *)&(s2[0].n));
    clSetKernelArg(kernel, argn++, sizeof(cl_mem), (void *)&buf1);
    clSetKernelArg(kernel, argn++, sizeof(cl_int), (void *)&ps1);
    clSetKernelArg(kernel, argn++, sizeof(cl_int), (void *)&(s1[0].p));
    clSetKernelArg(kernel, argn++, sizeof(cl_mem), (void *)&buf2);
    clSetKernelArg(kernel, argn++, sizeof(cl_int), (void *)&ps2);
    clSetKernelArg(kernel, argn++, sizeof(cl_int), (void *)&(s2[0].p));
    clSetKernelArg(kernel, argn++, sizeof(cl_mem), (void *)&buf3);
    clSetKernelArg(kernel, argn++, sizeof(cl_int), (void *)&ps3);
    clSetKernelArg(kernel, argn++, sizeof(cl_int), (void *)&(s3[0].p));

    /* execute OpenCL kernel */
    OPENCL_EXKRNL(queue, kernel, &event);
    //checkTime(event);

    /* run commands in queue and make sure all commands in queue is done */
    clFinish(queue);
///////////////////////////////////////////////////
    /* rank up */
    do {
      if ( ++i >= nd ) return;
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
  cl_device_type device_type;
  cl_uint compute_unit;
  cl_int ret;

  char fileName[] = KERNEL_SRC_FILE;
  FILE *fp;
  char *kernel_src_code;
  size_t kernel_src_size;
  const char buildOptions[] = HDRDIR;
  long begin, end;

  /* load kernel source code */
  fp = fopen(fileName, "r");
  if (!fp) rb_raise(rb_eIOError, "Failed loading %s\n", fileName);
  fseek(fp, 0, SEEK_END);
  end = ftell(fp);
  fseek(fp, 0, SEEK_SET);
  begin = ftell(fp);
  kernel_src_size = (size_t)((end-begin)*sizeof(char));
  kernel_src_code = (char*)malloc(kernel_src_size);
  fread( kernel_src_code, sizeof(char), kernel_src_size, fp);
  fclose( fp );

  /* get platform device info */
  clGetPlatformIDs(1, &platform_id, &ret_num_platforms);
  //clGetDeviceIDs( platform_id, CL_DEVICE_TYPE_DEFAULT, 1, &device_id, &ret_num_devices);
  clGetDeviceIDs( platform_id, CL_DEVICE_TYPE_CPU, 1, &device_id, &ret_num_devices);
  //clGetDeviceInfo(device_id, CL_DEVICE_MAX_WORK_ITEM_SIZES, sizeof(work_item_sizes), work_item_sizes,  NULL);
  //clGetDeviceInfo(device_id, CL_DEVICE_MAX_WORK_GROUP_SIZE, sizeof(size_t),          &work_group_size, NULL);
  clGetDeviceInfo(device_id, CL_DEVICE_MAX_COMPUTE_UNITS,   sizeof(cl_uint),         &compute_unit,    NULL);
  clGetDeviceInfo(device_id, CL_DEVICE_TYPE,                sizeof(cl_device_type),  &device_type,     NULL);
  local_item_size = (device_type == CL_DEVICE_TYPE_GPU)? 64 : 1;
  global_item_size = local_item_size * compute_unit;

  /* create OpenCL context */
  context = clCreateContext( NULL, 1, &device_id, NULL, NULL, &ret);

  /* create kernel program from the kernel source code */
  program = clCreateProgramWithSource(context, 1, (const char **)&kernel_src_code, NULL, &ret);
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
    rb_raise(rb_eRuntimeError, "Failed building %s\n%s\n", fileName, log);
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
