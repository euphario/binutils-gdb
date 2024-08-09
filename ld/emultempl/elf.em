# This shell script emits a C file. -*- C -*-
# It does some substitutions.
test -z "${ELFSIZE}" && ELFSIZE=32
if [ -z "$MACHINE" ]; then
  OUTPUT_ARCH=${ARCH}
else
  OUTPUT_ARCH=${ARCH}:${MACHINE}
fi
fragment <<EOF
/* This file is is generated by a shell script.  DO NOT EDIT! */

/* ${ELFSIZE} bit ELF emulation code for ${EMULATION_NAME}
   Copyright (C) 1991-2024 Free Software Foundation, Inc.
   Written by Steve Chamberlain <sac@cygnus.com>
   ELF support by Ian Lance Taylor <ian@cygnus.com>

   This file is part of the GNU Binutils.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street - Fifth Floor, Boston,
   MA 02110-1301, USA.  */

#define TARGET_IS_${EMULATION_NAME}

#include "sysdep.h"
#include "bfd.h"
#include "libiberty.h"
#include "getopt.h"
#include "bfdlink.h"
#include "ctf-api.h"
#include "ld.h"
#include "ldmain.h"
#include "ldmisc.h"
#include "ldexp.h"
#include "ldlang.h"
#include "ldfile.h"
#include "ldlex.h"
#include "ldemul.h"
#include <ldgram.h>
#include "elf-bfd.h"
#include "ldelf.h"
#include "ldelfgen.h"

/* Declare functions used by various EXTRA_EM_FILEs.  */
static void gld${EMULATION_NAME}_before_parse (void);
static void gld${EMULATION_NAME}_before_plugin_all_symbols_read
  (void);
static void gld${EMULATION_NAME}_after_open (void);
static void gld${EMULATION_NAME}_before_allocation (void);
static void gld${EMULATION_NAME}_after_allocation (void);
EOF

# Import any needed special functions and/or overrides.
#
source_em ${srcdir}/emultempl/elf-generic.em
if test -n "$EXTRA_EM_FILE" ; then
  source_em ${srcdir}/emultempl/${EXTRA_EM_FILE}.em
fi

# Functions in this file can be overridden by setting the LDEMUL_* shell
# variables.  If the name of the overriding function is the same as is
# defined in this file, then don't output this file's version.
# If a different overriding name is given then output the standard function
# as presumably it is called from the overriding function.
#
if test x"$LDEMUL_BEFORE_PARSE" != xgld"$EMULATION_NAME"_before_parse; then
fragment <<EOF

static void
gld${EMULATION_NAME}_before_parse (void)
{
  ldfile_set_output_arch ("${OUTPUT_ARCH}", bfd_arch_`echo ${ARCH} | sed -e 's/:.*//'`);
  input_flags.dynamic = ${DYNAMIC_LINK-true};
  config.has_shared = `if test -n "$GENERATE_SHLIB_SCRIPT" ; then echo true ; else echo false ; fi`;
  config.separate_code = `if test "x${SEPARATE_CODE}" = xyes ; then echo true ; else echo false ; fi`;
  link_info.check_relocs_after_open_input = true;
EOF
if test -n "$COMMONPAGESIZE"; then
fragment <<EOF
  link_info.relro = DEFAULT_LD_Z_RELRO;
EOF
fi
fragment <<EOF
  link_info.separate_code = DEFAULT_LD_Z_SEPARATE_CODE;
  link_info.one_rosegment = DEFAULT_LD_ROSEGMENT;
  link_info.warn_execstack = DEFAULT_LD_WARN_EXECSTACK;
  link_info.no_warn_rwx_segments = ! DEFAULT_LD_WARN_RWX_SEGMENTS;
  link_info.default_execstack = DEFAULT_LD_EXECSTACK;
  link_info.error_execstack = DEFAULT_LD_ERROR_EXECSTACK;
  link_info.warn_is_error_for_rwx_segments = DEFAULT_LD_ERROR_RWX_SEGMENTS;
}

EOF
fi

fragment <<EOF

/* These variables are used to implement target options */

static char *audit; /* colon (typically) separated list of libs */
static char *depaudit; /* colon (typically) separated list of libs */

EOF

if test x"$LDEMUL_AFTER_OPEN" != xgld"$EMULATION_NAME"_after_open; then

  IS_LINUX_TARGET=false
  IS_FREEBSD_TARGET=false
  case ${target} in
    *-*-linux-* | *-*-k*bsd*-* | *-*-gnu*)
      IS_LINUX_TARGET=true ;;
    *-*-freebsd* | *-*-dragonfly*)
      IS_FREEBSD_TARGET=true ;;
  esac
  IS_LIBPATH=false
  if test "x${USE_LIBPATH}" = xyes; then
    IS_LIBPATH=true
  fi
  IS_NATIVE=false
  if test "x${NATIVE}" = xyes; then
    IS_NATIVE=true
  fi

fragment <<EOF

/* This is called before calling plugin 'all symbols read' hook.  */

static void
gld${EMULATION_NAME}_before_plugin_all_symbols_read (void)
{
  ldelf_before_plugin_all_symbols_read ($IS_LIBPATH, $IS_NATIVE,
				        $IS_LINUX_TARGET,
					$IS_FREEBSD_TARGET,
					$ELFSIZE, "$prefix");
}

/* This is called after all the input files have been opened.  */

