#
# Copyright 2002 Free Software Foundation, Inc.
#
# This file is part of GNU Radio
#
# GNU Radio is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
#
# GNU Radio is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GNU Radio; see the file COPYING.  If not, write to
# the Free Software Foundation, Inc., 51 Franklin Street,
# Boston, MA 02110-1301, USA.
#


# input and taps are guarenteed to be 16 byte aligned.
# n_2_complex_blocks is != 0
#
#
#  complex_dotprod_generic (const short *input,
#                         const float *taps, unsigned n_2_complex_blocks, float *result)
#  {
#    float sum0 = 0;
#    float sum1 = 0;
#    float sum2 = 0;
#    float sum3 = 0;
#
#    do {
#
#      sum0 += input[0] * taps[0];
#      sum1 += input[0] * taps[1];
#      sum2 += input[1] * taps[2];
#      sum3 += input[1] * taps[3];
#
#      input += 2;
#      taps += 4;
#
#    } while (--n_2_complex_blocks != 0);
#
#
#    result[0] = sum0 + sum2;
#    result[1] = sum1 + sum3;
#  }
#

# TODO: prefetch and better scheduling

#include "assembly.h"


	.file	"complex_dotprod_sse.S"
//	.version	"01.01"
.text
	.p2align 4
.globl GLOB_SYMB(complex_dotprod_sse)
	DEF_FUNC_HEAD(complex_dotprod_sse)
GLOB_SYMB(complex_dotprod_sse):
	pushl	%ebp
	movl	%esp, %ebp
	movl	8(%ebp), %eax		# input
	movl	12(%ebp), %edx		# taps
	movl	16(%ebp), %ecx


	# xmm0 xmm1 xmm2 xmm3 are used to hold taps and the result of mults
	# xmm4 xmm5 xmm6 xmm7 are used to hold the accumulated results

	xorps	%xmm4, %xmm4		# zero two accumulators
	xorps	%xmm5, %xmm5		# xmm5 holds zero for use below

	# first handle any non-zero remainder of (n_2_complex_blocks % 4)

	andl	$0x3, %ecx
	jmp	.L1_test

	.p2align 4
.Loop1:

	pxor    %mm0, %mm0
	punpcklwd       0(%eax), %mm0
	psrad   $16, %mm0
	cvtpi2ps %mm0, %xmm0
	shufps	$0x50, %xmm0, %xmm0

	mulps	(%edx), %xmm0
	addl	$0x10, %edx
	addl	$4, %eax
	addps	%xmm0, %xmm4
.L1_test:
	decl	%ecx
	jge	.Loop1


	# set up for primary loop which is unrolled 4 times

	movl	16(%ebp), %ecx
	movaps	%xmm5, %xmm6		# zero remaining accumulators
	movaps	%xmm5, %xmm7

	shrl	$2, %ecx		# n_2_complex_blocks / 4
	je	.Lcleanup		# if zero, take short path

	# finish setup and loop priming

	pxor    %mm0, %mm0
	punpcklwd       0(%eax), %mm0
	psrad   $16, %mm0
	cvtpi2ps %mm0, %xmm0
	shufps	$0x50, %xmm0, %xmm0

	movaps	%xmm5, %xmm2

	pxor    %mm1, %mm1
	punpcklwd       4(%eax), %mm1
	psrad   $16, %mm1
	cvtpi2ps %mm1, %xmm1
	shufps	$0x50, %xmm1, %xmm1

	movaps	%xmm5, %xmm3

	# we know ecx is not zero, we checked above,
	# hence enter loop at top

	.p2align 4
.Loop2:
	mulps	(%edx), %xmm0
	addps	%xmm2, %xmm6

	pxor    %mm2, %mm2
	punpcklwd       8(%eax), %mm2
	psrad   $16, %mm2
	cvtpi2ps %mm2, %xmm2
	shufps	$0x50, %xmm2, %xmm2

	mulps	0x10(%edx), %xmm1
	addps	%xmm3, %xmm7

	pxor    %mm3, %mm3
	punpcklwd       12(%eax), %mm3
	psrad   $16, %mm3
	cvtpi2ps %mm3, %xmm3
	shufps	$0x50, %xmm3, %xmm3

	mulps	0x20(%edx), %xmm2
	addps	%xmm0, %xmm4

	pxor    %mm0, %mm0
	punpcklwd       16(%eax), %mm0
	psrad   $16, %mm0
	cvtpi2ps %mm0, %xmm0
	shufps	$0x50, %xmm0, %xmm0

	mulps	0x30(%edx), %xmm3
	addps	%xmm1, %xmm5

	pxor    %mm1, %mm1
	punpcklwd       20(%eax), %mm1
	psrad   $16, %mm1
	cvtpi2ps %mm1, %xmm1
	shufps	$0x50, %xmm1, %xmm1

	addl	$0x40, %edx
	addl	$0x10, %eax
	decl	%ecx
	jne	.Loop2

	# OK, now we've done with all the multiplies, but
	# we still need to handle the unaccumulated
	# products in xmm2 and xmm3

	addps	%xmm2, %xmm6
	addps	%xmm3, %xmm7

	# now we want to add all accumulators into xmm4

	addps	%xmm5, %xmm4
	addps	%xmm6, %xmm7
	addps	%xmm7, %xmm4


	# At this point, xmm4 contains 2x2 partial sums.  We need
	# to compute a "horizontal complex add" across xmm4.

.Lcleanup:				# xmm4 = r1 i2 r3 i4
	movl	20(%ebp), %eax		# @result
	movhlps	%xmm4, %xmm0		# xmm0 = ?? ?? r1 r2
	addps	%xmm4, %xmm0		# xmm0 = ?? ?? r1+r3 i2+i4
	movlps	%xmm0, (%eax)		# store low 2x32 bits (complex) to memory

	emms
	popl	%ebp
	ret

FUNC_TAIL(complex_dotprod_sse)
	.ident	"Hand coded x86 SSE assembly"

#if defined(__linux__) && defined(__ELF__)
.section .note.GNU-stack,"",%progbits
#endif
