/*
  na_random.c
  Numerical Array Extention for Ruby
    (C) Copyright 2003-2008 by Masahiro TANAKA

  This program is free software.
  You can distribute/modify this program
  under the same terms as Ruby itself.
  NO WARRANTY.
*/

/* 
This is based on trimmed version of MT19937.  To get the original version,
contact <http://www.math.keio.ac.jp/~matumoto/emt.html>.

The original copyright notice follows.

   A C-program for MT19937, with initialization improved 2002/2/10.
   Coded by Takuji Nishimura and Makoto Matsumoto.
   This is a faster version by taking Shawn Cokus's optimization,
   Matthe Bellew's simplification, Isaku Wada's real version.

   Before using, initialize the state by using init_genrand(seed) 
   or init_by_array(init_key, key_length).

   Copyright (C) 1997 - 2002, Makoto Matsumoto and Takuji Nishimura,
   All rights reserved.                          

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

     1. Redistributions of source code must retain the above copyright
        notice, this list of conditions and the following disclaimer.

     2. Redistributions in binary form must reproduce the above copyright
        notice, this list of conditions and the following disclaimer in the
        documentation and/or other materials provided with the distribution.

     3. The names of its contributors may not be used to endorse or promote 
        products derived from this software without specific prior written 
        permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


   Any feedback is very welcome.
   http://www.math.keio.ac.jp/matumoto/emt.html
   email: matumoto@math.keio.ac.jp
*/
#include "ruby.h"
#include "narray.h"
#include "narray_local.h"

/* Period parameters */  
#define N 624
#define M 397
#define MATRIX_A 0x9908b0dfUL   /* constant vector a */
#define UMASK 0x80000000UL /* most significant w-r bits */
#define LMASK 0x7fffffffUL /* least significant r bits */
#define MIXBITS(u,v) ( ((u) & UMASK) | ((v) & LMASK) )
#define TWIST(u,v) ((MIXBITS(u,v) >> 1) ^ ((v)&1UL ? MATRIX_A : 0UL))

static u_int32_t state[N]; /* the array for the state vector  */
static int left = 1;
static int initf = 0;
static u_int32_t *next;
#ifdef __OPENCL__
cl_mem state_buf;
cl_mem left_buf;
cl_mem initf_buf;
cl_mem next_buf;
#endif

/* initializes state[N] with a seed */
static void
 init_genrand(u_int32_t s)
{
    int j;
    state[0]= s & 0xffffffffUL;
    for (j=1; j<N; ++j) {
        state[j] = (1812433253UL * (state[j-1] ^ (state[j-1] >> 30)) + j); 
        /* See Knuth TAOCP Vol2. 3rd Ed. P.106 for multiplier. */
        /* In the previous versions, MSBs of the seed affect   */
        /* only MSBs of the array state[].                        */
        /* 2002/01/09 modified by Makoto Matsumoto             */
        state[j] &= 0xffffffffUL;  /* for >32 bit machines */
    }
    left = 1; initf = 1;
}

static void
 next_state()
{
    u_int32_t *p=state;
    int j;

    /* if init_genrand() has not been called, */
    /* a default initial seed is used         */
    if (initf==0) init_genrand(5489UL);

    left = N;
    next = state;
    
    for (j=N-M+1; --j; ++p) 
        *p = p[M] ^ TWIST(p[0], p[1]);

    for (j=M; --j; ++p) 
        *p = p[M-N] ^ TWIST(p[0], p[1]);

    *p = p[M-N] ^ TWIST(p[0], state[0]);
}

#undef N
#undef M

/* These real versions are due to Isaku Wada, 2002/01/09 added */

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#include <time.h>
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif

static int first = 1;

static int
rand_init(seed)
    u_int32_t seed;
{
    static u_int32_t saved_seed;
    u_int32_t old;

    first = 0;
    init_genrand(seed);
    old = saved_seed;
    saved_seed = seed;

    return old;
}

static u_int32_t
 random_seed()
{
    static int n = 0;
    struct timeval tv;

    gettimeofday(&tv, 0);
    return tv.tv_sec ^ tv.tv_usec ^ getpid() ^ n++;
}

static VALUE
 na_s_srand(int argc, VALUE *argv, VALUE obj)
{
    VALUE sd;
    u_int32_t seed, old;

    rb_secure(4);
    if (rb_scan_args(argc, argv, "01", &sd) == 0) {
	seed = random_seed();
    }
    else {
	seed = NUM2ULONG(sd);
    }
    old = rand_init(seed);

    return ULONG2NUM(old);
}

/* - end of the code from ruby/random.c - */

#define genrand(y) \
{ if (--left == 0) next_state();\
  (y) = *next++;\
  (y) ^= ((y) >> 11);\
  (y) ^= ((y) << 7) & 0x9d2c5680UL;\
  (y) ^= ((y) << 15) & 0xefc60000UL;\
  (y) ^= ((y) >> 18); }

