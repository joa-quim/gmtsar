/*	$Id$	*/
/*******************************************************************************
 * Update a parameter in the PRM file and write it out.                        *
 * Replaces update_PRM.csh with more robust C-code                             *
 * Uses routines written by Anders Hogrelius.                                  *
 *******************************************************************************/
/********************************************************************************
 * Creator:  David Sandwell, July 27, 2018
 *										*
 * Date   :  06/07/2007 *
 ********************************************************************************/
#include "update_PRM.h"
#include "gmtsar.h"
#include "gmtsar_commands.h"

static const char *update_PRM_usage = "\nUsage: update_PRM file.PRM parameter value \n";

int gmtsar_update_PRM_run(const char *prmfile, const char *parameter, const char *value) {
	update_PRM_sub((char *)prmfile, (char *)parameter, (char *)value);
	return 0;
}

int gmtsar_update_PRM(int argc, char **argv) {
	if (argc < 4)
		die((char *)update_PRM_usage, "");
	return gmtsar_update_PRM_run(argv[1], argv[2], argv[3]);
}
