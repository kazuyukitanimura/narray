require "mknafunc"

$kernels = ["#define CREATE_OPENCL_KERNELS(program,ret) {"]

fname = "na_kernel.cl"
$> = open(fname,"w")

upcast_ary = $upcast.collect{|i| '  {'+i.join(", ")+'}'}.join(",\n")

$opencl_types = 
 %w(none uchar short int float double scomplex dcomplex VALUE)

def mkopenclfuncs(name,t1,t2,func)

  print "
/* ------------------------- #{name} --------------------------- */\n"
  c  = $type_codes
  td = $data_types
  tr = $real_types
  tcl= $opencl_types

  for i in 0...c.size
    if func[i] != nil && func[i] != "copy"
      f = func[i].
	gsub(/p0->/,"((#{t1[i]}*)&p0[gid*i1])->").
	gsub(/p1->/,"((#{t1[i]}*)&p1[gid*i1])->").
	gsub(/p2->/,"((#{t2[i]}*)&p2[gid*i2])->").
	gsub(/p3->/,"((#{t2[i]}*)&p3[gid*i3])->").
	gsub(/\*p0/,"(*(#{t1[i]}*)&p0[gid*i1])").
	gsub(/\*p1/,"(*(#{t1[i]}*)&p1[gid*i1])").
	gsub(/\*p2/,"(*(#{t2[i]}*)&p2[gid*i2])").
	gsub(/\*p3/,"(*(#{t2[i]}*)&p3[gid*i3])").
	gsub(/type1/,td[i]).
	gsub(/typecl/,tcl[i]).
	gsub(/typef/,tr[i])
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
    elsif func[i]=='copy'
  #    m += ['Set'+c[$data_types.index(t1[i])]+c[i]]
    else
  #    m += [name+c[i]]
      $kernels << "  #{name}Funcs[#{narray_types[i]}] = (void*)clCreateKernel(program, \"#{name+c[i]}\", &ret);"
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
const int na_upcast[NA_NTYPES][NA_NTYPES] = {
#{upcast_ary} };

const int na_no_cast[NA_NTYPES] =
 { 0, 1, 2, 3, 4, 5, 6, 7, 8 };
const int na_cast_real[NA_NTYPES] =
 { 0, 1, 2, 3, 4, 5, 4, 5, 8 };
const int na_cast_comp[NA_NTYPES] =
 { 0, 6, 6, 6, 6, 7, 6, 7, 8 };
const int na_cast_round[NA_NTYPES] =
 { 0, 1, 2, 3, 3, 3, 6, 7, 8 };
const int na_cast_byte[NA_NTYPES] =
 { 0, 1, 1, 1, 1, 1, 1, 1, 1 };


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

static int notnanF(float *n)
{
  return *n == *n;
}
static int notnanD(double *n)
{
  return *n == *n;
}*/
EOM

#
##
##  Set Fucs
##
#data = [
#  [/[O]/,/[O]/,        "*p1 = *p2;"],
#  [/[O]/,/[BI]/,       "*p1 = INT2FIX(*p2);"],
#  [/[O]/,/[L]/,        "*p1 = INT2NUM(*p2);"],
#  [/[O]/,/[FD]/,       "*p1 = rb_float_new(*p2);"],
#  [/[O]/,/[XC]/,       "*p1 = rb_complex_new(p2->r,p2->i);"],
#  [/[BIL]/,/[O]/,      "*p1 = NUM2INT(*p2);"],
#  [/[FD]/,/[O]/,       "*p1 = NUM2DBL(*p2);"],
#  [/[XC]/,/[O]/,       "p1->r = NUM2REAL(*p2); p1->i = NUM2IMAG(*p2);"],
#  [/[BILFD]/,/[BILFD]/,"*p1 = *p2;"],
#  [/[BILFD]/,/[XC]/,   "*p1 = p2->r;"],
#  [/[XC]/,/[BILFD]/,   "p1->r = *p2; p1->i = 0;"],
#  [/[XC]/,/[XC]/,      "p1->r = p2->r; p1->i = p2->i;"] ]
#
#$func_body = 
#  "static void #name#CC(int n, char *p1, int i1, char *p2, int i2)
#{
#  for (; n; --n) {
#    OPERATION
#    p1+=i1; p2+=i2;
#  }
#}
#"
#mksetfuncs('Set','','',data)



#
#  Unary Funcs
#
$func_body = 
  "__kernel void #name#C(__local char* p0, __global char* p1, int i1, __global char* p2, int i2)
{
  GLOBAL_ID
  OPERATION
}
"

#mkfuncs('Swp', $swap_types, $swap_types,
# [nil] +
# ["*p1 = *p2;"] + 
# ["na_size16_t x;  swap16(x,*p2);   *p1 = x;"] + 
# ["na_size32_t x;  swap32(x,*p2);   *p1 = x;"] + 
# ["na_size32_t x;  swap32(x,*p2);   *p1 = x;"] + 
# ["na_size64_t x;  swap64(x,*p2);   *p1 = x;"] + 
# ["na_size64_t x;  swap64c(x,*p2);  *p1 = x;"] + 
# ["na_size128_t x; swap128c(x,*p2); *p1 = x;"] + 
# ["*p1 = *p2;"]
#)
#
#print <<EOM
#
#/* ------------------------- H2N --------------------------- */
##ifdef WORDS_BIGENDIAN
#
#na_func_t H2NFuncs =
#{ TpErr, SetBB, SetII, SetLL, SetFF, SetDD, SetXX, SetCC, SetOO };
#
#na_func_t H2VFuncs =
#{ TpErr, SetBB, SwpI, SwpL, SwpF, SwpD, SwpX, SwpC, SetOO };
#
##else
##ifdef DYNAMIC_ENDIAN  /* not supported yet */
##else  /* LITTLE ENDIAN */
#
#na_func_t H2NFuncs =
#{ TpErr, SetBB, SwpI, SwpL, SwpF, SwpD, SwpX, SwpC, SetOO };
#
#na_func_t H2VFuncs =
#{ TpErr, SetBB, SetII, SetLL, SetFF, SetDD, SetXX, SetCC, SetOO };
#
##endif
##endif
#EOM

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
  typef a = y.r*y.r + y.i*y.i;
  p0->r = (x.r*y.r + x.i*y.i)/a;
  p0->i = (x.i*y.r - x.r*y.i)/a;
  barrier(CLK_LOCAL_MEM_FENCE);
  p1->r = p0->r;
  p1->i = p0->i;"] +
 [nil] +
 [nil]
)


