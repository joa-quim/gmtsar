/*----------------------------------------------------------------------*/
/* NAME									*/
/*	ers_line_fixer - fixes lines in an ERS SAR raw data file	*/
/*									*/
/* SYNOPSIS								*/
/*	ers_line_fixer [ -a ] [ -h header ] [ -l line ] [ -s station ]	*/
/*		<raw file...> <fixed file>				*/
/*									*/
/* DESCRIPTION								*/
/*	The ers_line_fixer program reads in ERS SAR raw data files	*/
/*	and produces a single "preprocessed" ERS SAR data file.		*/
/*	Missing	lines are "replaced" by the next available line.	*/
/*									*/
/* OPTIONS								*/
/*	-a	Align the lines by shifting them so they all have the	*/
/*		same sampling window start time.			*/
/*									*/
/*	-h header							*/
/*		Sets the number of bytes per header to be <header>.	*/
/*		If this option is not specified, the program will use	*/
/*		the header length for the specified station, or the	*/
/*		default header length.					*/
/*									*/
/*	-l line								*/
/*		Sets the number of bytes per line to be <line>.  If	*/
/*		this option is not specified, the program will use the	*/
/*		line length for the specified station, or attempt to	*/
/*		determine the line length.				*/
/*									*/
/*	-s station							*/
/*		Indicates the input file station.  If this option is	*/
/*		not specified, the program will use the default		*/
/*		station.						*/
/*----------------------------------------------------------------------*/
/*  DEC 29, 2010 - Modified for little endian computer.                 */
/*                 Does not change byte order on output.                */
/*  Jan 23, 2011 - Modified to read near range instead of swst          */
/*  JUL 02, 2020 - modified to suppress bit 24 in the ifc counter       */

#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <time.h>
#include <unistd.h>

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>

#define SWAP_2(x) ((((x)&0xff) << 8) | ((unsigned short)(x) >> 8))
#define SWAP_4(x) (((x) << 24) | (((x) << 8) & 0x00ff0000) | (((x) >> 8) & 0x0000ff00) | ((x) >> 24))
#define FIX_SHORT(x) (*(unsigned short *)&(x) = SWAP_2(*(unsigned short *)&(x)))
#define FIX_INT(x) (*(unsigned int *)&(x) = SWAP_4(*(unsigned int *)&(x)))
#define FIX_FLOAT(x) FIX_INT(x)

#define OPTSTRING "a:h:l:s:"

/* for assessing unknown stations */
#define UNKNOWN "Unknown"
#define MIN_LINE_SIZE 10000
#define MAX_LINE_SIZE 13000
#define MIN_PRF 1640.0
#define MAX_PRF 1720.0
#define DEFAULT_HEADER_SIZE 412
#define CHECK_LINES 5   /* number of lines to check */
#define MISSING_LINES 1 /* OK # of missing lines */

#define MAX_GAP 900 /* max consec. missing lines */

#define SWST_OFFSET 4 /* bytes from ifc to swst */
#define PRI_OFFSET 6  /* bytes from ifc to pri */

#define IFC_SIZE 4  /* four bytes per ifc */
#define SWST_SIZE 2 /* two bytes per swst */
#define PRI_SIZE 2  /* two bytes per pri */

#define SEC_PER_PRI_COUNT 210.94e-09
#define SOL 299792456.0

/*-----------*/
/* FUNCTIONS */
/*-----------*/

void readline(int ifd, char *data, int line_length, char *command, char *filename, int line_number);
void writeline(int ofd, char *data, int line_length, char *command, char *filename, int line_number);
int determine_info(char *command, char *filename, int station_index);
int try_info(int ifd, int line_length, int ifc_index);
double calc_pri(unsigned short pri_dn);
double calc_swst(unsigned short swst_dn, double pri);
int range2swst(double range, double pri);
void underline(FILE *ofp, int count, char character);
void usage(char *command, int exit_code);
int is_big_endian_(void);
int is_big_endian__(void);

/*-----------------------------*/
/* PROCESSING SITE INFORMATION */
/*-----------------------------*/

typedef struct station_info {
	char *station_name;
	int line_length;
	int header_length;
	int ifc_index;  /* image format counter */
	int swst_index; /* sampling window start time */
	int pri_index;  /* pulse repetition interval */
} Station_Info;

