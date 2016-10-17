#!/bin/sh
#
# $0 ../function_defs.list OUTDIR
#
# Generates output files with various defs and lookup arrays.

infile="$1"
outdir="$2"

if [ -z "${infile}" -o ! -r "${infile}" ]; then
	echo "No infile."
	exit 1
fi

if [ -z "${outdir}" -o ! -d "${outdir}" ]; then
	echo "No outdir."
	exit 1
fi


# We're all C here
print_header() {
	echo "/*"
	echo " * AUTOGENERATED FILE -- DO NOT EDIT"
	echo " * This file is generated automatically by $0"
	echo " * from '${infile}'"
	echo " * during the build process."
	echo " */"
	echo
}


# Getting one section out of the input file
getsect() {
	# We presume we always want to clear out the comments and blank lines
	# anyway, so stick that in here.  And I think we always end up
	# sorting too, so do that as well.
	sed -e "1,/^# START($1)/d" -e "/^# END($1)/,\$d" \
		-e 's/#.*//' -e '/^[[:space:]]*$/d' \
		${infile} | sort
}



#
# First off, creating the F_ defines.
#
gf="${outdir}/functions_defs.h"
(
	print_header
	echo "/* Definitions for functions */"
	echo
	echo "#define F_NOP 0    /* Hardcoded magic value */"
	echo

	counter=1

	echo "/* Standard functions */"
	while read func ctype ifdef
	do
		# f.nop is special cased to always be 0, so skip it when we
		# encounter it in here.
		if [ "X${func}" = "XNOP" ]; then
			continue;
		fi


		# Output #define, possible guarded by #ifdef's, with a comment to
		# note the ones that take string args.
		if [ "X${ifdef}" != "X-" ]; then
			echo "#ifdef ${ifdef}"
		fi

		cmt=" //"
		if [ "X${ctype}" = "XS" ]; then
			cmt="${cmt} string"
		fi
		if [ "X${cmt}" = "X //" ]; then
			cmt=""
		fi

		printf "#define F_%-21s %3d${cmt}\n" "${func}" "${counter}"

		if [ "X${ifdef}" != "X-" ]; then
			echo "#endif"
		fi
		counter=$((counter+1))
	done << EOF
	$(getsect main \
		| awk '{printf "%s %s %s\n", toupper($1), $2, $4;}')
EOF

	echo
	echo "/* Synthetic functions */"
	while read func
	do
		printf "#define F_%-21s %3d\n" "${func}" "${counter}"
		counter=$((counter+1))
	done << EOF
	$(getsect synthetic \
		| awk '{printf "%s\n", toupper($1)}')
EOF

) > ${gf}
#echo "Generated ${gf}"



#
# Next, setup the deferral lookup struct for function execution
#
gf="${outdir}/functions_deferral.h"
(
	print_header
	cat << EOF

#ifndef _CTWM_FUNCTIONS_DEFERRAL_H
#define _CTWM_FUNCTIONS_DEFERRAL_H

/* Functions deferral lookup */
typedef enum {
	DC_NONE = 0,
	DC_SELECT,
	DC_MOVE,
	DC_DESTROY,
} _fdef_table_cursor;

static const _fdef_table_cursor fdef_table[] = {
EOF

	while read func curs
	do
		if [ "X${func}" = "X" ]; then
			echo "Got no function!"
			exit 1
		fi

		scurs=""
		if [ "X${curs}" = "XCS" ]; then scurs="DC_SELECT"; fi
		if [ "X${curs}" = "XCM" ]; then scurs="DC_MOVE"; fi
		if [ "X${curs}" = "XCD" ]; then scurs="DC_DESTROY"; fi

		if [ "X${scurs}" = "X" ]; then
			echo "Invalid: unexpected cursor '${curs}' for '${func}'!"
			exit 1
		fi

		printf "\t%-23s = %s,\n" "[F_${func}]" "${scurs}"
	done << EOF
	$(getsect main \
		| awk '{ if ($3 != "-") {printf "%s %s\n", toupper($1), $3;} }')
EOF

	cat << EOF
};

static const size_t fdef_table_max = (sizeof(fdef_table) / sizeof(fdef_table[0]));

#endif // _CTWM_FUNCTIONS_DEFERRAL_H
EOF

) > ${gf}
#echo "Generated ${gf}"



#
# Now the keyword table for the config file parser.  This is somewhat
# more involved because it needs the entries from the main as well as
# alias sections, but it needs to have them together in a single
# ASCIIbetized list.
#
gf="${outdir}/functions_parse_table.h"
(
	# So we better start by pulling the main section, and stashing up
	# its rules.
	while read func ctype ifdef fdef
	do
		eval _STASH_${func}_ctype=\"$ctype\"
		eval _STASH_${func}_ifdef=\"$ifdef\"
		eval _STASH_${func}_fdef=\"$fdef\"
	done << EOF
	$(getsect main \
		| awk '{ printf "%s %s %s %s\n", $1, $2, $4, toupper($1) }')
EOF
	# Adding and stashing the extra toupper() there instead of calling
	# tr(1) in the loop below saves more than a quarter of a second
	# (which is ~quintuple the runtime without it).


	# Now run 'em both together and output
	print_header
	echo "/* Parser table for functions */"
	echo "static const TwmKeyword funckeytable[] = {"

	while read func alias
	do
		# Look up pieces
		luf=$func
		cmt=""
		if [ "X${alias}" != "X" ]; then
			luf=$alias
			cmt=" // -> f.${alias}"
		fi

		eval _ctype=\$_STASH_${luf}_ctype
		eval ifdef=\$_STASH_${luf}_ifdef
		eval fdef=\$_STASH_${luf}_fdef

		ctype="FKEYWORD"
		if [ "X${_ctype}" = "XS" ]; then
			ctype="FSKEYWORD"
		fi


		# Output
		if [ "X${ifdef}" != "X-" ]; then
			echo "#ifdef ${ifdef}"
		fi

		printf "\t{ %-24s %10s %s },%s\n" "\"f.${func}\"," "${ctype}," \
			"F_${fdef}" "${cmt}"

		if [ "X${ifdef}" != "X-" ]; then
			echo "#endif"
		fi
	done << EOF
	$( ( getsect main    | awk '{printf "%s\n",    $1}' ;
	     getsect aliases | awk '{printf "%s %s\n", $1, $2}'
	   ) | sort)
EOF

	echo "};"
	echo
	echo "static const size_t numfunckeywords = (sizeof(funckeytable) / " \
			"sizeof(funckeytable[0]));"
) > ${gf}
#echo "Generated ${gf}"