static void
gld${EMULATION_NAME}_after_open (void)
{
  ldelf_after_open ($IS_LIBPATH, $IS_NATIVE,
		    $IS_LINUX_TARGET, $IS_FREEBSD_TARGET, $ELFSIZE, "$prefix");
}

EOF
fi

if test x"$LDEMUL_BEFORE_ALLOCATION" != xgld"$EMULATION_NAME"_before_allocation; then
  if test x"${ELF_INTERPRETER_NAME}" = x; then
    ELF_INTERPRETER_NAME=NULL
  fi
fragment <<EOF

/* This is called after the sections have been attached to output
   sections, but before any sizes or addresses have been set.  */

static void
gld${EMULATION_NAME}_before_allocation (void)
{
  ldelf_before_allocation (audit, depaudit, ${ELF_INTERPRETER_NAME});
}

EOF
fi

if test x"$LDEMUL_AFTER_ALLOCATION" != xgld"$EMULATION_NAME"_after_allocation; then
fragment <<EOF

static void
gld${EMULATION_NAME}_after_allocation (void)
{
  int need_layout = bfd_elf_discard_info (link_info.output_bfd, &link_info);

  if (need_layout < 0)
    einfo (_("%X%P: .eh_frame/.stab edit: %E\n"));
  else
    ldelf_map_segments (need_layout);
}
EOF
fi

if test x"$LDEMUL_GET_SCRIPT" != xgld"$EMULATION_NAME"_get_script; then
fragment <<EOF

static char *
gld${EMULATION_NAME}_get_script (int *isfile)
EOF

if test x"$COMPILE_IN" = xyes
then
# Scripts compiled in.

# sed commands to quote an ld script as a C string.
sc="-f ${srcdir}/emultempl/stringify.sed"

