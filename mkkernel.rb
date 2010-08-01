require "mknafunc"

$globals = []
$kernels = ["#define CREATE_OPENCL_KERNELS(program,ret) {"]

fname = "na_kernel.cl"
$> = open(fname,"w")

$opencl_types = 
 %w(none uchar short int float double scomplex dcomplex VALUE)
$realopencl_types = 
 %w(none uchar short int float double float double VALUE)
$intopencl_types = 
 %w(none uchar short int int int scomplex dcomplex VALUE)
$swapopencl_types = 
 %w(none uchar uchar2 uchar4 uchar4 uchar8 uchar8 uchar16 VALUE)

def mkopenclsetfuncs(name,op,id,funcs)

  print "
/* ------------------------- #{name} --------------------------- */\n"
  c  = $type_codes
  n  = $type_codes.size
  td = $data_types
  tr = $real_types
  tcl = $opencl_types

  # Function Definition

  for i in 0...n
    for j in 0...n
      funcs.each do |k|
	if c[i]=~k[0] && c[j]=~k[1]
          f = k[2]
	  f = f.
            gsub(/p0->/,"((#{tcl[i]}*)&p0[gid*i1])->").
            gsub(/p1->/,"((#{tcl[i]}*)&p1[gid*i1+b1[bid]])->").
            gsub(/p2->/,"((#{tcl[j]}*)&p2[gid*i2+b2[bid]])->").
            gsub(/\*p0/,"(*(#{tcl[i]}*)&p0[gid*i1])").
            gsub(/\*p1/,"(*(#{tcl[i]}*)&p1[gid*i1+b1[bid]])").
            gsub(/\*p2/,"(*(#{tcl[j]}*)&p2[gid*i2+b2[bid]])").
            gsub(/#id/,id).
            gsub(/#op/,op).
	    gsub(/typed/,td[i]).
            gsub(/typef/,tr[i])
	  puts $func_body.
	    gsub(/#name/,name).
            sub(/GLOBAL_ID/,'int gid = get_global_id(0);').
            sub(/BASE_ID/,'int bid = get_global_id(1);').
	    sub(/OPERATION/,f).
	    gsub(/#CC/,c[i]+c[j])
	end
      end
    end
  end

  # function pointer array
  narray_types = ["NA_NONE", "NA_BYTE", "NA_SINT", "NA_LINT", "NA_SFLOAT", "NA_DFLOAT", "NA_SCOMPLEX", "NA_DCOMPLEX", "NA_ROBJ", "NA_NTYPES"]
  #print "\nna_setfunc_t "+name+"Funcs = {\n"
  $globals << "na_opencl_kernel2_t #{name}Kernels;" 
  #m = []
  for i in 0...n
    #l = []
    for j in 0...n
      f = true
      for k in funcs
	if c[i]=~k[0] && c[j]=~k[1]
	  #l += [name+c[i]+c[j]]
          $kernels << "  #{name}Kernels[#{narray_types[i]}][#{narray_types[j]}] = clCreateKernel(program, \"#{name+c[i]+c[j]}\", &ret);"
	  f = false
	  break
	end
      end
      if f
        #l += ['TpErr']
        $kernels << "  #{name}Kernels[#{narray_types[i]}][#{narray_types[j]}] = NULL;"
      end
    end
    #m += ['  { '+l.join(', ')+' }']
  end
  #print m.join(",\n")+"\n};\n"
end

def mkopenclfuncs(name,t1,t2,func)

  print "
/* ------------------------- #{name} --------------------------- */\n"
  c   = $type_codes
  td  = $data_types
  tr  = $real_types
  tcl = $opencl_types
  trcl= $realopencl_types

  for i in 0...c.size
    if func[i] != nil && func[i] != "set" && func[i] != "swp"
      f = func[i].
	gsub(/p0->/,"((#{t1[i]}*)&p0[gid*i1])->").
	gsub(/p1->/,"((#{t1[i]}*)&p1[gid*i1+b1[bid]])->").
	gsub(/p2->/,"((#{t2[i]}*)&p2[gid*i2+b2[bid]])->").
	gsub(/p3->/,"((#{t2[i]}*)&p3[gid*i3+b3[bid]])->").
	gsub(/\*p0/,"(*(#{t1[i]}*)&p0[gid*i1])").
	gsub(/\*p1/,"(*(#{t1[i]}*)&p1[gid*i1+b1[bid]])").
	gsub(/\*p2/,"(*(#{t2[i]}*)&p2[gid*i2+b2[bid]])").
	gsub(/\*p3/,"(*(#{t2[i]}*)&p3[gid*i3+b3[bid]])").
	gsub(/type1/,td[i]).
	gsub(/typecl/,tcl[i]).
	gsub(/typef/,tr[i]).
	gsub(/typercl/,trcl[i])
      puts $func_body.
	gsub(/#name/,name).
	sub(/GLOBAL_ID/,'int gid = get_global_id(0);').
	sub(/BASE_ID/,'int bid = get_global_id(1);').
	sub(/OPERATION/,f).
	gsub(/#C/,c[i]).
	gsub(/typecl/,tcl[i]).
	gsub(/typercl/,trcl[i])
    end
  end
  # Function Array
  narray_types = ["NA_NONE", "NA_BYTE", "NA_SINT", "NA_LINT", "NA_SFLOAT", "NA_DFLOAT", "NA_SCOMPLEX", "NA_DCOMPLEX", "NA_ROBJ", "NA_NTYPES"]
  #print "\ncl_kernel #{name}Funcs =\n{ "
  $globals << "na_opencl_kernel1_t #{name}Kernels;" 
  #m = []
  for i in 0...c.size
    if func[i] == nil
  #    m += ['TpErr']
      $kernels << "  #{name}Kernels[#{narray_types[i]}] = NULL;"
    elsif func[i]=='swp'
      $kernels << "  #{name}Kernels[#{narray_types[i]}] = SwpKernels[#{narray_types[i]}];"
    elsif func[i]=='set'
  #    m += ['Set'+c[$data_types.index(t1[i])]+c[i]]
      $kernels << "  #{name}Kernels[#{narray_types[i]}] = SetKernels[#{narray_types[i]}][#{narray_types[i]}];"
    else
  #    m += [name+c[i]]
      $kernels << "  #{name}Kernels[#{narray_types[i]}] = clCreateKernel(program, \"#{name+c[i]}\", &ret);"
    end
  end
  #print m.join(", ")+" };\n"
end


print <<EOM
/*
  #{fname}
  Automatically generated code
  Numerical Array Extention on OpenCL for Ruby
    (C) Copyright 2010 by Kazuyuki TANIMURA

  This program is free software.
  You can distribute/modify this program
  under the same terms as Ruby itself.
  NO WARRANTY.
*/
#pragma OPENCL EXTENSION cl_khr_byte_addressable_store : enable
//#pragma OPENCL EXTENSION cl_khr_fp64 : enable
//#include <ruby.h>
//#include "narray.h"
//#include "narray_local.h"
///* isalpha(3) etc. */
//#include <ctype.h>
typedef struct { float r,i; }  scomplex;
//typedef struct { double r,i; } dcomplex;

#ifndef M_LOG2E
#define M_LOG2E         1.4426950408889634074
#endif
#ifndef M_LOG10E
#define M_LOG10E        0.43429448190325182765
#endif
/*

static void TpErr(void) {
    rb_raise(rb_eTypeError,"illegal operation with this type");
}
static int TpErrI(void) {
    rb_raise(rb_eTypeError,"illegal operation with this type");
    return 0;
}
static void na_zerodiv() {
    rb_raise(rb_eZeroDivError, "divided by 0");
}
*/
EOM


#
#  Set Fucs
#
data = [
  #[/[O]/,/[O]/,        "*p1 = *p2;"],
  #[/[O]/,/[BI]/,       "*p1 = INT2FIX(*p2);"],
  #[/[O]/,/[L]/,        "*p1 = INT2NUM(*p2);"],
  #[/[O]/,/[FD]/,       "*p1 = rb_float_new(*p2);"],
  #[/[O]/,/[XC]/,       "*p1 = rb_complex_new(p2->r,p2->i);"],
  #[/[BIL]/,/[O]/,      "*p1 = NUM2INT(*p2);"],
  #[/[FD]/,/[O]/,       "*p1 = NUM2DBL(*p2);"],
  #[/[XC]/,/[O]/,       "p1->r = NUM2REAL(*p2); p1->i = NUM2IMAG(*p2);"],
  #[/[BILFD]/,/[BILFD]/,"*p1 = *p2;"],
  [/[BILF]/,/[BILF]/,"*p1 = *p2;"],
  #[/[BILFD]/,/[XC]/,   "*p1 = p2->r;"],
  [/[BILF]/,/[X]/,   "*p1 = p2->r;"],
  #[/[XC]/,/[BILFD]/,   "p1->r = *p2; p1->i = 0;"],
  [/[X]/,/[BILF]/,   "p1->r = *p2; p1->i = 0;"],
  #[/[XC]/,/[XC]/,      "p1->r = p2->r; p1->i = p2->i;"]
  [/[X]/,/[X]/,      "p1->r = p2->r; p1->i = p2->i;"]
]
$func_body = 
  "__kernel void #name#CC(__local char* p0, __global char* p1, int i1, __global long* b1, __global char* p2, int i2, __global long* b2)
{
  GLOBAL_ID
  BASE_ID
  OPERATION
}
"
mkopenclsetfuncs('Set','','',data)



#
#  Unary Funcs
#
$func_body = 
  "__kernel void #name#C(__local char* p0, __global char* p1, int i1, __global long* b1, __global char* p2, int i2, __global long* b2)
{
  GLOBAL_ID
  BASE_ID
  OPERATION
}
"

mkopenclfuncs('Swp', $swapopencl_types, $swapopencl_types,
 [nil] +
 ["*p1 = *p2;"] + 
 ["*p1 = *p2.s10;"] + 
 ["*p1 = *p2.s3210;"]*2 + 
 ["*p1 = *p2.s76543210;"] + 
 ["*p1 = *p2.s32107654;"] + 
 ["*p1 = *p2.s76543210fedcba98;"] + 
 [nil]
)

$kernels << "  cl_bool little_endian;"
$kernels << "  clGetDeviceInfo(device_id, CL_DEVICE_ENDIAN_LITTLE, sizeof(little_endian), &little_endian, NULL);"
$kernels << "  if (little_endian) { /* LITTLE ENDIAN */"

mkopenclfuncs('H2N', [], [],
 [nil] +
 ['set'] + 
 ['swp']*6 + 
 [nil]
)

mkopenclfuncs('H2V', [], [],
 [nil] +
 ['set']*7 + 
 [nil]
)

$kernels << "  }else if (CL_FALSE) { /* DYNAMIC ENDIAN not supported yet */"
$kernels << "  }else { /* BIG ENDIAN */"

mkopenclfuncs('H2N', [], [],
 [nil] +
 ['set']*7 + 
 [nil]
)

mkopenclfuncs('H2V', [], [],
 [nil] +
 ['set'] + 
 ['swp']*6 + 
 [nil]
)

$kernels << "  }"

mkopenclfuncs('Neg', $opencl_types, $opencl_types,
 [nil] +
 ["*p1 = -*p2;"]*4 + 
 [nil] +
 ["p1->r = -p2->r;
  p1->i = -p2->i;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('AddU', $opencl_types, $opencl_types,
 [nil] +
 ["*p0 = *p1 + *p2;
//barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"]*4 + 
 [nil] +
 ["p0->r = p1->r + p2->r;
  p0->i = p1->i + p2->i;
//barrier(CLK_LOCAL_MEM_FENCE);
  p1->r = p0->r;
  p1->i = p0->i;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('SbtU', $opencl_types, $opencl_types,
 [nil] +
 ["*p0 = *p1 - *p2;
//barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"]*4 + 
 [nil] +
 ["p0->r = p1->r - p2->r;
  p0->i = p1->i - p2->i;
//barrier(CLK_LOCAL_MEM_FENCE);
  p1->r = p0->r;
  p1->i = p0->i;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('MulU', $opencl_types, $opencl_types,
 [nil] +
 ["*p0 = *p1 * *p2;
//barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"]*4 + 
 [nil] +
 ["typecl x = *p1;
  typecl y = *p2;
  p0->r = x.r*y.r - x.i*y.i;
  p0->i = x.r*y.i + x.i*y.r;
//barrier(CLK_LOCAL_MEM_FENCE);
  p1->r = p0->r;
  p1->i = p0->i;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('DivU', $opencl_types, $opencl_types,
 [nil] +
 #["if (*p2==0) {na_zerodiv();}
 #   *p1 /= *p2;"]*3 + 
 #["*p1 /= *p2;"]*2 + 
 ["*p0 = *p1 / *p2;
//barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"]*4 + 
 [nil] +
 ["typecl x = *p1;
  typecl y = *p2;
  typercl a = y.r*y.r + y.i*y.i;
  p0->r = (x.r*y.r + x.i*y.i)/a;
  p0->i = (x.i*y.r - x.r*y.i)/a;
//barrier(CLK_LOCAL_MEM_FENCE);
  p1->r = p0->r;
  p1->i = p0->i;"] +
 [nil] +
 [nil]
)


# method: imag=
mkopenclfuncs('ImgSet',$opencl_types,$realopencl_types,
 [nil]*6 +
 ["p1->i = *p2;"] +
 [nil]*2
)


mkopenclfuncs('Floor',$intopencl_types,$opencl_types,
 [nil] +
 ['set']*3 + 
 ["*p1 = floor*p2;"] + 
 [nil]*4
)

mkopenclfuncs('Ceil',$intopencl_types,$opencl_types,
 [nil] +
 ['set']*3 + 
 ["*p1 = ceil*p2;"] + 
 [nil]*4
)

mkopenclfuncs('Round',$intopencl_types,$opencl_types,
 [nil] +
 ['set']*3 + 
 ["*p1 = round*p2;"] + 
 [nil]*4
)

mkopenclfuncs('Abs',$realopencl_types,$opencl_types,
 [nil] +
 ["*p1 = abs(*p2);"]*3 + 
 ["*p1 = fabs(*p2);"] + 
 [nil] +
 ["*p1 = hypot(p2->r, p2->i);"] +
 [nil]*2
)


mkopenclfuncs('Real',$realopencl_types,$opencl_types,
 [nil] +
 ['set']*4 + 
 [nil] +
 ['set'] + 
 [nil] +
 [nil]
)

mkopenclfuncs('Imag',$realopencl_types,$opencl_types,
 [nil] +
 ["*p1 = 0;"]*4 + 
 [nil] +
 ["*p1 = p2->i;"] +
 [nil]*2
)

mkopenclfuncs('Angl',$realopencl_types,$opencl_types,
 [nil] +
 [nil]*4 +
 [nil] +
 ["*p1 = atan2(p2->i,p2->r);"] +
 [nil]*2
)

mkopenclfuncs('ImagMul',$comp_types,$opencl_types,
 [nil] +
 [nil]*3 +
 ["p1->r = 0; p1->i = *p2;"] + 
 [nil] +
 ["p1->r = -p2->i; p1->i = p2->r;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('Conj',$opencl_types,$opencl_types,
 [nil] +
 ['set']*4 + 
 [nil] +
 ["p1->r = p2->r; p1->i = -p2->i;"] +
 [nil]*2
)

mkopenclfuncs('Not', [$opencl_types[1]]*9, $opencl_types,
 [nil] +
 ["*p1 = (*p2==0) ? 1:0;"]*4 +
 [nil] +
 ["*p1 = (p2->r==0 && p2->i==0) ? 1:0;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('BRv', $opencl_types, $opencl_types,
 [nil] +
 ["*p1 = ~(*p2);"]*3 +
 [nil]*5
)

mkopenclfuncs('Min', $opencl_types, $opencl_types,
 [nil] +
 ["if (*p1>*p2) *p1=*p2;"]*3 +
 ["if ((!isnan*p2) && (*p1>*p2)) *p1=*p2;"] +
 [nil]*4
)

mkopenclfuncs('Max', $opencl_types, $opencl_types,
 [nil] +
 ["if (*p1<*p2) *p1=*p2;"]*3 +
 ["if ((!isnan*p2) && (*p1<*p2)) *p1=*p2;"] +
 [nil]*4
)

#
#  Recip
#
mkopenclfuncs('Rcp', $opencl_types, $opencl_types,
 [nil] +
 ["*p1 = 1/*p2;"]*4 + 
 [nil] +
 ["typecl z = *p2;
  typercl x, y;
  if ( (z.r<0 ? -z.r:z.r) > (z.i<0 ? -z.i:z.i) ) {
    x = z.i/z.r;
    y = (1+x*x)*z.r;
    p1->r =  1/y;
    p1->i = -x/y;
  } else {
    x = z.r/z.i;
    y = (1+x*x)*z.i;
    p1->r =  x/y;
    p1->i = -1/y;
  }"] +
 [nil]*2
)

#
# NMath Operations
#
mkopenclfuncs('sqrt', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = sqrt*p2;"] +
 [nil] +
["typercl xr=p2->r/2, xi=p2->i/2, r=hypot(xr,xi);
  if (xr>0) {
    p1->r = sqrt(r+xr);
    p1->i = xi/p1->r;
  } else if ( (r-=xr) ) {
    p1->i = (xi>=0) ? sqrt(r):-sqrt(r);
    p1->r = xi/p1->i;
  } else {
    p1->r = p1->i = 0;
  }"] +
 [nil]*2
)

mkopenclfuncs('sin', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = sin*p2;"] +
 [nil] +
["p1->r = sin(p2->r)*cosh(p2->i);
  p1->i = cos(p2->r)*sinh(p2->i);"] +
 [nil]*2
)

mkopenclfuncs('cos', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = cos*p2;"] +
 [nil] +
["p1->r = cos(p2->r)*cosh(p2->i);
  p1->i = -sin(p2->r)*sinh(p2->i);"] +
 [nil]*2
)

mkopenclfuncs('tan', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = tan*p2;"] +
 [nil] +
["typercl d, th, k;
  th = tanh(2 * p2->i);
  k = sqrt(1 - th * th); /* sech */
  d  = 1 + cos(2 * p2->r) * k;
  p1->r = k * sin(2 * p2->r) / d;
  p1->i = th / d;"] +
 [nil]*2
)

mkopenclfuncs('sinh', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = sinh*p2;"] +
 [nil] +
["p1->r = sinh(p2->r)*cos(p2->i);
  p1->i = cosh(p2->r)*sin(p2->i);"] +
 [nil]*2
)

mkopenclfuncs('cosh', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = cosh*p2;"] +
 [nil] +
["p1->r = cosh(p2->r)*cos(p2->i);
  p1->i = sinh(p2->r)*sin(p2->i);"] +
 [nil]*2
)

mkopenclfuncs('tanh', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = tanh*p2;"] +
 [nil] +
["typercl d, th, k;
  th = tanh(2 * p2->r);
  k = sqrt(1 - th * th); /* sech */
  d  = 1 + cos(2 * p2->i) * k;
  p1->i = k * sin(2 * p2->i) / d;
  p1->r = th / d;"] +
 [nil]*2
)

mkopenclfuncs('exp', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = exp*p2;"] +
 [nil] +
["typercl a = exp(p2->r);
  p1->r = a*cos(p2->i);
  p1->i = a*sin(p2->i);"] +
 [nil]*2
)

mkopenclfuncs('log', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = log*p2;"] +
 [nil] +
["typecl x = *p2;
  p1->r = log(hypot(x.r, x.i));
  p1->i = atan2(x.i, x.r);"] +
 [nil]*2
)

mkopenclfuncs('log10', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = log10*p2;"] +
 [nil] +
["typecl x = *p2;
  p1->r = log(hypot(x.r, x.i)) * M_LOG10E;
  p1->i = atan2(x.i, x.r) * M_LOG10E;"] +
 [nil]*2
)

mkopenclfuncs('log2', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = log2*p2;"] +
 [nil] +
["typecl x = *p2;
  p1->r = log(hypot(x.r, x.i)) * M_LOG2E;
  p1->i = atan2(x.i, x.r) * M_LOG2E;"] +
 [nil]*2
)

mkopenclfuncs('asin', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = asin*p2;"] +
 [nil] +
["typecl x = *p2;
  typecl y;
  typercl r=x.r;
  typercl xr = (1 - (r*r - x.i*x.i))/2;
  typercl xi = -r*x.i;
  r=hypot(xr,xi);
  if (xr>0) {
    y.r = sqrt(r+xr) - x.i;
    y.i = xi/y.r + x.r;
  } else if ( (r-=xr) ) {
    y.i = ((xi>=0) ? sqrt(r):-sqrt(r)) + x.r;
    y.r = xi/y.i - x.i;
  } else {
    y.r = - x.i;
    y.i = x.r;
  }
  p1->r = atan2(y.i, y.r);
  p1->i = - log(hypot(y.r, y.i));"] +
 [nil]*2
)

mkopenclfuncs('asinh', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = asinh*p2;"] +
 [nil] +
["typecl x = *p2;
  typecl y;
  typercl r=x.r;
  typercl xr = ((r*r - x.i*x.i) + 1)/2;
  typercl xi = r*x.i;
  r=hypot(xr,xi);
  if (xr>0) {
    y.r = sqrt(r+xr) + x.r;
    y.i = xi/y.r + x.i;
  } else if ( (r-=xr) ) {
    y.i = ((xi>=0) ? sqrt(r):-sqrt(r)) + x.i;
    y.r = xi/y.i + x.r;
  } else {
    y.r = x.r;
    y.i = x.i;
  }
  p1->r = log(hypot(y.r, y.i));
  p1->i = atan2(y.i, y.r);"] +
 [nil]*2
)

mkopenclfuncs('acos', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = acos*p2;"] +
 [nil] +
["typecl x = *p2;
  typecl y;
  typercl r=x.r;
  typercl xr = (1 - (r*r - x.i*x.i))/2;
  typercl xi = -r*x.i;
  r=hypot(xr,xi);
  if (xr>0) {
    y.r = -(xi/y.r) + x.r;
    y.i = sqrt(r+xr) + x.i;
  } else if ( (r-=xr) ) {
    y.i = xi/y.i + x.i;
    y.r = ((xi>=0) ? -sqrt(r):sqrt(r)) + x.r;
  } else {
    y.r = x.r;
    y.i = x.i;
  }
  p1->r = atan2(y.i, y.r);
  p1->i = - log(hypot(y.r, y.i));"] +
 [nil]*2
)

mkopenclfuncs('acosh', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = acosh*p2;"] +
 [nil] +
["typecl x = *p2;
  typecl y;
  typercl r=x.r;
  typercl xr = ((r*r - x.i*x.i) - 1)/2;
  typercl xi = r*x.i;
  r=hypot(xr,xi);
  if (xr>0) {
    y.r = sqrt(r+xr) + x.r;
    y.i = xi/y.r + x.i;
  } else if ( (r-=xr) ) {
    y.i = ((xi>=0) ? sqrt(r):-sqrt(r)) + x.i;
    y.r = xi/y.i + x.r;
  } else {
    y.r = x.r;
    y.i = x.i;
  }
  p1->r = log(hypot(y.r, y.i));
  p1->i = atan2(y.i, y.r);"] +
 [nil]*2
)

mkopenclfuncs('atan', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = atan*p2;"] +
 [nil] +
["typecl x,y,z;
  x.r=-p2->r; x.i=1-p2->i;
  y.r= p2->r; y.i=1+p2->i;
  typercl a = x.r*x.r + x.i*x.i;
  z.r = (y.r*x.r + y.i*x.i)/a;
  z.i = (y.i*x.r - y.r*x.i)/a;
  p1->r = - atan2(z.i, z.r)/2;
  p1->i = log(hypot(z.r, z.i))/2;"] +
 [nil]*2
)

mkopenclfuncs('atanh', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = atanh*p2;"] +
 [nil] +
["typecl x,y,z;
  x.r=1-p2->r; x.i=-p2->i;
  y.r=1+p2->r; y.i= p2->i;
  typercl a = x.r*x.r + x.i*x.i;
  z.r = (y.r*x.r + y.i*x.i)/a;
  z.i = (y.i*x.r - y.r*x.i)/a;
  p1->r = log(hypot(z.r, z.i))/2;
  p1->i = atan2(z.i, z.r)/2;"] +
 [nil]*2
)

#mksortfuncs('Sort', $opencl_types, $opencl_types,
# [nil] +
# ["
#{ if (*p1 > *p2) return 1;
#  if (*p1 < *p2) return -1;
#  return 0; }"]*5 +
# [nil]*3
#)
#
#mksortfuncs('SortIdx', $opencl_types, $opencl_types,
# [nil] +
# ["
#{ if (**p1 > **p2) return 1;
#  if (**p1 < **p2) return -1;
#  return 0; }"]*5 +
# [nil]*3
#)

# indgen
$func_body = 
  "__kernel void #name#C(__global char* p1, int i1, int p2, int i2)
{
  int gid = get_global_id(0);
  OPERATION
}
"
mkopenclfuncs('IndGen',$opencl_types,[$opencl_types[3]]*8,
 [nil] +
 ["(*(typecl*)&p1[gid*i1]) = p2+gid*i2;"]*4 +
 [nil] +
 ["((typecl*)&p1[gid*i1])->r = p2+gid*i2;
  ((typecl*)&p1[gid*i1])->i = 0;"] +
 [nil] +
 [nil]
)

#$func_body = 
#"static void #name#C(int n, char *p1, int i1, char *p2, int i2)
#{
#  OPERATION
#}
#"
#mkfuncs('ToStr',['']+[$data_types[8]]*8,$data_types,
# [nil] +
# ["char buf[22];
#  for (; n; --n) {
#    sprintf(buf,\"%i\",(int)*p2);
#    *p1 = rb_str_new2(buf);
#    p1+=i1; p2+=i2;
#  }"]*3 +
# ["char buf[24];
#  for (; n; --n) {
#    sprintf(buf,\"%.5g\",(double)*p2);
#    *p1 = rb_str_new2(buf);
#    p1+=i1; p2+=i2;
#  }"] +
# ["char buf[24];
#  for (; n; --n) {
#    sprintf(buf,\"%.8g\",(double)*p2);
#    *p1 = rb_str_new2(buf);
#    p1+=i1; p2+=i2;
#  }"] +
# ["char buf[50];
#  for (; n; --n) {
#    sprintf(buf,\"%.5g%+.5gi\",(double)p2->r,(double)p2->i);
#    *p1 = rb_str_new2(buf);
#    p1+=i1; p2+=i2;
#  }"] +
# ["char buf[50];
#  for (; n; --n) {
#    sprintf(buf,\"%.8g%+.8gi\",(double)p2->r,(double)p2->i);
#    *p1 = rb_str_new2(buf);
#    p1+=i1; p2+=i2;
#  }"] +
# ["for (; n; --n) {
#    *p1 = rb_obj_as_string(*p2);
#    p1+=i1; p2+=i2;
#  }"]
#)
#
#
#print <<EOM
#
#/* from numeric.c */
#static void na_str_append_fp(char *buf)
#{
#  if (buf[0]=='-' || buf[0]=='+') ++buf;
#  if (ISALPHA(buf[0])) return; /* NaN or Inf */
#  if (strchr(buf, '.') == 0) {
#      int   len = strlen(buf);
#      char *ind = strchr(buf, 'e');
#      if (ind) {
#          memmove(ind+2, ind, len-(ind-buf)+1);
#          ind[0] = '.';
#	  ind[1] = '0';
#      } else {
#          strcat(buf, ".0");
#      }
#  }
#}
#EOM
#
#$func_body = 
#"static void #name#C(char *p1, char *p2)
#{
#  OPERATION
#}
#"
#mkfuncs('Insp',['']+[$data_types[8]]*8,$data_types,
# [nil] +
# ["char buf[22];
#  sprintf(buf,\"%i\",(int)*p2);
#  *p1 = rb_str_new2(buf);"]*3 +
# ["char buf[24];
#  sprintf(buf,\"%g\",(double)*p2);
#  na_str_append_fp(buf);
#  *p1 = rb_str_new2(buf);"] +
# ["char buf[24];
#  sprintf(buf,\"%g\",(double)*p2);
#  na_str_append_fp(buf);
#  *p1 = rb_str_new2(buf);"] +
# ["char buf[50], *b;
#  sprintf(buf,\"%g\",(double)p2->r);
#  na_str_append_fp(buf);
#  b = buf+strlen(buf);
#  sprintf(b,\"%+g\",(double)p2->i);
#  na_str_append_fp(b);
#  strcat(buf,\"i\");
#  *p1 = rb_str_new2(buf);"] +
# ["char buf[50], *b;
#  sprintf(buf,\"%g\",(double)p2->r);
#  na_str_append_fp(buf);
#  b = buf+strlen(buf);
#  sprintf(b,\"%+g\",(double)p2->i);
#  na_str_append_fp(b);
#  strcat(buf,\"i\");
#  *p1 = rb_str_new2(buf);"] +
# ["*p1 = rb_inspect(*p2);"]
#)
#
#

#
#   Binary Funcs
#
$func_body = 
  "__kernel void #name#C(__local char* p0, __global char* p1, int i1, __global long* b1, __global char* p2, int i2, __global long* b2, __global char* p3, int i3, __global long* b3)
{
  GLOBAL_ID
  BASE_ID
  OPERATION
}
"

mkopenclfuncs('AddB', $opencl_types, $opencl_types,
 [nil] +
 ["*p1 = *p2 + *p3;"]*4 + 
 [nil] +
 ["p1->r = p2->r + p3->r;
  p1->i = p2->i + p3->i;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('SbtB', $opencl_types, $opencl_types,
 [nil] +
 ["*p1 = *p2 - *p3;"]*4 + 
 [nil] +
 ["p1->r = p2->r - p3->r;
  p1->i = p2->i - p3->i;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('MulB', $opencl_types, $opencl_types,
 [nil] +
 ["*p1 = *p2 * *p3;"]*4 + 
 [nil] +
 #["typecl x = *p2;
 # p1->r = x.r*p3->r - x.i*p3->i;
 # p1->i = x.r*p3->i + x.i*p3->r;"]*2 +
 ["typecl x = *p2;
  typecl y = *p3;
  p1->r = x.r*y.r - x.i*y.i;
  p1->i = x.r*y.i + x.i*y.r;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('DivB', $opencl_types, $opencl_types,
 [nil] +
 #["if (*p3==0) {na_zerodiv();};
 #   *p1 = *p2 / *p3;"]*3 +
 #["*p1 = *p2 / *p3;"]*2 +
 ["*p1 = *p2 / *p3;"]*4 +
 [nil] +
 #["typecl x = *p2;
 # typef a = p3->r*p3->r + p3->i*p3->i;
 # p1->r = (x.r*p3->r + x.i*p3->i)/a;
 # p1->i = (x.i*p3->r - x.r*p3->i)/a;"]*2 +
 ["typecl x = *p2;
  typecl y = *p3;
  typercl a = y.r*y.r + y.i*y.i;
  p1->r = (x.r*y.r + x.i*y.i)/a;
  p1->i = (x.i*y.r - x.r*y.i)/a;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('ModB', $opencl_types, $opencl_types,
 [nil] +
 ["*p1 = *p2 % *p3;"]*3 + 
 ["*p1 = fmod(*p2, *p3);"] + 
 [nil] +
 [nil]*3
)

mkopenclfuncs('MulAdd', $opencl_types, $opencl_types,
 [nil] +
 ["*p0 = *p1 + *p2 * *p3;
//barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"]*3 + 
 ["*p0 = fma(*p2, *p3, *p1);
//barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"] + 
 [nil] +
 #["typecl x = *p2;
 # p0->r = p1->r + x.r*p3->r - x.i*p3->i;
 # p0->i = p1->i + x.r*p3->i + x.i*p3->r;"]*2 +
 ["typecl x = *p2;
  typecl y = *p3;
  p0->r = fma(-(x.i), y.i, fma(x.r, y.r, p1->r));
  p0->i = fma(  x.i,  y.r, fma(x.r, y.i, p1->i));
//barrier(CLK_LOCAL_MEM_FENCE);
  p1->r = p0->r;
  p1->i = p0->i;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('MulSbt', $opencl_types, $opencl_types,
 [nil] +
 ["*p0 = *p1 - *p2 * *p3;
//barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"]*3 + 
 ["*p0 = fma(-*p2, *p3, *p1);
//barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"] + 
 [nil] +
 #["typecl x = *p2;
 # p0->r = p1->r - x.r*p3->r - x.i*p3->i;
 # p0->i = p1->i - x.r*p3->i + x.i*p3->r;"]*2 +
 ["typecl x = *p2;
  typecl y = *p3;
  p0->r = fma(-(x.i), y.i, fma(-(x.r), y.r, p1->r));
  p0->i = fma(  x.i,  y.r, fma(-(x.r), y.i, p1->i));
//barrier(CLK_LOCAL_MEM_FENCE);
  p1->r = p0->r;
  p1->i = p0->i;"] +
 [nil] +
 [nil]
)


#
#   Bit operator
#

mkopenclfuncs('BAn', $opencl_types, $opencl_types,
 [nil] +
 ["*p1 = *p2 & *p3;"]*3 + 
 [nil]*5
)

mkopenclfuncs('BOr', $opencl_types, $opencl_types,
 [nil] +
 ["*p1 = *p2 | *p3;"]*3 + 
 [nil]*5
)

mkopenclfuncs('BXo', $opencl_types, $opencl_types,
 [nil] +
 ["*p1 = *p2 ^ *p3;"]*3 + 
 [nil]*5
)


#
#   Comparison
#

mkopenclfuncs('Eql', [$opencl_types[1]]*9, $opencl_types,
 [nil] +
 ["*p1 = (*p2==*p3) ? 1:0;"]*4 +
 [nil] +
 ["*p1 = (p2->r==p3->r) && (p2->i==p3->i) ? 1:0;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('Cmp', [$opencl_types[1]]*9, $opencl_types,
 [nil] +
 ["if (*p2>*p3) *p1=1;
    else if (*p2<*p3) *p1=2;
    else *p1=0;"]*4 +
 [nil]*4
)

mkopenclfuncs('And', [$opencl_types[1]]*9, $opencl_types,
 [nil] +
 ["*p1 = (*p2!=0 && *p3!=0) ? 1:0;"]*4 +
 [nil] +
 ["*p1 = ((p2->r!=0||p2->i!=0) && (p3->r!=0||p3->i!=0)) ? 1:0;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('Or_', [$opencl_types[1]]*9, $opencl_types,
 [nil] +
 ["*p1 = (*p2!=0 || *p3!=0) ? 1:0;"]*4 +
 [nil] +
 ["*p1 = ((p2->r!=0||p2->i!=0) || (p3->r!=0||p3->i!=0)) ? 1:0;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('Xor', [$opencl_types[1]]*9, $opencl_types,
 [nil] +
 ["*p1 = ((*p2!=0) == (*p3!=0)) ? 0:1;"]*4 +
 [nil] +
 ["*p1 = ((p2->r!=0||p2->i!=0) == (p3->r!=0||p3->i!=0)) ? 0:1;"] +
 [nil] +
 [nil]
)

#
#   Atan2
#
mkopenclfuncs('atan2', $opencl_types, $opencl_types,
 [nil]*4 +
 ["*p1 = atan2(*p2, *p3);"] +
 [nil]*4
)

#
#   Mask
#
#mkopenclfuncs('RefMask',$opencl_types,$opencl_types,
# [nil] +
# ["if (*(uchar*)p3) { *p1=*p2; p1+=i1; } p3+=i3; p2+=i2;"]*4 +
# [nil] +
# ["if (*(uchar*)p3) { *p1=*p2; p1+=i1; } p3+=i3; p2+=i2;"] +
# [nil]*2
#)
#
#mkfopencluncs('SetMask',$opencl_types,$opencl_types,
# [nil] +
# ["if (*(uchar*)p3) { *p1=*p2; p2+=i2; } p3+=i3; p1+=i1;"]*4 +
# [nil] +
# ["if (*(uchar*)p3) { *p1=*p2; p2+=i2; } p3+=i3; p1+=i1;"] +
# [nil]*2
#)

#
#   Power
#
def mkopenclpowfuncs(name,funcs)

  print "
/* ------------------------- #{name} --------------------------- */\n"
  c  = $type_codes
  n  = $type_codes.size
  td = $data_types
  tr = $real_types
  tcl = $opencl_types
  trcl= $realopencl_types

  # Function Definition

  for i in 0...n
    for j in 0...n
      funcs.each do |k|
	if c[i]=~k[0] && c[j]=~k[1]
          tu = tcl[$upcast[i][j]]
          f = k[2]
	  f = f.
            gsub(/p0->/,"((#{tcl[i]}*)&p0[gid*i1])->").
            gsub(/p1->/,"((#{tu}*)&p1[gid*i1+b1[bid]])->").
            gsub(/p2->/,"((#{tcl[i]}*)&p2[gid*i2+b2[bid]])->").
            gsub(/p3->/,"((#{tcl[j]}*)&p3[gid*i3+b3[bid]])->").
            gsub(/\*p0/,"(*(#{tcl[i]}*)&p0[gid*i1])").
            gsub(/\*p1/,"(*(#{tu}*)&p1[gid*i1+b1[bid]])").
            gsub(/\*p2/,"(*(#{tcl[i]}*)&p2[gid*i2+b2[bid]])").
            gsub(/\*p3/,"(*(#{tcl[j]}*)&p3[gid*i3+b3[bid]])").
            gsub(/typecl1/,tu).
            gsub(/typecl2/,tcl[i]).
            gsub(/typecl3/,tcl[j]).
            gsub(/typercl2/,trcl[i])
	  puts $func_body.
	    gsub(/#name/,name).
            sub(/GLOBAL_ID/,'int gid = get_global_id(0);').
            sub(/BASE_ID/,'int bid = get_global_id(1);').
	    sub(/OPERATION/,f).
	    gsub(/#CC/,c[i]+c[j])
	end
      end
    end
  end

  # function pointer array
  narray_types = ["NA_NONE", "NA_BYTE", "NA_SINT", "NA_LINT", "NA_SFLOAT", "NA_DFLOAT", "NA_SCOMPLEX", "NA_DCOMPLEX", "NA_ROBJ", "NA_NTYPES"]
  $globals << "na_opencl_kernel2_t #{name}Kernels;" 
  for i in 0...n
    for j in 0...n
      f = true
      for k in funcs
	if c[i]=~k[0] && c[j]=~k[1]
          $kernels << "  #{name}Kernels[#{narray_types[i]}][#{narray_types[j]}] = clCreateKernel(program, \"#{name+c[i]+c[j]}\", &ret);"
	  f = false
	  break
	end
      end
      if f
        $kernels << "  #{name}Kernels[#{narray_types[i]}][#{narray_types[j]}] = NULL;"
      end
    end
  end
end

$func_body = 
  "__kernel void #name#CC(__local char* p0, __global char* p1, int i1, __global long* b1, __global char* p2, int i2, __global long* b2, __global char* p3, int i3, __global long* b3)
{
  GLOBAL_ID
  BASE_ID
  OPERATION
}

"
mkopenclpowfuncs('Pow', [
 [/[BILF]/,/[BIL]/, "typecl1 z=1;
  *p0 = *p2;
  typecl3 y = abs(*p3);
  typecl3 i = 0;
  while (y>>i) {
    if ( ((y>>i++)&1) == 1 ) z *= *p0;
    *p0 *= *p0;
  }
  if (*p3<0) {
    *p1 = 1/z;
  }else {
    *p1 = z;
  }"],
 [/[BILF]/,/[F]/,"*p1 = pow(*p2,*p3);"],
 [/[X]/,/[BIL]/,  "typecl1 z={1,0};
  *p0 = *p2;
  typecl3 y = abs(*p3);
  typecl3 i = 0;
  while (y>>i) {
    if ( ((y>>i++)&1) == 1 ) {
      z.r = z.r * p0->r - z.i * p0->i;
      z.i = z.r * p0->i + z.i * p0->r;
    }
    p0->r = p0->r * p0->r - p0->i * p0->i;
    p0->i = 2 * p0->r * p0->i;
  }
  if (*p3<0) {
    typercl2 v, w;
    if ( (z.r<0 ? -z.r:z.r) > (z.i<0 ? -z.i:z.i) ) {
      v = z.i/z.r;
      w = (1+v*v)*z.r;
      p1->r =  1/w;
      p1->i = -v/w;
    } else {
      v = z.r/z.i;
      w = (1+v*v)*z.i;
      p1->r =  v/w;
      p1->i = -1/w;
    }
  }else {
    *p1 = z;
  }"],
 [/[X]/,/[F]/, "typecl2 x;
  if (*p3==0) {
    p1->r=1; p1->i=0; 
  }else if (p2->r==0 && p2->i==0 && *p3>0) {
    p1->r=0; p1->i=0;
  }else {
    x.r = exp(log(hypot(p2->r, p2->i)) * *p3);
    x.i = atan2(p2->i, p2->r) * *p3;
    p1->r = x.r * cos(x.i);
    p1->i = x.r * sin(x.i);
  }"],
 [/[X]/,/[X]/, "typecl2 x, y;
  if (p3->r==0 && p3->i==0) {
    p1->r=1; p1->i=0;
  }else if (p2->r==0 && p2->i==0 && p3->r>0 && p3->i==0) {
    p1->r=0; p1->i=0;
  }else {
    y.r = log(hypot(p2->r, p2->i));
    y.i = atan2(p2->i, p2->r);
    x.r = exp(p3->r * y.r - p3->i * y.i);
    x.i = p3->r * y.i + p3->i * y.r;
    p1->r = x.r * cos(x.i);
    p1->i = x.r * sin(x.i);
  }"]
])

#
# random
#
$func_body = 
  "__kernel void #name#C(__global char* p1, int i1, typercl rmax, char sign)
{
  GLOBAL_ID
  OPERATION
}
"
print <<EOM
/* This is based on na_random.c that utilizes MT19937. See na_random.c for the original copyright notice of MT19937. */
#define N 624
#define M 397
#define MATRIX_A 0x9908b0dfUL   /* constant vector a */
#define UMASK 0x80000000UL /* most significant w-r bits */
#define LMASK 0x7fffffffUL /* least significant r bits */
#define MIXBITS(u,v) ( ((u) & UMASK) | ((v) & LMASK) )
#define TWIST(u,v) ((MIXBITS(u,v) >> 1) ^ ((v)&1UL ? MATRIX_A : 0UL))

global uint state[N] = {#{state=[5489];1.upto(623){|j|state<<((1812433253*(state[-1]^(state[-1]>>30))+j)&0x0ffffffff)};state.join(',')}}; /* the default initial seed array for the state vector */
global int left = N;

/* initializes state[N] with a seed */
__kernel void init_genrand(uint s)
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
  left = N;
}

#define genrand(y) \\
{ int j = N - ((left==0)? (left=N) : (left--));\\
  if (j < N-M) {\\
    (y) = state[j] = state[j+M] ^ TWIST(state[j], state[j+1]);\\
  }else if (j < N-1) {\\
    (y) = state[j] = state[j+M-N] ^ TWIST(state[j], state[j+1]);\\
  }else {/* j==N-1 */\\
    (y) = state[j] = state[j+M-N] ^ TWIST(state[j], state[0]);\\
  }\\
  (y) ^= ((y) >> 11);\\
  (y) ^= ((y) << 7) & 0x9d2c5680UL;\\
  (y) ^= ((y) << 15) & 0xefc60000UL;\\
  (y) ^= ((y) >> 18); }

// #define rand_double(x,y) \\
//   (((double)((x)>>5)+(double)((y)>>6)*(1.0/67108864.0)) * (1.0/134217728.0))

#define rand_single(y) \\
  ((float)(y) * (1.0/4294967296.0))

#define n_bits(a,xl) \\
{ int x=0x10, bitwidth=32;\\
  if ((~((1<<(x-1))-1)) & (a)) { (xl) = bitwidth - x; x += 0x08; } else { x -= 0x08; }\\
  if ((~((1<<(x-1))-1)) & (a)) { (xl) = bitwidth - x; x += 0x04; } else { x -= 0x04; }\\
  if ((~((1<<(x-1))-1)) & (a)) { (xl) = bitwidth - x; x += 0x02; } else { x -= 0x02; }\\
  if ((~((1<<(x-1))-1)) & (a)) { (xl) = bitwidth - x; x += 0x01; } else { x -= 0x01; }\\
  if ((~((1<<(x-1))-1)) & (a)) { (xl) = bitwidth - x; }\\
}
EOM

$kernels << "  init_genrandKernel = clCreateKernel(program, \"init_genrand\", &ret);"
$globals << "cl_kernel init_genrandKernel;" 

mkopenclfuncs('Rnd', $opencl_types, $opencl_types,
 [nil] +
 ["uint y;
  int shift;

  if (rmax<1) {
    (*(typecl*)&p1[gid*i1]) = 0;
  } else {
    n_bits((int)rmax,shift);
    do {
      genrand(y);
      y >>= shift;
    } while (y > rmax);
    (*(typecl*)&p1[gid*i1]) = (typecl)y*sign;
  }"]*3 +
 ["uint y;
  genrand(y);
  (*(typecl*)&p1[gid*i1]) = rand_single(y) * rmax;"] +
 [nil] +
 ["uint y;
  genrand(y);
  ((typecl*)&p1[gid*i1])->r = rand_single(y) * rmax;
  ((typecl*)&p1[gid*i1])->i = 0;"] +
 [nil]*2
)

$>.close
File.open("na_opencl.h","w"){|f|
  f.puts "#define KERNEL_SRC_FILE \"#{ARGV[0]}/na_kernel.cl\""
  f.puts "#define MAX_SOURCE_SIZE (#{File.size('./na_kernel.cl')})"
  f.puts "#define HDRDIR \"-I#{ARGV[0]} -I#{ARGV[1]}\""
  f.puts $kernels.join("\\\n") + "}"
  f.puts $globals.join("\n")
}