## method: imag=
#mkfuncs('ImgSet',$data_types,$real_types,
# [nil]*6 +
# ["p1->i = *p2;"]*2 +
# [nil]
#)
#
#
#mkfuncs('Floor',$int_types,$data_types,[nil] +
# ['copy']*3 + 
# ["*p1 = floor(*p2);"]*2 + 
# [nil]*3
#)
#
#mkfuncs('Ceil',$int_types,$data_types,[nil] +
# ['copy']*3 + 
# ["*p1 = ceil(*p2);"]*2 + 
# [nil]*3
#)
#
#mkfuncs('Round',$int_types,$data_types,[nil] +
# ['copy']*3 + 
## ["*p1 = floor(*p2+0.5);"]*2 + 
# ["if (*p2 >= 0) *p1 = floor(*p2+0.5);
#     else *p1 = ceil(*p2-0.5);"]*2 + 
# [nil]*3
#)
#
#mkfuncs('Abs',$real_types,$data_types,[nil] +
# ["*p1 = *p2;"] + 
# ["*p1 = (*p2<0) ? -*p2 : *p2;"]*4 + 
# ["*p1 = hypot(p2->r, p2->i);"]*2 +
# ["*p1 = rb_funcall(*p2,na_id_abs,0);"]
#)
#
#
#mkfuncs('Real',$real_types,$data_types,[nil] +
# ['copy']*7 + 
# [nil]
#)
#
#mkfuncs('Imag',$real_types,$data_types,[nil] +
# ["*p1 = 0;"]*5 + 
# ["*p1 = p2->i;"]*2 +
# [nil]
#)
#
#mkfuncs('Angl',$real_types,$data_types,[nil] +
# [nil]*5 +
# ["*p1 = atan2(p2->i,p2->r);"]*2 +
# [nil]
#)
#
#mkfuncs('ImagMul',$comp_types,$data_types,[nil] +
# [nil]*3 +
# ["p1->r = 0; p1->i = *p2;"]*2 + 
# ["p1->r = -p2->i; p1->i = p2->r;"]*2 +
# [nil]
#)
#
#mkfuncs('Conj',$data_types,$data_types,[nil] +
# ['copy']*5 + 
# ["p1->r = p2->r; p1->i = -p2->i;"]*2 +
# [nil]
#)
#
#mkfuncs('Not', [$data_types[1]]*9, $data_types,
# [nil] +
# ["*p1 = (*p2==0) ? 1:0;"]*5 +
# ["*p1 = (p2->r==0 && p2->i==0) ? 1:0;"]*2 +
# ["*p1 = RTEST(*p2) ? 0:1;"]
#)