#define rand_double(x,y) \
  (((double)((x)>>5)+(double)((y)>>6)*(1.0/67108864.0)) * (1.0/134217728.0))

#define rand_single(y) \
  ((double)(y) * (1.0/4294967296.0))

static int n_bits(int32_t a)
{
  int i, x, xu, xl, n=4;
  int32_t m;

  if (a==0) return 0;
  if (a<0) a=-a;

  x  = 1<<n;
  xu = 1<<(n+1);
  xl = 0;

  for (i=n; i>=0; --i) {
    m = ~((1<<(x-1))-1);

    if (m & a) {
      xl = x;
      x += 1<<(i-1);
    } else {
      xu = x;
      x -= 1<<(i-1);
    }
    /* printf("%3i, [%3i, %3i], %x\n", i, xu, xl, m1); */
  }
  /* if (xu-xl!=1) printf("*** erorr %d - %d != 1\n", xu, xl); */
  return xl;
}

static int32_t size_check(double rmax, double limit)
{
  if ( rmax == 0 ) {
    return (int32_t)(limit-1);
  }
  if ( rmax < 0 ) {
    rmax = -rmax;
  }
  rmax -= 1;
  if ( rmax >= limit ) {
    rb_raise(rb_eArgError, "rand-max(%.0f) must be <= %.0f", rmax+1, limit);
  }
  return (int32_t)rmax;
}

static void TpErr(void) {
    rb_raise(rb_eTypeError,"illegal operation with this type");
}

static void RndB(int n, char *p1, int i1, double rmax)
{
  u_int32_t y;
  u_int8_t max;
  int shift;

  if ( rmax < 0 ) {
    rb_raise(rb_eArgError, "rand-max must be positive");
  }
  max   = size_check(rmax,0x100);
  shift = 32 - n_bits(max);

  if (max<1) {
    for (; n; --n) {
      *(u_int8_t*)p1 = 0;
      p1+=i1;
    }
  } else {
    for (; n; --n) {
      do {
	genrand(y);
	y >>= shift;
      } while (y > max);
      *(u_int8_t*)p1 = (u_int8_t)y;
      p1+=i1;
    }
  }
}

static void RndI(int n, char *p1, int i1, double rmax)
{
  u_int32_t y;
  int16_t max;
  int shift, sign=1;

  if ( rmax < 0 ) { rmax = -rmax; sign = -1; }
  max   = size_check(rmax,0x8000);
  shift = 32 - n_bits(max);

  if (max<1) {
    for (; n; --n) {
      *(int16_t*)p1 = 0;
      p1+=i1;
    }
  } else {
    for (; n; --n) {
      do {
	genrand(y);
	y >>= shift;
      } while (y > max);
      *(int16_t*)p1 = (int16_t)y*sign;
      p1+=i1;
    }
  }
}

static void RndL(int n, char *p1, int i1, double rmax)
{
  u_int32_t y;
  int32_t max;
  int shift, sign=1;

  if ( rmax < 0 ) { rmax = -rmax; sign = -1; }
  max   = size_check(rmax,0x80000000);
  shift = 32 - n_bits(max);

  if (max<1) {
    for (; n; --n) {
      *(int32_t*)p1 = 0;
      p1+=i1;
    }
  } else {
    for (; n; --n) {
      do {
	genrand(y);
	y >>= shift;
      } while (y > max);
      *(int32_t*)p1 = (int32_t)y*sign;
      p1+=i1;
    }
  }
}

static void RndF(int n, char *p1, int i1, double rmax)
{
  u_int32_t y;

  for (; n; --n) {
    genrand(y);
    *(float*)p1 = rand_single(y) * rmax;
    p1+=i1;
  }
}

static void RndD(int n, char *p1, int i1, double rmax)
{
  u_int32_t x,y;

  for (; n; --n) {
    genrand(x);
    genrand(y);
    *(double*)p1 = rand_double(x,y) * rmax;
    p1+=i1;
  }
}

static void RndX(int n, char *p1, int i1, double rmax)
{
  u_int32_t y;

  for (; n; --n) {
    genrand(y);
    ((scomplex*)p1)->r = rand_single(y) * rmax;
    ((scomplex*)p1)->i = 0;
    p1+=i1;
  }
}

static void RndC(int n, char *p1, int i1, double rmax)
{
  u_int32_t x,y;

  for (; n; --n) {
    genrand(x);
    genrand(y);
    ((dcomplex*)p1)->r = rand_double(x,y) * rmax;
    ((dcomplex*)p1)->i = 0;
    p1+=i1;
  }
}

na_func_t RndFuncs =
  { TpErr, RndB, RndI, RndL, RndF, RndD, RndX, RndC, TpErr };


