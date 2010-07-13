require "mknafunc"

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
  trcl= $realopencl_types

  # Function Definition

  for i in 0...n
    for j in 0...n
      funcs.each do |k|
	if c[i]=~k[0] && c[j]=~k[1]
          f = k[2]
	  f = f.
            gsub(/p0->/,"((#{tcl[i]}*)&p0[gid*i1])->").
            gsub(/p1->/,"((#{tcl[i]}*)&p1[gid*i1+b1])->").
            gsub(/p2->/,"((#{tcl[j]}*)&p2[gid*i2+b2])->").
            gsub(/\*p0/,"(*(#{tcl[i]}*)&p0[gid*i1])").
            gsub(/\*p1/,"(*(#{tcl[i]}*)&p1[gid*i1+b1])").
            gsub(/\*p2/,"(*(#{tcl[j]}*)&p2[gid*i2+b2])").
            gsub(/#id/,id).
            gsub(/#op/,op).
	    gsub(/typed/,td[i]).
            gsub(/typecl/,tcl[i]).
            gsub(/typef/,tr[i]).
            gsub(/typercl/,trcl[i])
	  puts $func_body.
	    gsub(/#name/,name).
            sub(/GLOBAL_ID/,'int gid = get_global_id(0);').
	    sub(/OPERATION/,f).
	    gsub(/#CC/,c[i]+c[j])
	end
      end
    end
  end

  # function pointer array
  narray_types = ["NA_NONE", "NA_BYTE", "NA_SINT", "NA_LINT", "NA_SFLOAT", "NA_DFLOAT", "NA_SCOMPLEX", "NA_DCOMPLEX", "NA_ROBJ", "NA_NTYPES"]
  #print "\nna_setfunc_t "+name+"Funcs = {\n"
  #m = []
  for i in 0...n
    #l = []
    for j in 0...n
      f = true
      for k in funcs
	if c[i]=~k[0] && c[j]=~k[1]
	  #l += [name+c[i]+c[j]]
          $kernels << "  #{name}Kernels[#{narray_types[i]}][#{narray_types[j]}] = (void*)clCreateKernel(program, \"#{name+c[i]+c[j]}\", &ret);"
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
	gsub(/p1->/,"((#{t1[i]}*)&p1[gid*i1+b1])->").
	gsub(/p2->/,"((#{t2[i]}*)&p2[gid*i2+b2])->").
	gsub(/p3->/,"((#{t2[i]}*)&p3[gid*i3+b3])->").
	gsub(/\*p0/,"(*(#{t1[i]}*)&p0[gid*i1])").
	gsub(/\*p1/,"(*(#{t1[i]}*)&p1[gid*i1+b1])").
	gsub(/\*p2/,"(*(#{t2[i]}*)&p2[gid*i2+b2])").
	gsub(/\*p3/,"(*(#{t2[i]}*)&p3[gid*i3+b3])").
	gsub(/type1/,td[i]).
	gsub(/typecl/,tcl[i]).
	gsub(/typef/,tr[i]).
	gsub(/typercl/,trcl[i])
      puts $func_body.
	gsub(/#name/,name).
	sub(/GLOBAL_ID/,'int gid = get_global_id(0);').
	sub(/OPERATION/,f).
	gsub(/#C/,c[i])
    end
  end
  # Function Array
  narray_types = ["NA_NONE", "NA_BYTE", "NA_SINT", "NA_LINT", "NA_SFLOAT", "NA_DFLOAT", "NA_SCOMPLEX", "NA_DCOMPLEX", "NA_ROBJ", "NA_NTYPES"]
  #print "\ncl_kernel #{name}Funcs =\n{ "
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
      $kernels << "  #{name}Kernels[#{narray_types[i]}] = (void*)clCreateKernel(program, \"#{name+c[i]}\", &ret);"
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
  "__kernel void #name#CC(__local char* p0, __global char* p1, int i1, int b1, __global char* p2, int i2, int b2)
{
  GLOBAL_ID
  OPERATION
}
"
mkopenclsetfuncs('Set','','',data)



#
#  Unary Funcs
#
$func_body = 
  "__kernel void #name#C(__local char* p0, __global char* p1, int i1, int b1, __global char* p2, int i2, int b2)
{
  GLOBAL_ID
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
  barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"]*4 + 
 [nil] +
 ["p0->r = p1->r + p2->r;
  p0->i = p1->i + p2->i;
  barrier(CLK_LOCAL_MEM_FENCE);
  p1->r = p0->r;
  p1->i = p0->i;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('SbtU', $opencl_types, $opencl_types,
 [nil] +
 ["*p0 = *p1 - *p2;
  barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"]*4 + 
 [nil] +
 ["p0->r = p1->r - p2->r;
  p0->i = p1->i - p2->i;
  barrier(CLK_LOCAL_MEM_FENCE);
  p1->r = p0->r;
  p1->i = p0->i;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('MulU', $opencl_types, $opencl_types,
 [nil] +
 ["*p0 = *p1 * *p2;
  barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"]*4 + 
 [nil] +
 ["typecl x = *p1;
  typecl y = *p2;
  p0->r = x.r*y.r - x.i*y.i;
  p0->i = x.r*y.i + x.i*y.r;
  barrier(CLK_LOCAL_MEM_FENCE);
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
  barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"]*4 + 
 [nil] +
 ["typecl x = *p1;
  typecl y = *p2;
  typercl a = y.r*y.r + y.i*y.i;
  p0->r = (x.r*y.r + x.i*y.i)/a;
  p0->i = (x.i*y.r - x.r*y.i)/a;
  barrier(CLK_LOCAL_MEM_FENCE);
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
  "__kernel void #name#C(__global char* p1, int i1, int b1, int p2, int i2, int b2)
{
  int gid = get_global_id(0);
  OPERATION
}
"
mkopenclfuncs('IndGen',$opencl_types,[$opencl_types[3]]*8,
 [nil] +
 ["*p1 = p2+gid*i2;"]*4 +
 [nil] +
 ["p1->r = p2+gid*i2;
   p1->i = 0;"] +
 [nil] +
 [nil]
)

## reduction for sum
#$func_body = 
#  "__kernel void #name#C(__local char* p0, __global char* p1, int i1, int b1, __global char* p2, int i2, int b2)
#{
#  int gid = get_global_id(0);
#  OPERATION
#}
#"
#mkopenclfuncs('RdcU', $opencl_types, $opencl_types,
# [nil] +
# ["i1 = i2;
#  if (gid < get_global_size(0)/2)
#    *p0 = *p2;
#  int b2_org = b2;
#  barrier(CLK_LOCAL_MEM_FENCE);
#  for (b2 += i2*(get_global_size(0)/2); (b2-b2_org) < get_global_size(0); b2 += i2*((b2-b2_org)/2)) {
#    if (gid < (b2-b2_org)) {
#      *p0 += *p2;
#    }
#    barrier(CLK_LOCAL_MEM_FENCE);
#  }
#  i1 = 0;
#  if (gid == 0)
#    *p0 += *p1;
#  barrier(CLK_LOCAL_MEM_FENCE);
#  *p1 = *p0;"]*4 + 
# [nil] +
# ["p0->r = p1->r + p2->r;
#  p0->i = p1->i + p2->i;
#  barrier(CLK_LOCAL_MEM_FENCE);
#  p1->r = p0->r;
#  p1->i = p0->i;"] +
# [nil] +
# [nil]
#)

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
  "__kernel void #name#C(__local char* p0, __global char* p1, int i1, int b1, __global char* p2, int i2, int b2, __global char* p3, int i3, int b3)
{
  GLOBAL_ID
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
  barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"]*3 + 
 ["*p0 = fma(*p2, *p3, *p1);
  barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"] + 
 [nil] +
 #["typecl x = *p2;
 # p0->r = p1->r + x.r*p3->r - x.i*p3->i;
 # p0->i = p1->i + x.r*p3->i + x.i*p3->r;"]*2 +
 ["typecl x = *p2;
  typecl y = *p3;
  p0->r = fma(-(x.i), y.i, fma(x.r, y.r, p1->r));
  p0->i = fma(  x.i,  y.r, fma(x.r, y.i, p1->i));
  barrier(CLK_LOCAL_MEM_FENCE);
  p1->r = p0->r;
  p1->i = p0->i;"] +
 [nil] +
 [nil]
)

mkopenclfuncs('MulSbt', $opencl_types, $opencl_types,
 [nil] +
 ["*p0 = *p1 - *p2 * *p3;
  barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"]*3 + 
 ["*p0 = fma(-*p2, *p3, *p1);
  barrier(CLK_LOCAL_MEM_FENCE);
  *p1 = *p0;"] + 
 [nil] +
 #["typecl x = *p2;
 # p0->r = p1->r - x.r*p3->r - x.i*p3->i;
 # p0->i = p1->i - x.r*p3->i + x.i*p3->r;"]*2 +
 ["typecl x = *p2;
  typecl y = *p3;
  p0->r = fma(-(x.i), y.i, fma(-(x.r), y.r, p1->r));
  p0->i = fma(  x.i,  y.r, fma(-(x.r), y.i, p1->i));
  barrier(CLK_LOCAL_MEM_FENCE);
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
#$func_body = 
#  "static void #name#C(int n, char *p1, int i1, char *p2, int i2, char *p3, int i3)
#{
#  for (; n; --n) {
#    OPERATION
#  }
#}
#"
#mkopenclfuncs('RefMask',$opencl_types,$opencl_types,
# [nil] +
# ["if (*(uchar*)p3) { *p1=*p2; p1+=i1; }
#    p3+=i3; p2+=i2;"]*8
#)
#
#mkfopencluncs('SetMask',$opencl_types,$opencl_types,
# [nil] +
# ["if (*(uchar*)p3) { *p1=*p2; p2+=i2; }
#    p3+=i3; p1+=i1;"]*8
#)
$>.close
File.open("na_opencl.h","w"){|f|
  f.puts "#define KERNEL_SRC_FILE \"#{ARGV[0]}/na_kernel.cl\""
  f.puts "#define MAX_SOURCE_SIZE (#{File.size('./na_kernel.cl')})"
  f.puts "#define HDRDIR \"-I#{ARGV[0]} -I#{ARGV[1]}\""
  f.puts $kernels.join("\\\n") + "}"
}