mkopenclfuncs('BRv', $opencl_types, $opencl_types,
 [nil] +
 ["*p1 = ~(*p2);"]*3 +
 [nil]*5
)

#mkfuncs('Min', $data_types, $data_types, [nil] +
# ["if (*p1>*p2) *p1=*p2;"]*3 +
# ["if (notnan#C((type1*)p2) && *p1>*p2) *p1=*p2;"]*2 +
# [nil]*2 +
# ["if (FIX2INT(rb_funcall(*p1,na_id_compare,1,*p2))>0) *p1=*p2;"]
#)
#
#mkfuncs('Max', $data_types, $data_types, [nil] +
# ["if (*p1<*p2) *p1=*p2;"]*3 +
# ["if (notnan#C((type1*)p2) && *p1<*p2) *p1=*p2;"]*2 +
# [nil]*2 +
# ["if (FIX2INT(rb_funcall(*p1,na_id_compare,1,*p2))<0) *p1=*p2;"]
#)
#
#
#mksortfuncs('Sort', $data_types, $data_types, [nil] +
# ["
#{ if (*p1 > *p2) return 1;
#  if (*p1 < *p2) return -1;
#  return 0; }"]*5 +
# [nil]*2 +
# ["
#{ VALUE r = rb_funcall(*p1, na_id_compare, 1, *p2);
#  return NUM2INT(r); }"]
#)
#
#mksortfuncs('SortIdx', $data_types, $data_types, [nil] +
# ["
#{ if (**p1 > **p2) return 1;
#  if (**p1 < **p2) return -1;
#  return 0; }"]*5 +
# [nil]*2 +
# ["
#{ VALUE r = rb_funcall(**p1, na_id_compare, 1, **p2);
#  return NUM2INT(r); }"]
#)

# indgen
$func_body = 
  "__kernel void #name#C(__local char* p0, __global char* p1, int i1, int p2, int i2)
{
  GLOBAL_ID
  OPERATION
}
"
#mkopenclfuncs('IndGen',$opencl_types,[$opencl_types[3]]*8,
# [nil] +
# ["*p1 = p2;"]*4 +
# [nil] +
# ["p1->r = p2;
#   p1->i = 0;"] +
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
  "__kernel void #name#C(__local char* p0, __global char* p1, int i1, __global char* p2, int i2, __global char* p3, int i3)
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
  typef a = y.r*y.r + y.i*y.i;
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
  *p1 = *p0;"]*4 + 
 [nil] +
 #["typecl x = *p2;
 # p0->r = p1->r + x.r*p3->r - x.i*p3->i;
 # p0->i = p1->i + x.r*p3->i + x.i*p3->r;"]*2 +
 ["typecl x = *p2;
  typecl y = *p3;
  p0->r = p1->r + x.r*y.r - x.i*y.i;
  p0->i = p1->i + x.r*y.i + x.i*y.r;
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
  *p1 = *p0;"]*4 + 
 [nil] +
 #["typecl x = *p2;
 # p0->r = p1->r - x.r*p3->r - x.i*p3->i;
 # p0->i = p1->i - x.r*p3->i + x.i*p3->r;"]*2 +
 ["typecl x = *p2;
  typecl y = *p3;
  p0->r = p1->r - x.r*y.r - x.i*y.i;
  p0->i = p1->i - x.r*y.i + x.i*y.r;
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


##
##   Atan2
##
#
#mkfuncs('atan2', $data_types, $data_types,
# [nil]*4 +
# ["*p1 = atan2(*p2, *p3);"]*2 +
# [nil]*3
#)
#
#
##
##   Mask
##
#$func_body = 
#  "static void #name#C(int n, char *p1, int i1, char *p2, int i2, char *p3, int i3)
#{
#  for (; n; --n) {
#    OPERATION
#  }
#}
#"
#mkfuncs('RefMask',$data_types,$data_types,
# [nil] +
# ["if (*(u_int8_t*)p3) { *p1=*p2; p1+=i1; }
#    p3+=i3; p2+=i2;"]*8
#)
#
#mkfuncs('SetMask',$data_types,$data_types,
# [nil] +
# ["if (*(u_int8_t*)p3) { *p1=*p2; p2+=i2; }
#    p3+=i3; p1+=i1;"]*8
#)
$>.close
File.open("na_opencl.h","w"){|f|
  f.puts "#define KERNEL_SRC_FILE \"#{ARGV[0]}/na_kernel.cl\""
  f.puts "#define MAX_SOURCE_SIZE (#{File.size('./na_kernel.cl')})"
  f.puts "#define HDRDIR \"-I#{ARGV[0]} -I#{ARGV[1]}\""
  f.puts $kernels.join("\\\n") + "}"
}