static VALUE
 na_random_bang(int argc, VALUE *argv, VALUE self)
{
  VALUE  vmax;
  struct NARRAY *ary;
  double rmax;

  rb_scan_args(argc, argv, "01", &vmax);
  if (first) {
    rand_init(random_seed());
  }
  if (NIL_P(vmax)) {
    rmax = 1;
  } else {
    rmax = NUM2DBL(vmax);
  }
  if (isinf(rmax) || isnan(rmax)) {
    rb_raise(rb_eArgError, "rand-max must be regular value");
  }

  GetNArray(self,ary);

#if 0
#ifdef __OPENCL__
  if (OPENCL_KERNEL(RndKernels[ary->type])) {
    cl_kernel kernel = RndKernels[ary->type]; 
    cl_int ret;
    size_t global_item_size[2] = {ary->total, (sizeof(state)/sizeof(state[0]))};
    cl_command_queue queue = ary->queue;
    cl_mem buf1 = ary->buffer;
    int s1 = na_sizeof[ary->type];
    int b1 = 0;
    u_int8_t rmaxB;
    int16_t rmaxI;
    int32_t rmaxL;
    float rmaxF;
 
    /* set OpenCL kernel arguments */
    ret = clSetKernelArg((void*)kernel, 0, sizeof(state), NULL);

    ret = clSetKernelArg((void*)kernel, 1, sizeof(cl_mem), (void *)&buf1);
    ret = clSetKernelArg((void*)kernel, 2, sizeof(cl_int), (void *)&s1);
    ret = clSetKernelArg((void*)kernel, 3, sizeof(cl_int), (void *)&b1);
    switch(ary->type){
      case NA_BYTE:     if ( rmax < 0 ) { rb_raise(rb_eArgError, "rand-max must be positive"); }
                        rmaxB = size_check(rmax,0x100);
                        ret = clSetKernelArg((void*)kernel, 4, sizeof(cl_uchar), (void *)&rmaxB); break;
      case NA_SINT:     if ( rmax < 0 ) { rmax = -rmax; }
                        rmaxI = size_check(rmax,0x8000);
                        ret = clSetKernelArg((void*)kernel, 4, sizeof(cl_short), (void *)&rmaxI); break;
      case NA_LINT:     if ( rmax < 0 ) { rmax = -rmax; }
                        rmaxL = size_check(rmax,0x80000000);
                        ret = clSetKernelArg((void*)kernel, 4, sizeof(cl_int),   (void *)&rmaxL); break;
      case NA_SFLOAT:   rmaxF = (float) rmax;
                        ret = clSetKernelArg((void*)kernel, 4, sizeof(cl_float), (void *)&rmaxF); break;
      case NA_SCOMPLEX: rmaxF = (float) rmax;
                        ret = clSetKernelArg((void*)kernel, 4, sizeof(cl_float), (void *)&rmaxF); break;
    }
    cl_mem state_buf = clCreateBuffer(context, CL_MEM_READ_WRITE|CL_MEM_USE_HOST_PTR, sizeof(state), state, NULL);
    ret = clSetKernelArg((void*)kernel, 5, sizeof(cl_mem), (void *)&state_buf);
    cl_mem left_buf = clCreateBuffer(context, CL_MEM_READ_WRITE|CL_MEM_USE_HOST_PTR, sizeof(left), &left, NULL);
    ret = clSetKernelArg((void*)kernel, 6, sizeof(cl_mem), (void *)&left_buf);
    cl_mem initf_buf = clCreateBuffer(context, CL_MEM_READ_WRITE|CL_MEM_USE_HOST_PTR, sizeof(initf), &initf, NULL);
    ret = clSetKernelArg((void*)kernel, 7, sizeof(cl_mem), (void *)&initf_buf);
    cl_mem next_buf = clCreateBuffer(context, CL_MEM_READ_WRITE|CL_MEM_USE_HOST_PTR, sizeof(next), next, NULL);
    ret = clSetKernelArg((void*)kernel, 8, sizeof(cl_mem), (void *)&next_buf);

    /* execute OpenCL kernel */
    ret = clEnqueueNDRangeKernel(queue, (void*)kernel, 1, NULL, global_item_size, NULL, 0, NULL, NULL);
    if (ret != CL_SUCCESS)
      rb_raise(rb_eRuntimeError, "Failed executing kernel \n");

    /* run commands in queue and make sure all commands in queue is done */
    clFlush(queue); clFinish(queue);
  }else {
#endif
#endif
  (*RndFuncs[ary->type])( ary->total, ary->ptr, na_sizeof[ary->type], rmax );
#if 0
#ifdef __OPENCL__
  }
#endif
#endif

  return self;
}

static VALUE
 na_random(int argc, VALUE *argv, VALUE self)
{
  return na_random_bang(argc, argv, na_clone(self));
}

void
Init_na_random()
{
    rb_define_singleton_method(cNArray,"srand",na_s_srand,-1);
    rb_define_method(cNArray, "random!", na_random_bang,-1);
    rb_define_method(cNArray, "random",  na_random,-1);
}