Station_Info station[] = {{"DPAF/ESRIN", 11644, 412, 210, 214, 216},  {"CO", 11644, 416, 214, 218, 220},
                          {"EIC", 11644, 410, 198, 202, 204},         {"UK", 11644, 412, 210, 214, 216},
                          {"CCRS", 12060, 412, 200, 204, 206},        {"ASF", 11474, 242, 200, 204, 206},
                          {UNKNOWN, 0, DEFAULT_HEADER_SIZE, 0, 0, 0}, {NULL, 0, 0, 0, 0, 0}};

/*------------------*/
/* OPTION VARIABLES */
/*------------------*/

char opt_adjust, opt_line, opt_header, opt_station;

/*==========================*/
/* MAIN PROGRAM: line_fixer */
/*==========================*/

int main(int argc, char *argv[]) {
	char *output_filename, *station_name, *filename, *data, *data_buf;
	char **input_filenames;
	unsigned short swst_dn, old_swst_dn, swst_dn1 = 0, pri_dn, old_pri_dn;
	int station_index, c, header_length = 0, line_length = 0, match_count;
	int i, input_filecount, ifc_index, swst_index, pri_index, file_index;
	int file_size, line_count, input_line_number, ifc, lines_to_write;
	int old_ifc, shift_bytes, old_shift_bytes, output_line_number = 0;
	int char_count, ignore_flag;
	int ofd, ifd = 0;
	int endian;
	int itest = 0;
	int pcount; /* actual count of data pixels */
	double pri, swst;
	double near_range, near_range_in = 0.0;
	extern char *optarg;
	extern int optind;

	/*------------------------*/
	/* check endian           */
	/*------------------------*/

	endian = is_big_endian_();
	printf("\ncheck endian on this computer: (1 big or -1 little) %d \n", endian);

	/*------------------------*/
	/* parse the command line */
	/*------------------------*/

	station_index = 0; /* the first station is the default */
	while ((c = getopt(argc, argv, OPTSTRING)) != -1) {
		switch (c) {
		case 'a':
			opt_adjust = 1;
			near_range_in = atof(optarg);
			break;
		case 'h':
			opt_header = 1;
			header_length = atoi(optarg);
			break;
		case 'l':
			opt_line = 1;
			line_length = atoi(optarg);
			break;
		case 's':
			opt_station = 1;
			match_count = 0;
			for (i = 0; station[i].station_name; i++) {
				if (strcasecmp(optarg, station[i].station_name) == 0) {
					station_index = i;
					match_count = 1;
					break;
				}
			}
			if (match_count != 1) {
				printf("%s ERROR: station %s is unknown\n", argv[0], optarg);
				exit(1);
			}
			break;
		case '?':
			usage(argv[0], 1);
			break;
		}
	}

	if (argc < optind + 2)
		usage(argv[0], 1);

	input_filenames = argv + optind;
	input_filecount = argc - optind - 1;
	output_filename = argv[argc - 1];

	/*------------------*/
	/* open output file */
	/*------------------*/

	ofd = open(output_filename, O_WRONLY | O_CREAT | O_EXCL, 0644);
	if (ofd == -1) {
		switch (errno) {
		case EACCES:
			printf("%s ERROR: can't write to output file (%s) parent directory\n", argv[0], output_filename);
			break;
		case EEXIST:
			printf("%s ERROR: output file (%s) already exists (I don't clobber)\n", argv[0], output_filename);
			break;
		default:
			printf("%s ERROR: error opening output file (%s)\n", argv[0], output_filename);
			break;
		}
		exit(1);
	}

	/*-----------------------------*/
	/* override station parameters */
	/*-----------------------------*/
	if (opt_line)
		station[station_index].line_length = line_length;

	if (opt_header)
		station[station_index].header_length = header_length;

	/*------------------------------------*/
	/* if unknown station, determine type */
	/*------------------------------------*/

	if (strcasecmp(UNKNOWN, station[station_index].station_name) == 0) {
		printf("\n");
		char_count = printf("Using %s to determine station information\n", *input_filenames);
		underline(stdout, char_count - 1, '-');
		determine_info(argv[0], *input_filenames, station_index);
	}

	/*--------------------------------*/
	/* set variables based on station */
	/*--------------------------------*/
	line_length = station[station_index].line_length;
	header_length = station[station_index].header_length;
	station_name = station[station_index].station_name;
	ifc_index = station[station_index].ifc_index;
	swst_index = station[station_index].swst_index;
	pri_index = station[station_index].pri_index;

	/*----------------*/
	/* print out info */
	/*----------------*/

	printf("\n");
	printf("      Station: %s\n", station_name);
	printf("  Line Length: %d\n", line_length);
	printf("Header Length: %d\n", header_length);
	printf("    IFC Index: %d\n", ifc_index);
	printf("   SWST Index: %d\n", swst_index);
	printf("    PRI Index: %d\n", pri_index);

	/*----------------------------*/
	/* allocate memory for a line */
	/*----------------------------*/

	data = (char *)malloc(line_length);
	if (data == 0) {
		printf("%s ERROR: error allocating line memory (%d bytes)\n", argv[0], line_length);
		exit(1);
	}
	data_buf = (char *)malloc(line_length);
	if (data_buf == 0) {
		printf("%s ERROR: error allocating line memory (%d bytes)\n", argv[0], line_length);
		exit(1);
	}

	/*------------*/
	/* initialize */
	/*------------*/

	old_shift_bytes = 0;
	old_ifc = 0;
	old_pri_dn = 0;
	old_swst_dn = 0;
	ignore_flag = 0;

	/*------------------------------------*/
	/* process file by file, line by line */
	/*------------------------------------*/

	printf("\n");
	char_count = printf("Writing to fixed data file %s\n", output_filename);
	underline(stdout, char_count - 1, '-');
	for (file_index = 0; file_index < input_filecount; file_index++) {
		filename = *(input_filenames + file_index);
		ifd = open(filename, O_RDONLY);
		if (ifd == -1) {
			printf("%s ERROR: error opening input file %s\n", argv[0], filename);
			exit(1);
		}
		file_size = lseek(ifd, 0, SEEK_END);
		line_count = file_size / line_length;

		printf("\n");
		printf("INPUT FILE: %s\n", filename);
		printf("LINE COUNT: %d\n", line_count);

		/*---------------------------*/
		/* do something with headers */
		/*---------------------------*/

		lseek(ifd, 0, SEEK_SET);
		readline(ifd, data, line_length, argv[0], filename, 0);
		if (file_index == 0) {
			printf("  Transferring header.\n");
			writeline(ofd, data, line_length, argv[0], output_filename, 0);
		}
		else
			printf("  Discarding header.\n");

		/*-------------------*/
		/* read line by line */
		/*-------------------*/

		for (input_line_number = 1; input_line_number < line_count; input_line_number++) {
			memcpy(data_buf, data, line_length);
			readline(ifd, data, line_length, argv[0], filename, input_line_number);

			/*----------------------------------------------------*/
			/* swap bytes on the pixel count for esarp            */
			/* note this is the ONLY field that gets a byte swap. */
			/*----------------------------------------------------*/

			memcpy((char *)&pcount, data + 24, 4);
			if (endian == -1)
				FIX_INT(pcount);
			memcpy((char *)data + 24, &pcount, 4);

			/*------------------------------------*/
			/* determine the image format counter */
			/* turn bit 24 off if it is set       */
			/*------------------------------------*/

			memcpy((char *)&ifc, data + ifc_index, IFC_SIZE);
			if (endian == -1)
				FIX_INT(ifc);
			if (ifc == 0) {
				printf("  Line: %d,  Previously inserted line\n", input_line_number);
			}
			itest = ifc;
                        if( (itest & 16777216) == 16777216)
                              ifc = itest - 16777216;

			/*----------------------*/
			/* detect missing lines */
			/*----------------------*/

			if (file_index == 0 && input_line_number == 1) {
				/* can't detect missing lines yet */
				lines_to_write = 1;
			}
			else if (ifc > old_ifc) {
				/* the standard case */
				lines_to_write = ifc - old_ifc;
			}
			else if (ifc == 0) {
				/* a previously inserted line */
				lines_to_write = 1;
			}
			else if (ifc < old_ifc) {
				/* backtracking due to overlapped files or bad line */
				lines_to_write = 0;
			}
			else {
				/* what else can I do? */
				lines_to_write = 0;
			}

			if (lines_to_write > MAX_GAP + 1) {
				if (ignore_flag) {
					printf("%s ERROR: too many missing lines (%d)\n", argv[0], lines_to_write - 1);
					exit(1);
				}
				printf("  Line: %d,  ignoring line (%d missing)\n", input_line_number, lines_to_write - 1);
				lines_to_write = 0;
				ignore_flag = 1;
			}
			else
				ignore_flag = 0;

			if (lines_to_write) {
				if (ifc)
					old_ifc = ifc;
				else
					old_ifc++;
			}
			else
				continue;

			/*-----------------------------------------------*/
			/* determine the pri (pulse repetition interval) */
			/*-----------------------------------------------*/

			/*   pri_dn was sometimes zero which caused problems  so force it to 2820
			 */
			memcpy((char *)&pri_dn, data + pri_index, PRI_SIZE);
			if (endian == -1)
				FIX_SHORT(pri_dn);
			pri_dn = (unsigned short)2820;
			if (pri_dn != old_pri_dn) {
				pri = calc_pri(pri_dn);
				printf("  Line: %d,  PRI = %.8g s,  PRF = %.8g Hz\n", input_line_number, pri, 1.0 / pri);
				old_pri_dn = pri_dn;
			}

			/*------------------------------------------*/
			/* determine the sampling window start time */
			/*------------------------------------------*/

			memcpy((char *)&swst_dn, data + swst_index, SWST_SIZE);
			if (endian == -1)
				FIX_SHORT(swst_dn);
			if (swst_dn != old_swst_dn) {
				printf("Line: %d, swst_dn = %d, old_swst_dn = %d \n", input_line_number, swst_dn, old_swst_dn);
				old_swst_dn = swst_dn;
			}

			/*-----------------------------------------------------*/
			/* calculate the swst_dn1                              */
			/*-----------------------------------------------------*/

			if (input_line_number == 1)
				swst_dn1 = swst_dn;
			if (opt_adjust)
				swst_dn1 = range2swst(near_range_in, pri);

			/* debug
			printf("near_range_in %f, pri %.8g, swst_dn1 %d\n", near_range_in, pri,
			swst_dn1);
			*/

			/*------------------------------------------*/
			/* write the near range                     */
			/*------------------------------------------*/

			if (input_line_number == 2) {
				swst = calc_swst(swst_dn1, pri);
				near_range = SOL * swst / 2.;
				printf("near_range            =  %lf \n", near_range);
			}

			/*----------------------------*/
			/* align lines                */
			/*----------------------------*/

			// if (opt_adjust)
			// {
			/* set the sampling window start time */
			if (endian == -1)
				FIX_SHORT(swst_dn);
			memcpy(data + swst_index, (char *)&swst_dn, SWST_SIZE);
			if (endian == -1)
				FIX_SHORT(swst_dn);

			shift_bytes = (swst_dn1 - swst_dn) * 8;
			if (shift_bytes != old_shift_bytes) {
				printf("  Line: %d,  Byte shift = %d bytes\n", input_line_number, shift_bytes);
				old_shift_bytes = shift_bytes;
			}
			/* fix for CCRS data of length 12060 */
			if (line_length == 12060) {
				for (i = 11644; i < 12060; i++)
					data[i] = 35;
			}
			if (shift_bytes > 0) {
				for (i = header_length; i < line_length - shift_bytes; i++) {
					data[i] = data[i + shift_bytes];
				}
				for (i = line_length - shift_bytes; i < line_length; i++) {
					data[i] = 35;
				}
			}
			else if (shift_bytes < 0) {
				if (shift_bytes >= -1.0 * (line_length - 1)) {
					for (i = line_length - 1; i >= header_length - shift_bytes; i--) {
						data[i] = data[i + shift_bytes];
					}
					for (i = header_length; i < header_length - shift_bytes; i++) {
						data[i] = 35;
					}
				}
				else {
					lines_to_write++;
					if (input_line_number != 1) {
						memcpy(data, data_buf, line_length);
					}
				}
			}
			//	    }

			/*-----------------*/
			/* write out lines */
			/*-----------------*/

			switch (lines_to_write) {
			case 1:
				writeline(ofd, data, line_length, argv[0], output_filename, output_line_number);
				output_line_number++;
				break;
			case 0:
				break;
			default:
				printf("  Line: %d,  %d missing line(s)\n", input_line_number, lines_to_write - 1);
				/* zero the ifc */
				memset(data + ifc_index, 0, IFC_SIZE);
				for (i = 0; i < lines_to_write - 1; i++) {
					writeline(ofd, data, line_length, argv[0], output_filename, output_line_number);
					output_line_number++;
				}
				/* restore the ifc */
				if (endian == -1)
					FIX_INT(ifc);
				memcpy(data + ifc_index, (char *)&ifc, IFC_SIZE);
				writeline(ofd, data, line_length, argv[0], output_filename, output_line_number);
				output_line_number++;
			}
		}
	}

	/*---------------*/
	/* free the line */
	/*---------------*/

	free(data);

	/*-----------------*/
	/* close the files */
	/*-----------------*/

	close(ifd);
	close(ofd);
}