fragment <<EOF
{
  *isfile = 0;

  if (bfd_link_relocatable (&link_info) && config.build_constructors)
    return
EOF
sed $sc ldscripts/${EMULATION_NAME}.xu			>> e${EMULATION_NAME}.c

echo '  ; else if (bfd_link_relocatable (&link_info)) return' >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xr			>> e${EMULATION_NAME}.c

echo '  ; else if (!config.text_read_only) return'	>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xbn			>> e${EMULATION_NAME}.c

if cmp -s ldscripts/${EMULATION_NAME}.x ldscripts/${EMULATION_NAME}.xn; then : ; else
  echo '  ; else if (!config.magic_demand_paged) return'	>> e${EMULATION_NAME}.c
  sed $sc ldscripts/${EMULATION_NAME}.xn			>> e${EMULATION_NAME}.c
fi

if test -n "$GENERATE_PIE_SCRIPT" ; then
if test -n "$GENERATE_COMBRELOC_SCRIPT" ; then

echo '  ; else if (bfd_link_pie (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.combreloc'		>> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'		>> e${EMULATION_NAME}.c
echo '             && link_info.one_rosegment'		>> e${EMULATION_NAME}.c
echo '             && (link_info.flags & DF_BIND_NOW)) return' >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xdwer		>> e${EMULATION_NAME}.c

echo '  ; else if (bfd_link_pie (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.combreloc'		>> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'		>> e${EMULATION_NAME}.c
echo '             && (link_info.flags & DF_BIND_NOW)) return' >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xdwe		>> e${EMULATION_NAME}.c

echo '  ; else if (bfd_link_pie (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.combreloc'		>> e${EMULATION_NAME}.c
echo '             && link_info.relro'			>> e${EMULATION_NAME}.c
echo '             && (link_info.flags & DF_BIND_NOW)) return' >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xdw			>> e${EMULATION_NAME}.c

if test -n "$GENERATE_RELRO_SCRIPT" ; then

echo '  ; else if (bfd_link_pie (&link_info)'          >> e${EMULATION_NAME}.c
echo '             && link_info.combreloc'             >> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'         >> e${EMULATION_NAME}.c
echo '             && link_info.one_rosegment'         >> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'         >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xdceor             >> e${EMULATION_NAME}.c

echo '  ; else if (bfd_link_pie (&link_info)'          >> e${EMULATION_NAME}.c
echo '             && link_info.combreloc'             >> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'         >> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'         >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xdceo              >> e${EMULATION_NAME}.c

fi

echo '  ; else if (bfd_link_pie (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'		>> e${EMULATION_NAME}.c
echo '             && link_info.one_rosegment'		>> e${EMULATION_NAME}.c
echo '             && link_info.combreloc) return'	>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xdcer		>> e${EMULATION_NAME}.c

echo '  ; else if (bfd_link_pie (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'		>> e${EMULATION_NAME}.c
echo '             && link_info.combreloc) return'	>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xdce		>> e${EMULATION_NAME}.c

if test -n "$GENERATE_RELRO_SCRIPT" ; then

echo '  ; else if (bfd_link_pie (&link_info)'          >> e${EMULATION_NAME}.c
echo '             && link_info.combreloc'             >> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'         >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xdco               >> e${EMULATION_NAME}.c

fi

echo '  ; else if (bfd_link_pie (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.combreloc) return'	>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xdc			>> e${EMULATION_NAME}.c

if test -n "$GENERATE_RELRO_SCRIPT" ; then

echo '  ; else if (bfd_link_pie (&link_info)'          >> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'         >> e${EMULATION_NAME}.c
echo '             && link_info.one_rosegment'         >> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'         >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xdeor              >> e${EMULATION_NAME}.c

echo '  ; else if (bfd_link_pie (&link_info)'          >> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'         >> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'         >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xdeo               >> e${EMULATION_NAME}.c

fi

fi

echo '  ; else if (bfd_link_pie (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.one_rosegment'	        >> e${EMULATION_NAME}.c
echo '             && link_info.separate_code) return'	>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xder		>> e${EMULATION_NAME}.c

echo '  ; else if (bfd_link_pie (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.separate_code) return'	>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xde			>> e${EMULATION_NAME}.c

if test -n "$GENERATE_RELRO_SCRIPT" ; then

echo '  ; else if (bfd_link_pie (&link_info)'          >> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'         >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xdo                >> e${EMULATION_NAME}.c

fi

echo '  ; else if (bfd_link_pie (&link_info)) return'	>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xd			>> e${EMULATION_NAME}.c
fi

if test -n "$GENERATE_SHLIB_SCRIPT" ; then
if test -n "$GENERATE_COMBRELOC_SCRIPT" ; then

echo '  ; else if (bfd_link_dll (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.combreloc'		>> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'		>> e${EMULATION_NAME}.c
echo '             && link_info.one_rosegment'		>> e${EMULATION_NAME}.c
echo '             && (link_info.flags & DF_BIND_NOW)) return' >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xswer		>> e${EMULATION_NAME}.c

echo '  ; else if (bfd_link_dll (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.combreloc'		>> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'		>> e${EMULATION_NAME}.c
echo '             && (link_info.flags & DF_BIND_NOW)) return' >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xswe		>> e${EMULATION_NAME}.c

echo '  ; else if (bfd_link_dll (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.combreloc'		>> e${EMULATION_NAME}.c
echo '             && link_info.relro'			>> e${EMULATION_NAME}.c
echo '             && (link_info.flags & DF_BIND_NOW)) return' >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xsw			>> e${EMULATION_NAME}.c

if test -n "$GENERATE_RELRO_SCRIPT" ; then

echo '  ; else if (bfd_link_dll (&link_info)'          >> e${EMULATION_NAME}.c
echo '             && link_info.combreloc'             >> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'         >> e${EMULATION_NAME}.c
echo '             && link_info.one_rosegment'         >> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'         >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xsceor             >> e${EMULATION_NAME}.c

echo '  ; else if (bfd_link_dll (&link_info)'          >> e${EMULATION_NAME}.c
echo '             && link_info.combreloc'             >> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'         >> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'         >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xsceo              >> e${EMULATION_NAME}.c

fi

echo '  ; else if (bfd_link_dll (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.combreloc'		>> e${EMULATION_NAME}.c
echo '             && link_info.one_rosegment'		>> e${EMULATION_NAME}.c
echo '             && link_info.separate_code) return'	>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xscer		>> e${EMULATION_NAME}.c

echo '  ; else if (bfd_link_dll (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.combreloc'		>> e${EMULATION_NAME}.c
echo '             && link_info.separate_code) return'	>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xsce			>> e${EMULATION_NAME}.c

if test -n "$GENERATE_RELRO_SCRIPT" ; then

echo '  ; else if (bfd_link_dll (&link_info)'          >> e${EMULATION_NAME}.c
echo '             && link_info.combreloc'             >> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'         >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xsco               >> e${EMULATION_NAME}.c

fi

echo '  ; else if (bfd_link_dll (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.combreloc) return'	>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xsc			>> e${EMULATION_NAME}.c

if test -n "$GENERATE_RELRO_SCRIPT" ; then

echo '  ; else if (bfd_link_dll (&link_info)'          >> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'         >> e${EMULATION_NAME}.c
echo '             && link_info.one_rosegment'         >> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'         >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xseor              >> e${EMULATION_NAME}.c

echo '  ; else if (bfd_link_dll (&link_info)'          >> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'         >> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'         >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xseo               >> e${EMULATION_NAME}.c

fi

fi

echo '  ; else if (bfd_link_dll (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.one_rosegment'   	>> e${EMULATION_NAME}.c
echo '             && link_info.separate_code) return'	>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xser		>> e${EMULATION_NAME}.c

echo '  ; else if (bfd_link_dll (&link_info)'		>> e${EMULATION_NAME}.c
echo '             && link_info.separate_code) return'	>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xse			>> e${EMULATION_NAME}.c

if test -n "$GENERATE_RELRO_SCRIPT" ; then

echo '  ; else if (bfd_link_dll (&link_info)'          >> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'         >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xso               >> e${EMULATION_NAME}.c

fi

echo '  ; else if (bfd_link_dll (&link_info)) return'	>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xs			>> e${EMULATION_NAME}.c

fi

if test -n "$GENERATE_COMBRELOC_SCRIPT" ; then

echo '  ; else if (link_info.combreloc'			>> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'		>> e${EMULATION_NAME}.c
echo '             && (link_info.flags & DF_BIND_NOW)) return' >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xwe			>> e${EMULATION_NAME}.c

echo '  ; else if (link_info.combreloc'			>> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'		>> e${EMULATION_NAME}.c
echo '             && link_info.one_rosegment'		>> e${EMULATION_NAME}.c
echo '             && (link_info.flags & DF_BIND_NOW)) return' >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xwer		>> e${EMULATION_NAME}.c

echo '  ; else if (link_info.combreloc'			>> e${EMULATION_NAME}.c
echo '             && link_info.relro'			>> e${EMULATION_NAME}.c
echo '             && (link_info.flags & DF_BIND_NOW)) return' >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xw			>> e${EMULATION_NAME}.c

if test -n "$GENERATE_RELRO_SCRIPT" ; then

echo '  ; else if (link_info.combreloc'                 >> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'		>> e${EMULATION_NAME}.c
echo '             && link_info.one_rosegment'		>> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'          >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xceor               >> e${EMULATION_NAME}.c

echo '  ; else if (link_info.combreloc'                 >> e${EMULATION_NAME}.c
echo '             && link_info.separate_code'		>> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'          >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xceo                >> e${EMULATION_NAME}.c

fi

echo '  ; else if (link_info.combreloc'			>> e${EMULATION_NAME}.c
echo '             && link_info.one_rosegment'	        >> e${EMULATION_NAME}.c
echo '             && link_info.separate_code) return'	>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xcer		>> e${EMULATION_NAME}.c

echo '  ; else if (link_info.combreloc'			>> e${EMULATION_NAME}.c
echo '             && link_info.separate_code) return'	>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xce			>> e${EMULATION_NAME}.c

if test -n "$GENERATE_RELRO_SCRIPT" ; then

echo '  ; else if (link_info.combreloc'                 >> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'          >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xco                 >> e${EMULATION_NAME}.c

fi

echo '  ; else if (link_info.combreloc) return'		>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xc			>> e${EMULATION_NAME}.c

fi

if test -n "$GENERATE_RELRO_SCRIPT" ; then

echo '  ; else if (link_info.separate_code'             >> e${EMULATION_NAME}.c
echo '             && link_info.one_rosegment'          >> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'          >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xeor                >> e${EMULATION_NAME}.c

echo '  ; else if (link_info.separate_code'             >> e${EMULATION_NAME}.c
echo '             && link_info.relro) return'          >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xeo                 >> e${EMULATION_NAME}.c

fi

echo '  ; else if (link_info.separate_code'             >> e${EMULATION_NAME}.c
echo '             && link_info.one_rosegment) return'  >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xer			>> e${EMULATION_NAME}.c

echo '  ; else if (link_info.separate_code) return'     >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xe			>> e${EMULATION_NAME}.c

if test -n "$GENERATE_RELRO_SCRIPT" ; then

echo '  ; else if (link_info.relro) return'             >> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.xo                  >> e${EMULATION_NAME}.c

fi

echo '  ; else return'					>> e${EMULATION_NAME}.c
sed $sc ldscripts/${EMULATION_NAME}.x			>> e${EMULATION_NAME}.c
echo '; }'						>> e${EMULATION_NAME}.c

else
# Scripts read from the filesystem.

fragment <<EOF
{
  *isfile = 1;

  if (bfd_link_relocatable (&link_info) && config.build_constructors)
    return "ldscripts/${EMULATION_NAME}.xu";
  else if (bfd_link_relocatable (&link_info))
    return "ldscripts/${EMULATION_NAME}.xr";
  else if (!config.text_read_only)
    return "ldscripts/${EMULATION_NAME}.xbn";
EOF
if cmp -s ldscripts/${EMULATION_NAME}.x ldscripts/${EMULATION_NAME}.xn; then :
else
fragment <<EOF
  else if (!config.magic_demand_paged)
    return "ldscripts/${EMULATION_NAME}.xn";
EOF
fi
if test -n "$GENERATE_PIE_SCRIPT" ; then
if test -n "$GENERATE_COMBRELOC_SCRIPT" ; then
fragment <<EOF
  else if (bfd_link_pie (&link_info)
	   && link_info.combreloc
	   && link_info.relro
	   && (link_info.flags & DF_BIND_NOW))
    {
      if (link_info.separate_code)
	{
	  if (link_info.one_rosegment)
	    return "ldscripts/${EMULATION_NAME}.xdwer";
	  else
	    return "ldscripts/${EMULATION_NAME}.xdwe";
	}
      else
	return "ldscripts/${EMULATION_NAME}.xdw";
    }
EOF
if test -n "$GENERATE_RELRO_SCRIPT" ; then
fragment <<EOF
  else if (bfd_link_pie (&link_info)
	   && link_info.combreloc
	   && link_info.relro)
    {
      if (link_info.separate_code)
	{
	  if (link_info.one_rosegment)
	    return "ldscripts/${EMULATION_NAME}.xdceor";
	  else
	    return "ldscripts/${EMULATION_NAME}.xdceo";
	}
      else
	return "ldscripts/${EMULATION_NAME}.xdco";
    }
EOF
fi
fragment <<EOF
  else if (bfd_link_pie (&link_info)
	   && link_info.combreloc)
    {
      if (link_info.separate_code)
	{
	  if (link_info.one_rosegment)
	    return "ldscripts/${EMULATION_NAME}.xdcer";
	  else
	    return "ldscripts/${EMULATION_NAME}.xdce";
	}
      else
	return "ldscripts/${EMULATION_NAME}.xdc";
    }
EOF
fi
if test -n "$GENERATE_RELRO_SCRIPT" ; then
fragment <<EOF
  else if (bfd_link_pie (&link_info)
	   && link_info.relro)
    {
      if (link_info.separate_code)
	{
	  if (link_info.one_rosegment)
	    return "ldscripts/${EMULATION_NAME}.xdeor";
	  else
	    return "ldscripts/${EMULATION_NAME}.xdeo";
	}
      else
	return "ldscripts/${EMULATION_NAME}.xdo";
    }
EOF
fi
fragment <<EOF
  else if (bfd_link_pie (&link_info))
    {
      if (link_info.separate_code)
	{
	  if (link_info.one_rosegment)
	    return "ldscripts/${EMULATION_NAME}.xder";
	  else
	    return "ldscripts/${EMULATION_NAME}.xde";
	}
      else
	return "ldscripts/${EMULATION_NAME}.xd";
    }
EOF
fi
if test -n "$GENERATE_SHLIB_SCRIPT" ; then
if test -n "$GENERATE_COMBRELOC_SCRIPT" ; then
fragment <<EOF
  else if (bfd_link_dll (&link_info) && link_info.combreloc
	   && link_info.relro && (link_info.flags & DF_BIND_NOW))
    {
      if (link_info.separate_code)
	{
	  if (link_info.one_rosegment)
	    return "ldscripts/${EMULATION_NAME}.xswer";
	  else
	    return "ldscripts/${EMULATION_NAME}.xswe";
	}
      else
	return "ldscripts/${EMULATION_NAME}.xsw";
    }
EOF
if test -n "$GENERATE_RELRO_SCRIPT" ; then
fragment <<EOF
  else if (bfd_link_dll (&link_info)
	   && link_info.combreloc
	   && link_info.relro)
    {
      if (link_info.separate_code)
	{
	  if (link_info.one_rosegment)
	    return "ldscripts/${EMULATION_NAME}.xsceor";
	  else
	    return "ldscripts/${EMULATION_NAME}.xsceo";
	}
      else
	return "ldscripts/${EMULATION_NAME}.xsco";
    }
EOF
fi
fragment <<EOF
  else if (bfd_link_dll (&link_info) && link_info.combreloc)
    {
      if (link_info.separate_code)
	{
	  if (link_info.one_rosegment)
	    return "ldscripts/${EMULATION_NAME}.xscer";
	  else
	    return "ldscripts/${EMULATION_NAME}.xsce";
	}
      else
	return "ldscripts/${EMULATION_NAME}.xsc";
    }
EOF
fi
if test -n "$GENERATE_RELRO_SCRIPT" ; then
fragment <<EOF
  else if (bfd_link_dll (&link_info)
	   && link_info.relro)
    {
      if (link_info.separate_code)
	{
	  if (link_info.one_rosegment)
	    return "ldscripts/${EMULATION_NAME}.xseor";
	  else
	    return "ldscripts/${EMULATION_NAME}.xseo";
	}
      else
	return "ldscripts/${EMULATION_NAME}.xso";
    }
EOF
fi
fragment <<EOF
  else if (bfd_link_dll (&link_info))
    {
      if (link_info.separate_code)
	{
	  if (link_info.one_rosegment)
	    return "ldscripts/${EMULATION_NAME}.xser";
	  else
	    return "ldscripts/${EMULATION_NAME}.xse";
	}
      else
	return "ldscripts/${EMULATION_NAME}.xs";
    }
EOF
fi
if test -n "$GENERATE_COMBRELOC_SCRIPT" ; then
fragment <<EOF
  else if (link_info.combreloc && link_info.relro
	   && (link_info.flags & DF_BIND_NOW))
    {
      if (link_info.separate_code)
	{
	  if (link_info.one_rosegment)
	    return "ldscripts/${EMULATION_NAME}.xwer";
	  else
	    return "ldscripts/${EMULATION_NAME}.xwe";
	}
      else
	return "ldscripts/${EMULATION_NAME}.xw";
    }
EOF
if test -n "$GENERATE_RELRO_SCRIPT" ; then
fragment <<EOF
  else if (link_info.combreloc
	   && link_info.relro)
    {
      if (link_info.separate_code)
	{
	  if (link_info.one_rosegment)
	    return "ldscripts/${EMULATION_NAME}.xceor";
	  else
	    return "ldscripts/${EMULATION_NAME}.xceo";
	}
      else
	return "ldscripts/${EMULATION_NAME}.xco";
    }
EOF
fi
fragment <<EOF
  else if (link_info.combreloc)
    {
      if (link_info.separate_code)
	{
	  if (link_info.one_rosegment)
	    return "ldscripts/${EMULATION_NAME}.xcer";
	  else
	    return "ldscripts/${EMULATION_NAME}.xce";
	}
      else
	return "ldscripts/${EMULATION_NAME}.xc";
    }
EOF
fi
if test -n "$GENERATE_RELRO_SCRIPT" ; then
fragment <<EOF
  else if (link_info.relro)
    {
      if (link_info.separate_code)
	{
	  if (link_info.one_rosegment)
	    return "ldscripts/${EMULATION_NAME}.xeor";
	  else
	    return "ldscripts/${EMULATION_NAME}.xeo";
	}
      else
	return "ldscripts/${EMULATION_NAME}.xo";
    }
EOF
fi
fragment <<EOF
  else
    {
      if (link_info.separate_code)
	{
	  if (link_info.one_rosegment)
	    return "ldscripts/${EMULATION_NAME}.xer";
	  else
	    return "ldscripts/${EMULATION_NAME}.xe";
	}
      else
	return "ldscripts/${EMULATION_NAME}.x";
    }
}

EOF
fi
fi

fragment <<EOF

static void
gld${EMULATION_NAME}_add_options
  (int ns, char **shortopts, int nl, struct option **longopts,
   int nrl ATTRIBUTE_UNUSED, struct option **really_longopts ATTRIBUTE_UNUSED)
{
EOF
if test x"$GENERATE_SHLIB_SCRIPT" = xyes; then
fragment <<EOF
  static const char xtra_short[] = "${PARSE_AND_LIST_SHORTOPTS}z:P:";
EOF
else
fragment <<EOF
  static const char xtra_short[] = "${PARSE_AND_LIST_SHORTOPTS}z:";
EOF
fi
fragment <<EOF
  static const struct option xtra_long[] = {
EOF
if test x"$GENERATE_SHLIB_SCRIPT" = xyes; then
fragment <<EOF
    {"audit", required_argument, NULL, OPTION_AUDIT},
    {"Bgroup", no_argument, NULL, OPTION_GROUP},
EOF
fi
fragment <<EOF
    {"build-id", optional_argument, NULL, OPTION_BUILD_ID},
    {"package-metadata", optional_argument, NULL, OPTION_PACKAGE_METADATA},
    {"compress-debug-sections", required_argument, NULL, OPTION_COMPRESS_DEBUG},
    {"rosegment", no_argument, NULL, OPTION_ROSEGMENT},
    {"no-rosegment", no_argument, NULL, OPTION_NO_ROSEGMENT},
EOF
if test x"$GENERATE_SHLIB_SCRIPT" = xyes; then
fragment <<EOF
    {"depaudit", required_argument, NULL, 'P'},
    {"disable-new-dtags", no_argument, NULL, OPTION_DISABLE_NEW_DTAGS},
    {"enable-new-dtags", no_argument, NULL, OPTION_ENABLE_NEW_DTAGS},
    {"eh-frame-hdr", no_argument, NULL, OPTION_EH_FRAME_HDR},
    {"no-eh-frame-hdr", no_argument, NULL, OPTION_NO_EH_FRAME_HDR},
    {"exclude-libs", required_argument, NULL, OPTION_EXCLUDE_LIBS},
    {"hash-style", required_argument, NULL, OPTION_HASH_STYLE},
EOF
fi
if test -n "$PARSE_AND_LIST_LONGOPTS" ; then
fragment <<EOF
    $PARSE_AND_LIST_LONGOPTS
EOF
fi
fragment <<EOF
    {NULL, no_argument, NULL, 0}
  };

  *shortopts = (char *) xrealloc (*shortopts, ns + sizeof (xtra_short));
  memcpy (*shortopts + ns, &xtra_short, sizeof (xtra_short));
  *longopts = (struct option *)
    xrealloc (*longopts, nl * sizeof (struct option) + sizeof (xtra_long));
  memcpy (*longopts + nl, &xtra_long, sizeof (xtra_long));
}

#define DEFAULT_BUILD_ID_STYLE	"sha1"

static bool
gld${EMULATION_NAME}_handle_option (int optc)
{
  switch (optc)
    {
    default:
      return false;

    case OPTION_BUILD_ID:
      free ((char *) ldelf_emit_note_gnu_build_id);
      ldelf_emit_note_gnu_build_id = NULL;
      if (optarg == NULL)
	optarg = DEFAULT_BUILD_ID_STYLE;
      if (strcmp (optarg, "none"))
	ldelf_emit_note_gnu_build_id = xstrdup (optarg);
      break;

    case OPTION_PACKAGE_METADATA:
      free ((char *) ldelf_emit_note_fdo_package_metadata);
      ldelf_emit_note_fdo_package_metadata = NULL;
      if (optarg != NULL && strlen(optarg) > 0)
	ldelf_emit_note_fdo_package_metadata = xstrdup (optarg);
      break;

    case OPTION_COMPRESS_DEBUG:
      config.compress_debug = bfd_get_compression_algorithm (optarg);
      if (strcasecmp (optarg, "zstd") == 0)
	{
#ifndef HAVE_ZSTD
	  if (config.compress_debug == COMPRESS_DEBUG_ZSTD)
	    einfo (_ ("%F%P: --compress-debug-sections=zstd: ld is not built "
		  "with zstd support\n"));
#endif
	}
      if (config.compress_debug == COMPRESS_UNKNOWN)
	einfo (_("%F%P: invalid --compress-debug-sections option: \`%s'\n"),
	       optarg);
      break;

    case OPTION_ROSEGMENT:
      link_info.one_rosegment = true;
      break;
    case OPTION_NO_ROSEGMENT:
      link_info.one_rosegment = false;
      break;      
EOF

if test x"$GENERATE_SHLIB_SCRIPT" = xyes; then
fragment <<EOF
    case OPTION_AUDIT:
	ldelf_append_to_separated_string (&audit, optarg);
	break;

    case 'P':
	ldelf_append_to_separated_string (&depaudit, optarg);
	break;

    case OPTION_DISABLE_NEW_DTAGS:
      link_info.new_dtags = false;
      break;

    case OPTION_ENABLE_NEW_DTAGS:
      link_info.new_dtags = true;
      break;

    case OPTION_EH_FRAME_HDR:
      link_info.eh_frame_hdr_type = DWARF2_EH_HDR;
      break;

    case OPTION_NO_EH_FRAME_HDR:
      link_info.eh_frame_hdr_type = 0;
      break;

    case OPTION_GROUP:
      link_info.flags_1 |= (bfd_vma) DF_1_GROUP;
      /* Groups must be self-contained.  */
      link_info.unresolved_syms_in_objects = RM_DIAGNOSE;
      link_info.unresolved_syms_in_shared_libs = RM_DIAGNOSE;
      break;

    case OPTION_EXCLUDE_LIBS:
      add_excluded_libs (optarg);
      break;

    case OPTION_HASH_STYLE:
      link_info.emit_hash = false;
      link_info.emit_gnu_hash = false;
      if (strcmp (optarg, "sysv") == 0)
	link_info.emit_hash = true;
      else if (strcmp (optarg, "gnu") == 0)
	link_info.emit_gnu_hash = true;
      else if (strcmp (optarg, "both") == 0)
	{
	  link_info.emit_hash = true;
	  link_info.emit_gnu_hash = true;
	}
      else
	einfo (_("%F%P: invalid hash style \`%s'\n"), optarg);
      break;

EOF
fi
fragment <<EOF
    case 'z':
      if (strcmp (optarg, "defs") == 0)
	link_info.unresolved_syms_in_objects = RM_DIAGNOSE;
      else if (strcmp (optarg, "undefs") == 0)
	link_info.unresolved_syms_in_objects = RM_IGNORE;
      else if (strcmp (optarg, "muldefs") == 0)
	link_info.allow_multiple_definition = true;
      else if (startswith (optarg, "max-page-size="))
	{
	  char *end;

	  link_info.maxpagesize = strtoul (optarg + 14, &end, 0);
	  if (*end
	      || (link_info.maxpagesize & (link_info.maxpagesize - 1)) != 0)
	    einfo (_("%F%P: invalid maximum page size \`%s'\n"),
		   optarg + 14);
	  link_info.maxpagesize_is_set = true;
	}
      else if (startswith (optarg, "common-page-size="))
	{
	  char *end;
	  link_info.commonpagesize = strtoul (optarg + 17, &end, 0);
	  if (*end
	      || (link_info.commonpagesize & (link_info.commonpagesize - 1)) != 0)
	    einfo (_("%F%P: invalid common page size \`%s'\n"),
		   optarg + 17);
	  link_info.commonpagesize_is_set = true;
	}
      else if (startswith (optarg, "stack-size="))
	{
	  char *end;
	  link_info.stacksize = strtoul (optarg + 11, &end, 0);
	  if (*end || link_info.stacksize < 0)
	    einfo (_("%F%P: invalid stack size \`%s'\n"), optarg + 11);
	  if (!link_info.stacksize)
	    /* Use -1 for explicit no-stack, because zero means
	       'default'.   */
	    link_info.stacksize = -1;
	}
      else if (strcmp (optarg, "execstack") == 0)
	{
	  link_info.execstack = true;
	  link_info.noexecstack = false;
	}
      else if (strcmp (optarg, "noexecstack") == 0)
	{
	  link_info.noexecstack = true;
	  link_info.execstack = false;
	}
      else if (strcmp (optarg, "unique-symbol") == 0)
	link_info.unique_symbol = true;
      else if (strcmp (optarg, "nounique-symbol") == 0)
	link_info.unique_symbol = false;
      else if (strcmp (optarg, "globalaudit") == 0)
	{
	  link_info.flags_1 |= DF_1_GLOBAUDIT;
	}
      else if (startswith (optarg, "start-stop-gc"))
	link_info.start_stop_gc = true;
      else if (startswith (optarg, "nostart-stop-gc"))
	link_info.start_stop_gc = false;
      else if (startswith (optarg, "start-stop-visibility="))
	{
	  if (strcmp (optarg, "start-stop-visibility=default") == 0)
	    link_info.start_stop_visibility = STV_DEFAULT;
	  else if (strcmp (optarg, "start-stop-visibility=internal") == 0)
	    link_info.start_stop_visibility = STV_INTERNAL;
	  else if (strcmp (optarg, "start-stop-visibility=hidden") == 0)
	    link_info.start_stop_visibility = STV_HIDDEN;
	  else if (strcmp (optarg, "start-stop-visibility=protected") == 0)
	    link_info.start_stop_visibility = STV_PROTECTED;
	  else
	    einfo (_("%F%P: invalid visibility in \`-z %s'; "
		     "must be default, internal, hidden, or protected"),
		   optarg);
	}
      else if (strcmp (optarg, "sectionheader") == 0)
	config.no_section_header = false;
      else if (strcmp (optarg, "nosectionheader") == 0)
	config.no_section_header = true;
EOF

if test x"$GENERATE_SHLIB_SCRIPT" = xyes; then
fragment <<EOF
      else if (strcmp (optarg, "global") == 0)
	link_info.flags_1 |= (bfd_vma) DF_1_GLOBAL;
      else if (strcmp (optarg, "initfirst") == 0)
	link_info.flags_1 |= (bfd_vma) DF_1_INITFIRST;
      else if (strcmp (optarg, "interpose") == 0)
	link_info.flags_1 |= (bfd_vma) DF_1_INTERPOSE;
      else if (strcmp (optarg, "loadfltr") == 0)
	link_info.flags_1 |= (bfd_vma) DF_1_LOADFLTR;
      else if (strcmp (optarg, "nodefaultlib") == 0)
	link_info.flags_1 |= (bfd_vma) DF_1_NODEFLIB;
      else if (strcmp (optarg, "nodelete") == 0)
	link_info.flags_1 |= (bfd_vma) DF_1_NODELETE;
      else if (strcmp (optarg, "nodlopen") == 0)
	link_info.flags_1 |= (bfd_vma) DF_1_NOOPEN;
      else if (strcmp (optarg, "nodump") == 0)
	link_info.flags_1 |= (bfd_vma) DF_1_NODUMP;
      else if (strcmp (optarg, "now") == 0)
	{
	  link_info.flags |= (bfd_vma) DF_BIND_NOW;
	  link_info.flags_1 |= (bfd_vma) DF_1_NOW;
	}
      else if (strcmp (optarg, "lazy") == 0)
	{
	  link_info.flags &= ~(bfd_vma) DF_BIND_NOW;
	  link_info.flags_1 &= ~(bfd_vma) DF_1_NOW;
	}
      else if (strcmp (optarg, "origin") == 0)
	{
	  link_info.flags |= (bfd_vma) DF_ORIGIN;
	  link_info.flags_1 |= (bfd_vma) DF_1_ORIGIN;
	}
      else if (strcmp (optarg, "unique") == 0)
	link_info.gnu_flags_1 |= (bfd_vma) DF_GNU_1_UNIQUE;
      else if (strcmp (optarg, "nounique") == 0)
	link_info.gnu_flags_1 &= ~(bfd_vma) DF_GNU_1_UNIQUE;
      else if (strcmp (optarg, "combreloc") == 0)
	link_info.combreloc = true;
      else if (strcmp (optarg, "nocombreloc") == 0)
	link_info.combreloc = false;
      else if (strcmp (optarg, "nocopyreloc") == 0)
	link_info.nocopyreloc = true;
        else if (strcmp (optarg, "use-gs-for-tls") == 0)
  link_info.use_gs_for_tls = TRUE;
EOF
if test -n "$COMMONPAGESIZE"; then
fragment <<EOF
      else if (strcmp (optarg, "relro") == 0)
	link_info.relro = true;
      else if (strcmp (optarg, "norelro") == 0)
	link_info.relro = false;
EOF
fi
fragment <<EOF
      else if (strcmp (optarg, "separate-code") == 0)
	link_info.separate_code = true;
      else if (strcmp (optarg, "noseparate-code") == 0)
	link_info.separate_code = false;
      else if (strcmp (optarg, "common") == 0)
	link_info.elf_stt_common = elf_stt_common;
      else if (strcmp (optarg, "nocommon") == 0)
	link_info.elf_stt_common = no_elf_stt_common;
      else if (strcmp (optarg, "text") == 0)
	link_info.textrel_check = textrel_check_error;
      else if (strcmp (optarg, "notext") == 0)
	link_info.textrel_check = textrel_check_none;
      else if (strcmp (optarg, "textoff") == 0)
	link_info.textrel_check = textrel_check_none;
EOF
fi

if test -n "$PARSE_AND_LIST_ARGS_CASE_Z" ; then
fragment <<EOF
 $PARSE_AND_LIST_ARGS_CASE_Z
EOF
fi

fragment <<EOF
      else
	queue_unknown_cmdline_warning ("-z %s", optarg);
      break;
EOF

if test -n "$PARSE_AND_LIST_ARGS_CASES" ; then
fragment <<EOF
 $PARSE_AND_LIST_ARGS_CASES
EOF
fi

fragment <<EOF
    }

  return true;
}

EOF

if test x"$LDEMUL_LIST_OPTIONS" != xgld"$EMULATION_NAME"_list_options; then
gld_list_options="gld${EMULATION_NAME}_list_options"
if test -n "$PARSE_AND_LIST_OPTIONS"; then
fragment <<EOF

static void
gld${EMULATION_NAME}_list_options (FILE * file)
{
EOF

if test -n "$PARSE_AND_LIST_OPTIONS" ; then
fragment <<EOF
 $PARSE_AND_LIST_OPTIONS
EOF
fi

fragment <<EOF
}
EOF
else
  gld_list_options="NULL"
fi

if test -n "$PARSE_AND_LIST_EPILOGUE" ; then
fragment <<EOF
 $PARSE_AND_LIST_EPILOGUE
EOF
fi
fi

LDEMUL_AFTER_PARSE=${LDEMUL_AFTER_PARSE-ldelf_after_parse}
LDEMUL_BEFORE_PLUGIN_ALL_SYMBOLS_READ=${LDEMUL_BEFORE_PLUGIN_ALL_SYMBOLS_READ-gld${EMULATION_NAME}_before_plugin_all_symbols_read}
LDEMUL_AFTER_OPEN=${LDEMUL_AFTER_OPEN-gld${EMULATION_NAME}_after_open}
LDEMUL_BEFORE_PLACE_ORPHANS=${LDEMUL_BEFORE_PLACE_ORPHANS-ldelf_before_place_orphans}
LDEMUL_AFTER_ALLOCATION=${LDEMUL_AFTER_ALLOCATION-gld${EMULATION_NAME}_after_allocation}
LDEMUL_SET_OUTPUT_ARCH=${LDEMUL_SET_OUTPUT_ARCH-ldelf_set_output_arch}
LDEMUL_BEFORE_ALLOCATION=${LDEMUL_BEFORE_ALLOCATION-gld${EMULATION_NAME}_before_allocation}
LDEMUL_OPEN_DYNAMIC_ARCHIVE=${LDEMUL_OPEN_DYNAMIC_ARCHIVE-ldelf_open_dynamic_archive}
LDEMUL_PLACE_ORPHAN=${LDEMUL_PLACE_ORPHAN-ldelf_place_orphan}
LDEMUL_ADD_OPTIONS=gld${EMULATION_NAME}_add_options
LDEMUL_HANDLE_OPTION=gld${EMULATION_NAME}_handle_option
LDEMUL_LIST_OPTIONS=${LDEMUL_LIST_OPTIONS-${gld_list_options}}
LDEMUL_RECOGNIZED_FILE=${LDEMUL_RECOGNIZED_FILE-ldelf_load_symbols}

source_em ${srcdir}/emultempl/emulation.em
