#
# Setup yacc-alike to build the parser for the config file.
#
# Similarly to the _lex handler, we always use your yacc to build it if
# you have one.  If you don't we can fallback to a prebuilt one, else
# die.

# Setup flags, and have an escape to debug the parser, if that's ever
# useful.
set(YFLAGS -d -b gram)
if(DO_DEBUGPARSER)
	list(APPEND YFLAGS -t -v)
	add_definitions(-DYYEBUG=1)
	message(STATUS "Enabling config parser debug.")
endif(DO_DEBUGPARSER)

# This only finds bison, not yacc.
find_package(BISON)
if(BISON_FOUND)
	BISON_TARGET(ctwm_parser gram.y ${CMAKE_CURRENT_BINARY_DIR}/gram.tab.c
		COMPILE_FLAGS ${YFLAGS})
else()
	# There doesn't seem to be a standard module for yacc, so hand-code
	# it.
	find_program(YACC yacc)
	if(YACC)
		# Got yacc(1), use it
		message(STATUS "Found yacc: ${YACC}")
		add_custom_command(OUTPUT gram.tab.c gram.tab.h
			DEPENDS gram.y
			COMMAND ${YACC} ${YFLAGS} ${CMAKE_CURRENT_SOURCE_DIR}/gram.y
		)
	else()
		# No bison, no yacc.  Maybe there are prebuilt files?
		find_file(GRAM_C gram.tab.c
			PATHS ${GENSRCDIR} NO_DEFAULT_PATH)
		find_file(GRAM_H gram.tab.h
			PATHS ${GENSRCDIR} NO_DEFAULT_PATH)
		if(GRAM_C AND GRAM_H)
			# Got prebuilt ones, use 'em
			message(STATUS "No yacc found, using prebuilt gram.tab.*")
			add_custom_command(OUTPUT gram.tab.h
				DEPENDS ${GRAM_H}
				COMMAND cp ${GRAM_H} .
			)
			add_custom_command(OUTPUT gram.tab.c
				DEPENDS ${GRAM_C}
				COMMAND cp ${GRAM_C} .
			)
			# Also need to explicitly tell cmake; otherwise it knows to
			# pull in gram.tab.c ('cuz it's in CTWMSRC) but doesn't know
			# in time to pull in gram.tab.h and so blows up.
			set_source_files_properties(gram.tab.c OBJECT_DEPENDS gram.tab.h)
		else()
			# No bison, no yacc, no prebuilt.  Boom.
			message(FATAL_ERROR "Can't find yacc.")
		endif(GRAM_C AND GRAM_H)
	endif(YACC)
endif(BISON_FOUND)