/*----------*/
/* calc_pri */
/*----------*/
/* Calculates the pri */

double calc_pri(unsigned short pri_dn) { return (((double)pri_dn + 2.0) * SEC_PER_PRI_COUNT); }

/*-----------*/
/* calc_swst */
/*-----------*/
/* Calculates the swst */

double calc_swst(unsigned short swst_dn, double pri) {
	/*    return ((double) swst_dn * SEC_PER_PRI_COUNT + 9.0 * pri - 6.0E-6);*/
	/* based on Johan Jacob Mohr and Søren Nørvang Madsen, Member, IEEE,Geometric
	 * Calibration of ERS Satellite SAR Images, 2001, calibriation should be 6.6*/
	return ((double)swst_dn * SEC_PER_PRI_COUNT + 9.0 * pri - 6.6E-6);
}

/*------------*/
/* range2swst */
/*------------*/
/* Calculates the swst_dn from near_range_in defined by user */
int range2swst(double range, double pri) {
	/* refer to calc_swst */
	return ((int)floor((2.0 * range / SOL + 6.6E-6 - 9.0 * pri) / SEC_PER_PRI_COUNT));
}

/*----------*/
/* readline */
/*----------*/
/* Reads in the specified number of bytes and exits with message on error */

void readline(int ifd, char *data, int line_length, char *command, char *filename, int line_number) {
	if (read(ifd, data, line_length) != line_length) {
		if (line_number)
			printf("%s ERROR: error reading line %d from %s\n", command, line_number, filename);
		else
			printf("%s ERROR: error reading header from %s\n", command, filename);

		exit(1);
	}
	return;
}

/*-----------*/
/* writeline */
/*-----------*/
/* Writes the specified number of bytes and exits with message on error */

void writeline(int ofd, char *data, int line_length, char *command, char *filename, int line_number) {
	if (write(ofd, data, line_length) != line_length) {
		if (line_number)
			printf("%s ERROR: error writing line %d to %s\n", command, line_number, filename);
		else
			printf("%s ERROR: error writing header to %s\n", command, filename);

		exit(1);
	}
	return;
}

/*----------------*/
/* determine_info */
/*----------------*/
/* Sets-up the station_info structure based on file size and contents */

int determine_info(char *command, char *filename, int station_index) {
	int file_size, header_length, ifc_index, pass, line_length, x;
	int ifd;

	/*-----------*/
	/* open file */
	/*-----------*/

	ifd = open(filename, O_RDONLY);
	if (ifd == -1) {
		printf("%s ERROR: error opening file (%s) for station determination\n", command, filename);
		exit(1);
	}
	file_size = lseek(ifd, 0, SEEK_END);

	header_length = station[station_index].header_length;

	/*----------------------------------------------*/
	/* if line length is known, just search for IFC */
	/*----------------------------------------------*/

	if (station[station_index].line_length) {
		for (ifc_index = 0; ifc_index < header_length; ifc_index++) {
			if (try_info(ifd, station[station_index].line_length, ifc_index)) {
				station[station_index].ifc_index = ifc_index;
				station[station_index].swst_index = ifc_index + SWST_OFFSET;
				station[station_index].pri_index = ifc_index + PRI_OFFSET;
				close(ifd);
				return (1);
			}
		}
	}
	else {
		/*--------------------------------------------------*/
		/* use two passes (one based on file size, one not) */
		/*--------------------------------------------------*/

		for (pass = 0; pass < 2; pass++) {
			/*------------------------------------*/
			/* step through possible line lengths */
			/*------------------------------------*/

			for (line_length = MIN_LINE_SIZE; line_length < MAX_LINE_SIZE; line_length++) {
				if (pass == 0) {
					/* check line sizes with integer lines per file */
					x = file_size / line_length;
					if (x * line_length != file_size)
						continue;
				}
				else {
					/* check line sizes with non-integer lines per file */
					x = file_size / line_length;
					if (x * line_length == file_size)
						continue;
				}

				/*-------------------------------------*/
				/* step through possible ifc locations */
				/*-------------------------------------*/

				for (ifc_index = 0; ifc_index < header_length; ifc_index++) {
					if (try_info(ifd, line_length, ifc_index)) {
						station[station_index].line_length = line_length;
						station[station_index].ifc_index = ifc_index;
						station[station_index].swst_index = ifc_index + SWST_OFFSET;
						station[station_index].pri_index = ifc_index + PRI_OFFSET;
						close(ifd);
						return (1);
					}
				}
			}
		}
	}

	close(ifd);
	return (0);
}

/*----------*/
/* try_info */
/*----------*/
/* returns 1 if info appears to be acceptable, 0 otherwise */

int try_info(int ifd, int line_length, int ifc_index) {
	char bad;
	unsigned short pri_dn[CHECK_LINES];
	int line_number, ifc_offset, pri_offset;
	int ifc_dn[CHECK_LINES];
	unsigned int sum_dif, dif;
	double pri, prf;

	/*--------------------------------------*/
	/* load in values for CHECK_LINES lines */
	/*--------------------------------------*/

	for (line_number = 0; line_number < CHECK_LINES; line_number++) {
		ifc_offset = line_length * (line_number + 1) + ifc_index;
		pri_offset = ifc_offset + PRI_OFFSET;
		lseek(ifd, ifc_offset, SEEK_SET);
		read(ifd, (char *)&ifc_dn[line_number], IFC_SIZE);
		lseek(ifd, pri_offset, SEEK_SET);
		read(ifd, (char *)&pri_dn[line_number], PRI_SIZE);
	}

	/*---------------------------------*/
	/* check values for reasonableness */
	/*---------------------------------*/

	sum_dif = 0;
	bad = 0;
	for (line_number = 0; line_number < CHECK_LINES; line_number++) {
		if (line_number > 0) {
			dif = ifc_dn[line_number] - ifc_dn[line_number - 1];
			if (dif < 1) {
				bad = 1;
				break;
			}
			else
				sum_dif += dif;
		}
		pri = calc_pri(pri_dn[line_number]);
		if (pri == 0.0) {
			bad = 1;
			break;
		}
		prf = 1.0 / calc_pri(pri_dn[line_number]);
		if (prf < MIN_PRF || prf > MAX_PRF) {
			bad = 1;
			break;
		}
	}
	if (!bad && sum_dif < CHECK_LINES - 1 + MISSING_LINES)
		return (1);
	else
		return (0);
}

/*-------*/
/* usage */
/*-------*/
/* Prints a usage message to stderr, and exits */

void usage(char *command, int exit_code) {
	int i;
	printf("usage : ers_line_fixer [ -a near_range] [ -h header ] [ -l line ] [ "
	       "-s station ]\n");
	printf("    <raw file> <fixed file>\n");
	printf("\n");
	printf("    -a near_range    : align near_range \n");
	printf("    -h header        : set the header length (bytes)\n");
	printf("    -l line          : set the line length (bytes)\n");
	printf("    -s station       : set processing station\n");
	printf("    raw file         : input filename\n");
	printf("    fixed file       : output filename\n");
	printf("\n");
	printf("Stations: %s", station[0].station_name);
	for (i = 1; station[i].station_name; i++)
		printf(", %s", station[i].station_name);
	printf("\n");
	exit(exit_code);
	return;
}

/*-----------*/
/* underline */
/*-----------*/

void underline(FILE *ofp, int count, char character) {
	int i;
	for (i = 0; i < count; i++)
		fprintf(ofp, "%c", character);
	fprintf(ofp, "\n");
}

/*_______________________________*/
/* check endian of machine      */
/* 1 if big; -1 if little       */
/*_______________________________*/
int is_big_endian_() {
	union {
		int64_t l;
		char c[sizeof(int64_t)];
	} u;
	u.l = 1;
	return (u.c[sizeof(int64_t) - 1] == 1 ? 1 : -1);
}
int is_big_endian__() { return is_big_endian_(); }
