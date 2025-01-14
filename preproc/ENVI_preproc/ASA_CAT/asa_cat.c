/***********************************************************************************************************************************

asa_cat.c
version 1.3
Concatenates Envisat ASAR Image Mode / Wide Swath Mode Level 0 data

compiled on a Linux with command:     gcc -O2 -lm asa_cat.c -o asa_cat

Dochul Yang and Vikas Gudipati
version 1.0 July 15 2008
This code is based on ASAR IM Mode Level 0 data decoder written by Sean M
Buckley. version 1.1 July 15 2008   : First working version version 1.2 August
19 2008 : Replaced the use of roundl() by floor(), to round off floats to
integers : Included <string.h> header for older gcc compilers. version 1.3 Sept
10 2008   : Concatenates files even if they are non-overlapping (by filling
(127,127 or (128,128) for (I,Q) pairs)


***********************************************************************************************************************************/

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

/**
 * The <code>EPR_DataTypeId</code> enumeration lists all possible data
 * types for field elements in ENVISAT dataset records.
 */
// added by Z. Li on 16/02/2005
// extracted from ESA BEAM epr_api package

#define fileSize 100 /* Maximum number of file that can be concatenated. later change */

enum EPR_DataTypeId {
	/** The ID for unknown types. */
	e_tid_unknown = 0,
	/** An array of unsigned 8-bit integers, C type is <code>uchar*</code> */
	e_tid_uchar = 1,
	/** An array of signed 8-bit integers, C type is <code>char*</code> */
	e_tid_char = 2,
	/** An array of unsigned 16-bit integers, C type is <code>ushort*</code> */
	e_tid_ushort = 3,
	/** An array of signed 16-bit integers, C type is <code>short*</code> */
	e_tid_short = 4,
	/** An array of unsigned 32-bit integers, C type is <code>ulong*</code> */
	e_tid_ulong = 5,
	/** An array of signed 32-bit integers, C type is <code>long*</code> */
	e_tid_long = 6,
	/** An array of 32-bit floating point numbers, C type is <code>float*</code>
	 */
	e_tid_float = 7,
	/** An array of 64-bit floating point numbers, C type is <code>double*</code>
	 */
	e_tid_double = 8,
	/** A zero-terminated ASCII string, C type is <code>char*</code> */
	e_tid_string = 11,
	/** An array of unsigned character, C type is <code>uchar*</code> */
	e_tid_spare = 13,
	/** A time (MJD) structure, C type is <code>EPR_Time</code> */
	e_tid_time = 21
};

/* structures */

struct mphStruct {
	char product[62];
	char procStage[1];
	char refDoc[23];
	char spare1[40];
	char acquisitionStation[20];
	char procCenter[6];
	char procTime[27];
	char softwareVer[14];
	char spare2[40];
	char sensingStart[27];
	char sensingStop[27];
	char spare3[40];
	char phase[1];
	int cycle;
	int relOrbit;
	int absOrbit;
	char stateVectorTime[27];
	double deltaUt1;
	double xPosition;
	double yPosition;
	double zPosition;
	double xVelocity;
	double yVelocity;
	double zVelocity;
	char vectorSource[2];
	char spare4[40];
	char utcSbtTime[27];
	unsigned int satBinaryTime;
	unsigned int clockStep;
	char spare5[32];
	char leapUtc[27];
	int leapSign;
	int leapErr;
	char spare6[40];
	int productErr;
	int totSize;
	int sphSize;
	int numDsd;
	int dsdSize;
	int numDataSets;
	char spare7[40];
};

struct dsdStruct {
	char dsName[28];
	char dsType[1];
	char filename[62];
	int dsOffset;
	int dsSize;
	int numDsr;
	int dsrSize;
};

struct sphStruct {
	char sphDescriptor[28];
	double startLat;
	double startLon;
	double stopLat;
	double stopLon;
	double satTrack;
	char spare1[50];
	int ispErrorsSignificant;
	int missingIspsSignificant;
	int ispDiscardedSignificant;
	int rsSignificant;
	char spare2[50];
	int numErrorIsps;
	double errorIspsThresh;
	int numMissingIsps;
	double missingIspsThresh;
	int numDiscardedIsps;
	double discardedIspsThresh;
	int numRsIsps;
	double rsThresh;
	char spare3[100];
	char txRxPolar[5];
	char swath[3];
	char spare4[41];
	struct dsdStruct dsd[4];
};

struct sphAuxStruct {
	char sphDescriptor[28];
	char spare1[51];
	struct dsdStruct dsd[1];
};

struct dsrTimeStruct {
	int days;
	int seconds;
	int microseconds;
};

struct calPulseStruct {
	float nomAmplitude[32];
	float nomPhase[32];
};

struct nomPulseStruct {
	float pulseAmpCoeff[4];
	float pulsePhsCoeff[4];
	float pulseDuration;
};

struct dataConfigStruct {
	char echoCompMethod[4];
	char echoCompRatio[3];
	char echoResampFlag[1];
	char initCalCompMethod[4];
	char initCalCompRatio[3];
	char initCalResampFlag[1];
	char perCalCompMethod[4];
	char perCalCompRatio[3];
	char perCalResampFlag[1];
	char noiseCompMethod[4];
	char noiseCompRatio[3];
	char noiseResampFlag[1];
};

struct swathConfigStruct {
	unsigned short numSampWindowsEcho[7];
	unsigned short numSampWindowsInitCal[7];
	unsigned short numSampWindowsPerCal[7];
	unsigned short numSampWindowsNoise[7];
	float resampleFactor[7];
};

struct swathIdStruct {
	unsigned short swathNum[7];
	unsigned short beamSetNum[7];
};

struct timelineStruct {
	unsigned short swathNums[7];
	unsigned short mValues[7];
	unsigned short rValues[7];
	unsigned short gValues[7];
};

/* problems begin with field 132 - check the double statement */
struct testStruct {
	float operatingTemp;
	float rxGainDroopCoeffSmb[16]; /* this needs to be converted to a double array
	                                  of eight elements */
	                               // double rxGainDroopCoeffSmb[ 8 ]; /* Something wrong here, why?*/
};

struct insGadsStruct { /* see pages 455-477 for the 142 fields associated with
	                      this gads - got length of 121712 bytes */
	struct dsrTimeStruct dsrTime;
	unsigned int dsrLength;
	float radarFrequency;
	float sampRate;
	float offsetFreq;
	struct calPulseStruct calPulseIm0TxH1;
	struct calPulseStruct calPulseIm0TxV1;
	struct calPulseStruct calPulseIm0TxH1a;
	struct calPulseStruct calPulseIm0TxV1a;
	struct calPulseStruct calPulseIm0RxH2;
	struct calPulseStruct calPulseIm0RxV2;
	struct calPulseStruct calPulseIm0H3;
	struct calPulseStruct calPulseIm0V3;
	struct calPulseStruct calPulseImTxH1[7];
	struct calPulseStruct calPulseImTxV1[7];
	struct calPulseStruct calPulseImTxH1a[7];
	struct calPulseStruct calPulseImTxV1a[7];
	struct calPulseStruct calPulseImRxH2[7];
	struct calPulseStruct calPulseImRxV2[7];
	struct calPulseStruct calPulseImH3[7];
	struct calPulseStruct calPulseImV3[7];
	struct calPulseStruct calPulseApTxH1[7];
	struct calPulseStruct calPulseApTxV1[7];
	struct calPulseStruct calPulseApTxH1a[7];
	struct calPulseStruct calPulseApTxV1a[7];
	struct calPulseStruct calPulseApRxH2[7];
	struct calPulseStruct calPulseApRxV2[7];
	struct calPulseStruct calPulseApH3[7];
	struct calPulseStruct calPulseApV3[7];
	struct calPulseStruct calPulseWvTxH1[7];
	struct calPulseStruct calPulseWvTxV1[7];
	struct calPulseStruct calPulseWvTxH1a[7];
	struct calPulseStruct calPulseWvTxV1a[7];
	struct calPulseStruct calPulseWvRxH2[7];
	struct calPulseStruct calPulseWvRxV2[7];
	struct calPulseStruct calPulseWvH3[7];
	struct calPulseStruct calPulseWvV3[7];
	struct calPulseStruct calPulseWsTxH1[5];
	struct calPulseStruct calPulseWsTxV1[5];
	struct calPulseStruct calPulseWsTxH1a[5];
	struct calPulseStruct calPulseWsTxV1a[5];
	struct calPulseStruct calPulseWsRxH2[5];
	struct calPulseStruct calPulseWsRxV2[5];
	struct calPulseStruct calPulseWsH3[5];
	struct calPulseStruct calPulseWsV3[5];
	struct calPulseStruct calPulseGmTxH1[5];
	struct calPulseStruct calPulseGmTxV1[5];
	struct calPulseStruct calPulseGmTxH1a[5];
	struct calPulseStruct calPulseGmTxV1a[5];
	struct calPulseStruct calPulseGmRxH2[5];
	struct calPulseStruct calPulseGmRxV2[5];
	struct calPulseStruct calPulseGmH3[5];
	struct calPulseStruct calPulseGmV3[5];
	struct nomPulseStruct nomPulseIm[7];
	struct nomPulseStruct nomPulseAp[7];
	struct nomPulseStruct nomPulseWv[7];
	struct nomPulseStruct nomPulseWs[5];
	struct nomPulseStruct nomPulseGm[5];
	float azPatternIs1[101];
	float azPatternIs2[101];
	float azPatternIs3Ss2[101];
	float azPatternIs4Ss3[101];
	float azPatternIs5Ss4[101];
	float azPatternIs6Ss5[101];
	float azPatternIs7[101];
	float azPatternSs1[101];
	float rangeGateBias;
	float rangeGateBiasGm;
	float adcLutI[255];
	float adcLutQ[255];
	char spare1[648];
	float full8LutI[256];
	float full8LutQ[256];
	float fbaq4LutI[4096];
	float fbaq3LutI[2048];
	float fbaq2LutI[1024];
	float fbaq4LutQ[4096];
	float fbaq3LutQ[2048];
	float fbaq2LutQ[1024];
	float fbaq4NoAdc[4096];
	float fbaq3NoAdc[2048];
	float fbaq2NoAdc[1024];
	float smLutI[16];
	float smLutQ[16];
	struct dataConfigStruct dataConfigIm;
	struct dataConfigStruct dataConfigAp;
	struct dataConfigStruct dataConfigWs;
	struct dataConfigStruct dataConfigGm;
	struct dataConfigStruct dataConfigWv;
	struct swathConfigStruct swathConfigIm;
	struct swathConfigStruct swathConfigAp;
	struct swathConfigStruct swathConfigWs;
	struct swathConfigStruct swathConfigGm;
	struct swathConfigStruct swathConfigWv;
	unsigned short perCalWindowsEc;
	unsigned short perCalWindowsMs;
	struct swathIdStruct swathIdIm;
	struct swathIdStruct swathIdAp;
	struct swathIdStruct swathIdWs;
	struct swathIdStruct swathIdGm;
	struct swathIdStruct swathIdWv;
	unsigned short initCalBeamSetWv;
	unsigned short beamSetEc;
	unsigned short beamSetMs;
	unsigned short calSeq[32];
	struct timelineStruct timelineIm;
	struct timelineStruct timelineAp;
	struct timelineStruct timelineWs;
	struct timelineStruct timelineGm;
	struct timelineStruct timelineWv;
	unsigned short mEc;
	char spare2[44];
	float refElevAngleIs1;
	float refElevAngleIs2;
	float refElevAngleIs3Ss2;
	float refElevAngleIs4Ss3;
	float refElevAngleIs5Ss4;
	float refElevAngleIs6Ss5;
	float refElevAngleIs7;
	float refElevAngleSs1;
	char spare3[64];
	float calLoopRefIs1[128];
	float calLoopRefIs2[128];
	float calLoopRefIs3Ss2[128];
	float calLoopRefIs4Ss3[128];
	float calLoopRefIs5Ss4[128];
	float calLoopRefIs6Ss5[128];
	float calLoopRefIs7[128];
	float calLoopRefSs1[128];
	char spare4[5120];
	struct testStruct im;
	struct testStruct ap;
	struct testStruct ws;
	struct testStruct gm;
	struct testStruct wv;
	float swstCalP2;
	char spare5[72];
};

// added by Z. Li on 16/02/2005
typedef enum EPR_DataTypeId EPR_EDataTypeId;
typedef int boolean;
typedef unsigned char uchar;
typedef unsigned short ushort;
typedef unsigned int uint;
typedef uint64_t ulong;

/* function prototypes */

struct mphStruct readMph(const char *mphPtr, const int printMphIfZero);
struct sphStruct readSph(const char *sphPtr, const int printSphIfZero, const struct mphStruct mph);
struct sphAuxStruct readSphAux(const char *sphPtr, const int printSphIfZero, const struct mphStruct mph);

// added by Z. Li on 16/02/2005
int is_bigendian();
void byte_swap_short(short *buffer, uint number_of_swaps);
void byte_swap_ushort(ushort *buffer, uint number_of_swaps);
void byte_swap_long(int64_t *buffer, uint number_of_swaps);
void byte_swap_ulong(ulong *buffer, uint number_of_swaps);
void byte_swap_float(float *buffer, uint number_of_swaps);

/* new byte_swap_int type added below*/
void byte_swap_int(int *buffer, uint number_of_swaps);
void byte_swap_uint(uint *buffer, uint number_of_swaps);
/* new byte_swap_uint type added above*/

void swap_endian_order(EPR_EDataTypeId data_type_id, void *elems, uint num_elems);

double date2MJD(int yr, int mo, int day, int hr, int min, double sec);
void bubbleSort(double array[], int len);

/**********************************************************************************************************************************/

int main(int argc, char *argv[]) {

	/* variable definitions */

	FILE *imFilePtr;
	FILE *outFilePtr;
	// FILE *blockIdFilePtr;
	// FILE *insFilePtr;

	char imFileName[200];
	char outFileName[200];
	// char blockIdFileName[ 200 ] = "blockId";
	// char insFileName[ 200 ];

	char syear[4]; /* need to figure out  */
	char smonth[3];
	char sday[3];
	char shh[3];
	char smm[3];
	char sss[3];
	// char  sfracsec_start[6];
	// char  sfracsec_end[6];
	char sensingStopTime[32];
	char ssensingStopTime[32];
	// char  sensingStartTime[27];
	// char  ssensingStartTime[27];
	// char  start_lat[20];
	// char  sstart_lat[20];
	// char  stop_lon[20];
	// char  sstop_lon[20];
	char totsize[22];
	char ds_size[21];
	char num_dsr[11];
	char secduration[16];

	char *mphPtr;
	char *sphPtr;
	char *mphPtr2 = NULL;
	char *sphPtr2 = NULL;
	// char *gadsPtr;

	// unsigned char onBoardTimeLSB;
	// unsigned char auxTxMonitorLevel;
	// unsigned char mdsrBlockId[ 200 ];
	// unsigned char mdsrCheck[ 63 ];
	// unsigned char beamAdjDeltaCodeword;
	// unsigned char compressionRatio;
	// unsigned char echoFlag;
	// unsigned char noiseFlag;
	// unsigned char calFlag;
	// unsigned char calType;
	// unsigned char spare;
	// unsigned char antennaBeamSetNumber;
	// unsigned char TxPolarization;
	// unsigned char RxPolarization;
	// unsigned char calibrationRowNumber;
	// unsigned char chirpPulseBandwidthCodeword;
	unsigned char mdsrLineChar[20000];
	unsigned char tempmdsrLineChar[20000];

	int printImMphIfZero = 1;
	int printImSphIfZero = 1;
	// int printImMdsrIfZero	= 1;
	// int printInsMphIfZero	= 1;
	// int printInsSphIfZero	= 1;
	// int printBlockIdIfZero	= 1;
	// int noAdcIfZero		= 1;
	int firstTimeEqualsZero = 0;
	int mphSize = 1247; /* fixed size */
	// int outSamples		= 0;
	int outLines = 0;
	int duplicateLines = 0;
	// int sampleShift		= 0;
	int bytesRead = 0;
	int bytesToBeWritten = 0;
	// int nonOverlappingLineIfZero = 0;
	// int outType			= 4;
	int i;
	int ii;
	int j;
	// int k;
	// int m;
	// int n;
	// int counter  = 1;
	int numFiles;
	int mdsrDsrTimeDays;
	int mdsrDsrTimeSeconds;
	int mdsrDsrTimeMicroseconds;
	int mdsrGsrtTimeDays;
	int mdsrGsrtTimeSeconds;
	int mdsrGsrtTimeMicroseconds;
	// int mdsrLineInt;

	int tempmdsrDsrTimeDays;
	int tempmdsrDsrTimeSeconds;
	int tempmdsrDsrTimeMicroseconds;
	int tempmdsrGsrtTimeDays;
	int tempmdsrGsrtTimeSeconds;
	int tempmdsrGsrtTimeMicroseconds;

	int newmdsrDsrTimeDays;
	int newmdsrDsrTimeSeconds;
	int newmdsrDsrTimeMicroseconds;
	int oldmdsrDsrTimeDays = 0;
	int oldmdsrDsrTimeSeconds = 0;
	int oldmdsrDsrTimeMicroseconds = 0;

	int file_order[fileSize]; /* need to change */
	int totfilesize;
	// int ifracsec_diff;
	int imjd_diffsec;
	int duration;

	int oldFrameID;
	int FrameID;
	int catAbortFlag = 0;
	int jjj, kkk;
	int tempsamplecount;

	unsigned int modePacketCount = 0;
	unsigned int modePacketCountOld = 0;
	unsigned int tempmodePacketCount;
	// unsigned int onBoardTimeIntegerSeconds = 0;

	// short upConverterLevel;
	// short downConverterLevel;

	unsigned short tempmdsrIspLength;
	unsigned short tempmdsrILen;

	// unsigned short resamplingFactor;
	// unsigned short onBoardTimeMSW;
	// unsigned short onBoardTimeLSW;
	unsigned short mdsrIspLength;
	unsigned short mdsrILen;
	unsigned short mdsrCrcErrs;
	unsigned short mdsrRsErrs;
	unsigned short mdsrSpare1;
	unsigned short mdsrPacketIdentification;
	unsigned short mdsrPacketSequenceControl;
	unsigned short mdsrPacketLength;
	unsigned short tempmdsrPacketLength;
	unsigned short mdsrPacketDataHeader[15];
	unsigned short tempmdsrPacketDataHeader[15];
	// unsigned short onBoardTimeFractionalSecondsInt = 0;
	// unsigned short TxPulseLengthCodeword;
	// unsigned short priCodeword;
	// unsigned short priCodewordOld;
	// unsigned short priCodewordOldOld;
	// unsigned short windowStartTimeCodeword;
	// unsigned short windowStartTimeCodeword0;
	// unsigned short windowStartTimeCodewordOld;
	// unsigned short windowStartTimeCodewordOldOld;
	// unsigned short windowLengthCodeword;
	// unsigned short modeID;
	// unsigned short cyclePacketCount;

	// float mdsrLine[ 20000 ];

	// double onBoardTimeFractionalSeconds;
	// double TxPulseLength;
	// double beamAdjDelta;
	// double chirpPulseBandwidth;
	// double c = 299792458.;
	// double timeCode;
	// double pri;
	// double windowStartTime;
	// double windowLength;
	// double curser;

	double newt, oldt, delta1, est_pri;
	double temptimesec;

	int nmsl, msl;
	int year;
	int month;
	int day;
	int hh;
	int mm;
	double ss;
	double MJD[fileSize];          /* need to change */
	double MJD_original[fileSize]; /* need to change */
	double mjd_start = 0.0;
	double mjd_end = 0.0;
	double mjd_diffsec;
	// double fracsec_start;
	// double fracsec_end;
	// double fracsec_diff;

	char stmonthstr[4];
	char emonthstr[4];
	int stday, styear, stmonth = 0, sthour, stmin;
	int eday, eyear, emonth = 0, ehour, emin;

	double stseconds;
	double eseconds;

	struct mphStruct mph;
	// struct mphStruct mphIns;
	struct sphStruct sph;
	// struct sphAuxStruct sphIns;
	// struct insGadsStruct insGads;

	int is_littlendian;

	/* usage note */

	printf("\n*** asa_cat v1.3 by Dochul Yang and Vikas Gudipati***\n\n");

	if ((argc - 1) < 3) {
		printf("Concatenates Envisat ASAR Image Mode / Wide Swath Mode Level 0 "
		       "data.\n\n");
		printf("Usage: asa_cat <NumFiles2Cat> <asa_file1> <asa_file2> <...>  "
		       "<out_file> [catAbort]\n\n");
		printf("       NumFiles2Cat Number of files to be concatenated (positive "
		       "integer, Max: 100) \n");
		printf("       asa_file1    First file to be merged (along track)\n");
		printf("       asa_file2    Second file to be merged (along track)\n");
		printf("       ...          Rest of files to be merged (along track)\n");
		printf("       out_file     output data file\n");
		printf("       [catAbort]   Flag to discontinue concatenation if "
		       "non-overlaping frames are found. (0: Discontinue, 1: Continue, "
		       "Default: 0)\n");
		printf("Notes:\n\n");
		return 0;
	}

	sscanf(argv[1], "%d", &numFiles);
	printf("\nNumber of input files: %d\n", numFiles);

	if (numFiles < 1) {
		printf("ERROR: Number of files to concatenate is less than one(1). Look at "
		       "command usage.\n\n");
		exit(-1);
	}
	if (numFiles > 100) {
		printf("ERROR: Maximum number of files allowed for concatenation exceeded. "
		       "Max: 100. Look at command usage.\n\n");
		exit(-1);
	}

	if ((argc - 3) < numFiles) {
		printf("\nERROR: File names missing in input list. %s\n", argv[1]);
		printf("\nNumber of files to be concatenated. %s\n", argv[1]);
		printf("\nNumber of input file names provided. %d\n", (argc - 3));
		exit(-1);
	}

	for (ii = 0; ii < numFiles; ii++) {
		printf("Input file %d : %s\n", ii + 1, argv[ii + 2]);
	}

	sscanf(argv[numFiles + 2], "%s", outFileName);
	printf("Output file: %s\n\n", outFileName);

	if (argc > (numFiles + 3)) {
		sscanf(argv[numFiles + 3], "%d", &catAbortFlag);
	}
	if (catAbortFlag == 0) {
		printf("catAbortFlag: %d. Files will NOT be concatenated if they don't "
		       "overlap.\n",
		       catAbortFlag);
	}
	else if (catAbortFlag == 1) {
		printf("catAbortFlag: %d. Files will be concatenated even if they don't "
		       "overlap.\n",
		       catAbortFlag);
	}

	if (is_bigendian()) {
		printf("It is running under Unix or Mac...\n");
		is_littlendian = 0;
	}
	else {
		printf("It is running under Linux or Windows...\n");
		is_littlendian = 1;
	}

	/* begin loop over files for extract mph product name (DATE + HHMMSS) and sort
	 * by MJD*/

	for (ii = 0; ii < numFiles; ii++) {

		/* open image file */

		sscanf(argv[ii + 2], "%s", imFileName);
		printf("\nOpening file: %s\n", imFileName);

		imFilePtr = fopen(imFileName, "rb");
		if (imFilePtr == NULL) {
			printf("*** ERROR - cannot open file: %s\n", imFileName);
			printf("\n");
			exit(-1);
		}

		/* read image MPH */

		printf("Reading MPH...\n");

		mphPtr = (char *)malloc(sizeof(char) * mphSize);

		if (mphPtr == NULL) {
			printf("ERROR - mph allocation memory\n");
			exit(-1);
		}

		if ((fread(mphPtr, sizeof(char), mphSize, imFilePtr)) != mphSize) {
			printf("ERROR - mph read error\n\n");
			exit(-1);
		}

		mph = readMph(mphPtr, printImMphIfZero); /* extract information from MPH */

		memcpy(syear, mphPtr + 23, 4);
		memcpy(smonth, mphPtr + 27, 2);
		memcpy(sday, mphPtr + 29, 2);

		memcpy(shh, mphPtr + 32, 2);
		memcpy(smm, mphPtr + 34, 2);
		memcpy(sss, mphPtr + 36, 2);

		year = atoi(syear);
		month = atoi(smonth);
		day = atoi(sday);

		hh = atoi(shh);
		mm = atoi(smm);
		ss = atof(sss);

		printf("Date and time of first line of file (yyyy mo dd hh mm ss): %d %d "
		       "%d %d %d %f\n",
		       year, month, day, hh, mm, ss);

		MJD[ii] = date2MJD(year, month, day, hh, mm, ss);
		MJD_original[ii] = MJD[ii];

		free(mphPtr);

		fclose(imFilePtr);

	} /* end of for loop */

	//   for (i=0; i< numFiles; i++){printf("\n%d : %f", i, MJD[i]);}

	printf("\nSorting files in ascending order of their sensing start times ...\n");
	bubbleSort(MJD, numFiles);

	//   for (i=0; i< numFiles; i++){printf("\n%d : %f", i, MJD[i]);}

	for (i = 0; i < numFiles; i++) {
		for (j = 0; j < numFiles; j++) {
			if (MJD[i] == MJD_original[j]) {
				file_order[i] = j;
				break;
			}
		}
	}
	printf("File order after sorting:");
	for (i = 0; i < numFiles; i++) {
		printf(" %d", file_order[i] + 1);
	}
	printf("\n");

	/* open files */

	outFilePtr = fopen(outFileName, "wb");
	if (outFilePtr == NULL) {
		printf("*** ERROR - cannot open file: %s\n", outFileName);
		printf("\n");
		exit(-1);
	}

	/* begin loop over files */

	firstTimeEqualsZero = 0;
	for (ii = 0; ii < numFiles; ii++) {

		FrameID = ii;
		if (firstTimeEqualsZero == 0) {
			oldFrameID = ii;
		}

		/* open image file */
		sscanf(argv[file_order[ii] + 2], "%s", imFileName);
		printf("\nInput file: %d\n", file_order[ii] + 1);

		imFilePtr = fopen(imFileName, "rb");
		if (imFilePtr == NULL) {
			printf("*** ERROR - cannot open file: %s\n", imFileName);
			printf("\n");
			exit(-1);
		}

		/* read image MPH */

		printf("Reading MPH...\n");

		mphPtr = (char *)malloc(sizeof(char) * mphSize);

		if (mphPtr == NULL) {
			printf("ERROR - mph allocation memory\n");
			exit(-1);
		}

		if ((fread(mphPtr, sizeof(char), mphSize, imFilePtr)) != mphSize) {
			printf("ERROR - mph read error\n\n");
			exit(-1);
		}

		mph = readMph(mphPtr, printImMphIfZero); /* extract information from MPH */

		/* read image SPH */

		printf("Reading SPH...\n");

		sphPtr = (char *)malloc(sizeof(char) * mph.sphSize);

		if (sphPtr == NULL) {
			printf("ERROR - sph allocation memory\n");
			exit(-1);
		}

		if ((fread(sphPtr, sizeof(char), mph.sphSize, imFilePtr)) != mph.sphSize) {
			printf("ERROR - sph read error\n\n");
			exit(-1);
		}

		sph = readSph(sphPtr, printImSphIfZero, mph); /* extract information from SPH */

		/* writing dummy mph and sph for first file  */
		if (ii == 0) {

			/* Write MPH of output frame file */
			mphPtr2 = (char *)malloc(sizeof(char) * mphSize);
			if (mphPtr2 == NULL) {
				printf("ERROR - mph allocation memory\n");
				exit(-1);
			}
			memcpy(mphPtr2, mphPtr, mphSize);

			printf("\nInitializing MPH of output file...\n");
			if ((fwrite(mphPtr2, sizeof(char), mphSize, outFilePtr)) != mphSize) {
				printf(" ERROR - outFile write error\n\n");
				exit(-1);
			}

			/* Write SPH of output frame file */
			sphPtr2 = (char *)malloc(sizeof(char) * mph.sphSize);
			if (sphPtr2 == NULL) {
				printf("ERROR - sph allocation memory\n");
				exit(-1);
			}
			memcpy(sphPtr2, sphPtr, mph.sphSize);

			printf("Initializing SPH of output file...\n\n");
			if ((fwrite(sphPtr2, sizeof(char), mph.sphSize, outFilePtr)) != mph.sphSize) {
				printf(" ERROR - outFile write error\n\n");
				exit(-1);
			}

		} /* end of if(ii==0) */

		if (ii == 0) {
			sscanf(mph.sensingStart, "%2d-%3c-%4d %2d:%2d:%lf", &stday, stmonthstr, &styear, &sthour, &stmin, &stseconds);
			if (strcmp(stmonthstr, "JAN") == 0) {
				stmonth = 1;
			}
			if (strcmp(stmonthstr, "FEB") == 0) {
				stmonth = 2;
			}
			if (strcmp(stmonthstr, "MAR") == 0) {
				stmonth = 3;
			}
			if (strcmp(stmonthstr, "APR") == 0) {
				stmonth = 4;
			}
			if (strcmp(stmonthstr, "MAY") == 0) {
				stmonth = 5;
			}
			if (strcmp(stmonthstr, "JUN") == 0) {
				stmonth = 6;
			}
			if (strcmp(stmonthstr, "JUL") == 0) {
				stmonth = 7;
			}
			if (strcmp(stmonthstr, "AUG") == 0) {
				stmonth = 8;
			}
			if (strcmp(stmonthstr, "SEP") == 0) {
				stmonth = 9;
			}
			if (strcmp(stmonthstr, "OCT") == 0) {
				stmonth = 10;
			}
			if (strcmp(stmonthstr, "NOV") == 0) {
				stmonth = 11;
			}
			if (strcmp(stmonthstr, "DEC") == 0) {
				stmonth = 12;
			}

			mjd_start = date2MJD(styear, stmonth, stday, sthour, stmin, stseconds);
		}
		/* read image MDSR from file */

		printf("Reading and Writing MDSR...\n");
		printf("Number of lines in frame %d: %d\n", ii + 1, sph.dsd[0].numDsr);

		for (i = 0; i < sph.dsd[0].numDsr; i++) {

			if ((i) % 2000 == 0)
				printf("Line %6d of input file %d.  Output Line: %8d\n", i + 1, ii + 1, outLines + 1);

			/* sensing time added by Level 0 processor, as converted from Satellite
			 * Binary Time (SBT) counter embedded in each ISP */
			/**
			 * Represents a binary time value field in ENVISAT records.
			 *
			 * <p> Refer to ENVISAT documentation for the exact definition of
			 * this data type.
			 */
			/*
			       int64_t  days;
			       ulong seconds;
			       ulong microseconds;
			*/

			bytesRead = bytesRead + 4 * fread(&mdsrDsrTimeDays, 4, 1, imFilePtr);
			bytesRead = bytesRead + 4 * fread(&mdsrDsrTimeSeconds, 4, 1, imFilePtr);
			bytesRead = bytesRead + 4 * fread(&mdsrDsrTimeMicroseconds, 4, 1, imFilePtr);

			if (is_littlendian) {
				swap_endian_order(e_tid_long, &mdsrDsrTimeDays, 1);
				swap_endian_order(e_tid_ulong, &mdsrDsrTimeSeconds, 1);
				swap_endian_order(e_tid_ulong, &mdsrDsrTimeMicroseconds, 1);
			}
			newmdsrDsrTimeDays = mdsrDsrTimeDays;
			newmdsrDsrTimeSeconds = mdsrDsrTimeSeconds;
			newmdsrDsrTimeMicroseconds = mdsrDsrTimeMicroseconds;
			if (is_littlendian) {
				swap_endian_order(e_tid_long, &mdsrDsrTimeDays, 1);
				swap_endian_order(e_tid_ulong, &mdsrDsrTimeSeconds, 1);
				swap_endian_order(e_tid_ulong, &mdsrDsrTimeMicroseconds, 1);
			}
			bytesRead = bytesRead + 4 * fread(&mdsrGsrtTimeDays, 4, 1, imFilePtr);
			bytesRead = bytesRead + 4 * fread(&mdsrGsrtTimeSeconds, 4, 1, imFilePtr);
			bytesRead = bytesRead + 4 * fread(&mdsrGsrtTimeMicroseconds, 4, 1, imFilePtr);
			bytesRead = bytesRead + 2 * fread(&mdsrIspLength, 2, 1, imFilePtr);
			if (is_littlendian) {
				swap_endian_order(e_tid_ushort, &mdsrIspLength, 1);
			}
			mdsrILen = mdsrIspLength;
			if (is_littlendian) {
				swap_endian_order(e_tid_ushort, &mdsrIspLength, 1);
			}
			bytesRead = bytesRead + 2 * fread(&mdsrCrcErrs, 2, 1, imFilePtr);
			bytesRead = bytesRead + 2 * fread(&mdsrRsErrs, 2, 1, imFilePtr);
			bytesRead = bytesRead + 2 * fread(&mdsrSpare1, 2, 1, imFilePtr);

			/* 6-byte ISP Packet Header */
			bytesRead = bytesRead + 2 * fread(&mdsrPacketIdentification, 2, 1, imFilePtr);
			bytesRead = bytesRead + 2 * fread(&mdsrPacketSequenceControl, 2, 1, imFilePtr);
			bytesRead = bytesRead + 2 * fread(&mdsrPacketLength, 2, 1, imFilePtr);

			/* 30-byte Data Field Header in Packet Data Field */
			bytesRead = bytesRead + 30 * fread(&mdsrPacketDataHeader, 30, 1, imFilePtr);
			if (is_littlendian) {
				swap_endian_order(e_tid_ushort, &mdsrPacketDataHeader, 15);
			}
			modePacketCount = mdsrPacketDataHeader[5] * 256 + ((mdsrPacketDataHeader[6] >> 8) & 255);
			for (jjj = 0; jjj < 15; jjj++) {
				tempmdsrPacketDataHeader[jjj] = mdsrPacketDataHeader[jjj];
			}
			if (is_littlendian) {
				swap_endian_order(e_tid_ushort, &mdsrPacketDataHeader, 15);
			}

			if (((i) == 24890) || ((i) == 24891))
				printf("Line %6d of input file %d.  Output Line: %8d    "
				       "modePacketCount: %d\n",
				       i + 1, ii + 1, outLines + 1, modePacketCount);
			if ((modePacketCount == modePacketCountOld + 1) || (firstTimeEqualsZero == 0)) {

				firstTimeEqualsZero = 1;
				modePacketCountOld = modePacketCount;
				outLines = outLines + 1;
				bytesRead = bytesRead + (mdsrILen + 1 - 30) * fread(&mdsrLineChar, (mdsrILen + 1 - 30), 1, imFilePtr);

				if ((fwrite(&mdsrDsrTimeDays, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrDsrTimeSeconds, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrDsrTimeMicroseconds, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrGsrtTimeDays, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrGsrtTimeSeconds, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrGsrtTimeMicroseconds, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrIspLength, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrCrcErrs, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrRsErrs, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrSpare1, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrPacketIdentification, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrPacketSequenceControl, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrPacketLength, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrPacketDataHeader, 30, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrLineChar, (mdsrILen + 1 - 30), 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}

				bytesToBeWritten = bytesToBeWritten + 68 + (mdsrILen + 1 - 30);
			}
			else if ((modePacketCount > modePacketCountOld + 1) && (oldFrameID == FrameID)) {

				modePacketCountOld = modePacketCount;
				outLines = outLines + 1;
				bytesRead = bytesRead + (mdsrILen + 1 - 30) * fread(&mdsrLineChar, (mdsrILen + 1 - 30), 1, imFilePtr);

				if ((fwrite(&mdsrDsrTimeDays, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrDsrTimeSeconds, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrDsrTimeMicroseconds, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrGsrtTimeDays, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrGsrtTimeSeconds, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrGsrtTimeMicroseconds, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrIspLength, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrCrcErrs, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrRsErrs, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrSpare1, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrPacketIdentification, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrPacketSequenceControl, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrPacketLength, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrPacketDataHeader, 30, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrLineChar, (mdsrILen + 1 - 30), 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}

				bytesToBeWritten = bytesToBeWritten + 68 + (mdsrILen + 1 - 30);
			}
			else if (modePacketCount < modePacketCountOld + 1) {
				//             printf( "Line %5d : duplicate line\n", outLines +1 );
				duplicateLines = duplicateLines + 1;
				fseek(imFilePtr, mdsrILen + 1 - 30, SEEK_CUR);
				bytesRead = bytesRead + mdsrILen + 1 - 30;
			}
			else if ((modePacketCount > modePacketCountOld + 1) && (oldFrameID != FrameID) && (catAbortFlag == 1)) {
				printf("\nWARNING: No overlap between frames %d and %d.  Continuing "
				       "concatenation with with missing lines.\n",
				       modePacketCount, modePacketCountOld + 1);
				printf("At output Line %5d : Mode packet count at successive frame "
				       "edges - %d %d\n\n",
				       outLines + 1, modePacketCountOld, modePacketCount);
				printf("Number of missing lines: %d \n", modePacketCount - (modePacketCountOld + 1));
				nmsl = modePacketCount - (modePacketCountOld + 1);
				oldFrameID = FrameID;
				newt = ((double)newmdsrDsrTimeSeconds + newmdsrDsrTimeMicroseconds * 1e-06);
				oldt = ((double)oldmdsrDsrTimeSeconds + oldmdsrDsrTimeMicroseconds * 1e-06);
				delta1 = newt - oldt + ((newmdsrDsrTimeDays - oldmdsrDsrTimeDays) * 24. * 3600.);
				est_pri = delta1 / (double)(nmsl + 1);

				/* Fill missing lines with LUT indices corresponding to 127 and 128 for
				 * alternate samples */
				/* To get a byte value of 127 after decoding, first byte of block= 0,
				 * sample value = 10011001=153, corresponding to LUTi: -0.002563 LUTq:
				 * -0.002611 */
				/* To get a byte value of 128 after decoding, first byte of block= 0,
				 * sample value = 10001000=136, corresponding to LUTi:  0.001774 LUTq:
				 * 0.001816 */
				tempsamplecount = 0;
				for (jjj = 0; jjj < floor((mdsrILen + 1 - 30) / 64); jjj++) {
					tempmdsrLineChar[jjj * 64] = (unsigned char)(0);
					for (kkk = 1; kkk < 64; kkk++) {
						if (((tempsamplecount) % 2) == 1) {
							tempmdsrLineChar[jjj * 64 + kkk] = (unsigned char)(153);
						}
						else if (((tempsamplecount) % 2) == 0) {
							tempmdsrLineChar[jjj * 64 + kkk] = (unsigned char)(136);
						}
						tempsamplecount = tempsamplecount + 1;
					}
				}
				jjj = floor((mdsrILen + 1 - 30) / 64);
				tempmdsrLineChar[jjj * 64] = (unsigned char)(0);
				for (kkk = 1; kkk <= (((mdsrILen + 1 - 30) % 64) - 1); kkk++) {
					if (((tempsamplecount) % 2) == 1) {
						tempmdsrLineChar[jjj * 64 + kkk] = (unsigned char)(102);
					}
					else if (((tempsamplecount) % 2) == 0) {
						tempmdsrLineChar[jjj * 64 + kkk] = (unsigned char)(136);
					}
					tempsamplecount = tempsamplecount + 1;
				}

				for (msl = 1; msl <= nmsl; msl++) {
					temptimesec = oldt + (msl * est_pri);
					tempmdsrDsrTimeDays = oldmdsrDsrTimeDays;
					if (temptimesec > (24. * 3600.)) {
						temptimesec = temptimesec - 24. * 3600.;
						tempmdsrDsrTimeDays = tempmdsrDsrTimeDays + 1;
					}
					tempmdsrDsrTimeSeconds = floor(temptimesec);
					tempmdsrDsrTimeMicroseconds = floor((temptimesec - (double)(tempmdsrDsrTimeSeconds)) * 1e06);

					tempmdsrGsrtTimeDays = tempmdsrDsrTimeDays;
					tempmdsrGsrtTimeSeconds = tempmdsrDsrTimeSeconds;
					tempmdsrGsrtTimeMicroseconds = tempmdsrDsrTimeMicroseconds;
					tempmdsrIspLength = mdsrILen;
					tempmdsrILen = mdsrILen;
					tempmodePacketCount = modePacketCountOld + msl;
					tempmdsrPacketLength = mdsrILen;

					tempmdsrPacketDataHeader[5] = (unsigned short)(((tempmodePacketCount >> 8) & 65535));
					tempmdsrPacketDataHeader[6] = (unsigned short)(((tempmodePacketCount << 8) & 65280)) +
					                              (unsigned short)((tempmdsrPacketDataHeader[6]) & 255);
					if (is_littlendian) {
						swap_endian_order(e_tid_long, &tempmdsrDsrTimeDays, 1);
						swap_endian_order(e_tid_ulong, &tempmdsrDsrTimeSeconds, 1);
						swap_endian_order(e_tid_ulong, &tempmdsrDsrTimeMicroseconds, 1);
						swap_endian_order(e_tid_long, &tempmdsrGsrtTimeDays, 1);
						swap_endian_order(e_tid_ulong, &tempmdsrGsrtTimeSeconds, 1);
						swap_endian_order(e_tid_ulong, &tempmdsrGsrtTimeMicroseconds, 1);
						swap_endian_order(e_tid_ushort, &tempmdsrIspLength, 1);
						swap_endian_order(e_tid_ushort, &tempmdsrPacketLength, 1);
						swap_endian_order(e_tid_ushort, &tempmdsrPacketDataHeader, 15);
					}

					if ((fwrite(&tempmdsrDsrTimeDays, 4, 1, outFilePtr)) != 1) {
						printf("ERROR - outFile write error\n\n");
						exit(-1);
					}
					if ((fwrite(&tempmdsrDsrTimeSeconds, 4, 1, outFilePtr)) != 1) {
						printf("ERROR - outFile write error\n\n");
						exit(-1);
					}
					if ((fwrite(&tempmdsrDsrTimeMicroseconds, 4, 1, outFilePtr)) != 1) {
						printf("ERROR - outFile write error\n\n");
						exit(-1);
					}
					if ((fwrite(&tempmdsrGsrtTimeDays, 4, 1, outFilePtr)) != 1) {
						printf("ERROR - outFile write error\n\n");
						exit(-1);
					}
					if ((fwrite(&tempmdsrGsrtTimeSeconds, 4, 1, outFilePtr)) != 1) {
						printf("ERROR - outFile write error\n\n");
						exit(-1);
					}
					if ((fwrite(&tempmdsrGsrtTimeMicroseconds, 4, 1, outFilePtr)) != 1) {
						printf("ERROR - outFile write error\n\n");
						exit(-1);
					}
					if ((fwrite(&tempmdsrIspLength, 2, 1, outFilePtr)) != 1) {
						printf("ERROR - outFile write error\n\n");
						exit(-1);
					}
					if ((fwrite(&mdsrCrcErrs, 2, 1, outFilePtr)) != 1) {
						printf("ERROR - outFile write error\n\n");
						exit(-1);
					}
					if ((fwrite(&mdsrRsErrs, 2, 1, outFilePtr)) != 1) {
						printf("ERROR - outFile write error\n\n");
						exit(-1);
					}
					if ((fwrite(&mdsrSpare1, 2, 1, outFilePtr)) != 1) {
						printf("ERROR - outFile write error\n\n");
						exit(-1);
					}
					if ((fwrite(&mdsrPacketIdentification, 2, 1, outFilePtr)) != 1) {
						printf("ERROR - outFile write error\n\n");
						exit(-1);
					}
					if ((fwrite(&mdsrPacketSequenceControl, 2, 1, outFilePtr)) != 1) {
						printf("ERROR - outFile write error\n\n");
						exit(-1);
					}
					if ((fwrite(&tempmdsrPacketLength, 2, 1, outFilePtr)) != 1) {
						printf("ERROR - outFile write error\n\n");
						exit(-1);
					}
					if ((fwrite(&tempmdsrPacketDataHeader, 30, 1, outFilePtr)) != 1) {
						printf("ERROR - outFile write error\n\n");
						exit(-1);
					}
					if ((fwrite(&tempmdsrLineChar, (tempmdsrILen + 1 - 30), 1, outFilePtr)) != 1) {
						printf("ERROR - outFile write error\n\n");
						exit(-1);
					}

					if (is_littlendian) {
						swap_endian_order(e_tid_ushort, &tempmdsrPacketDataHeader, 15);
					}

					outLines = outLines + 1;
					bytesToBeWritten = bytesToBeWritten + 68 + (tempmdsrILen + 1 - 30);
				}
				modePacketCountOld = modePacketCount;
				outLines = outLines + 1;
				bytesRead = bytesRead + (mdsrILen + 1 - 30) * fread(&mdsrLineChar, (mdsrILen + 1 - 30), 1, imFilePtr);

				if ((fwrite(&mdsrDsrTimeDays, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrDsrTimeSeconds, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrDsrTimeMicroseconds, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrGsrtTimeDays, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrGsrtTimeSeconds, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrGsrtTimeMicroseconds, 4, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrIspLength, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrCrcErrs, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrRsErrs, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrSpare1, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrPacketIdentification, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrPacketSequenceControl, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrPacketLength, 2, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrPacketDataHeader, 30, 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}
				if ((fwrite(&mdsrLineChar, (mdsrILen + 1 - 30), 1, outFilePtr)) != 1) {
					printf("ERROR - outFile write error\n\n");
					exit(-1);
				}

				bytesToBeWritten = bytesToBeWritten + 68 + (mdsrILen + 1 - 30);
			}
			else if ((modePacketCount > modePacketCountOld + 1) && (oldFrameID != FrameID) && (catAbortFlag == 0)) {
				printf("\nWARNING: No overlap between frames. Aborting further "
				       "concatenation.\n");
				printf("At output Line %5d : Mode packet count at successive frame "
				       "edges - %d %d\n\n",
				       outLines + 1, modePacketCountOld, modePacketCount);

				sscanf(mph.sensingStop, "%2d-%3c-%4d %2d:%2d:%lf", &eday, emonthstr, &eyear, &ehour, &emin, &eseconds);
				if (strcmp(emonthstr, "JAN") == 0) {
					emonth = 1;
				}
				if (strcmp(emonthstr, "FEB") == 0) {
					emonth = 2;
				}
				if (strcmp(emonthstr, "MAR") == 0) {
					emonth = 3;
				}
				if (strcmp(emonthstr, "APR") == 0) {
					emonth = 4;
				}
				if (strcmp(emonthstr, "MAY") == 0) {
					emonth = 5;
				}
				if (strcmp(emonthstr, "JUN") == 0) {
					emonth = 6;
				}
				if (strcmp(emonthstr, "JUL") == 0) {
					emonth = 7;
				}
				if (strcmp(emonthstr, "AUG") == 0) {
					emonth = 8;
				}
				if (strcmp(emonthstr, "SEP") == 0) {
					emonth = 9;
				}
				if (strcmp(emonthstr, "OCT") == 0) {
					emonth = 10;
				}
				if (strcmp(emonthstr, "NOV") == 0) {
					emonth = 11;
				}
				if (strcmp(emonthstr, "DEC") == 0) {
					emonth = 12;
				}

				mjd_end = date2MJD(eyear, emonth, eday, ehour, emin, eseconds);
				memcpy(sensingStopTime, mphPtr + 380 + 14, 27);
				sprintf(ssensingStopTime, "%.27s", sensingStopTime);

				memcpy(mphPtr2 + 380 + 14, ssensingStopTime, 27);

				mjd_diffsec = (mjd_end - mjd_start) * 86400.0;
				imjd_diffsec = floor(mjd_diffsec);
				duration = imjd_diffsec;
				sprintf(secduration, "%08d", duration);
				memcpy(mphPtr2 + 0 + 9 + 30, secduration, 8);
				totfilesize = bytesToBeWritten + mphSize + mph.sphSize;
				sprintf(totsize, "%021d", totfilesize);

				memcpy(strchr(mphPtr2 + 1066 + 0, '=') + 1, totsize, 21);

				sprintf(ds_size, "%020d", bytesToBeWritten);
				sprintf(num_dsr, "%010d", outLines);

				memcpy(strchr(sphPtr2 + 836 + mph.dsdSize * 0 + 162 + 0, '=') + 2, ds_size, 20);
				memcpy(strchr(sphPtr2 + 836 + mph.dsdSize * 0 + 199 + 0, '=') + 2, num_dsr, 10);

				/* writing update MPH and SPH in outfile */
				fseek(outFilePtr, 0.0, SEEK_SET); /* go back to start of the file */

				printf("Writing updated MPH of output file...\n");
				if ((fwrite(mphPtr2, sizeof(char), mphSize, outFilePtr)) != mphSize) {
					printf(" ERROR - outFile write error\n\n");
					exit(-1);
				}

				printf("Writing updated SPH of output file...\n");
				if ((fwrite(sphPtr2, sizeof(char), mph.sphSize, outFilePtr)) != mph.sphSize) {
					printf(" ERROR - outFile write error\n\n");
					exit(-1);
				}
				free(mphPtr2);
				free(sphPtr2);
				fclose(outFilePtr);

				exit(-1);
			}

			oldmdsrDsrTimeDays = newmdsrDsrTimeDays;
			oldmdsrDsrTimeSeconds = newmdsrDsrTimeSeconds;
			oldmdsrDsrTimeMicroseconds = newmdsrDsrTimeMicroseconds;

		} /* end for of each data line,i */

		/* updating the MPH and SPH of concatenated data */

		if (ii == (numFiles - 1)) {
			sscanf(mph.sensingStop, "%2d-%3c-%4d %2d:%2d:%lf", &eday, emonthstr, &eyear, &ehour, &emin, &eseconds);
			if (strcmp(emonthstr, "JAN") == 0) {
				emonth = 1;
			}
			if (strcmp(emonthstr, "FEB") == 0) {
				emonth = 2;
			}
			if (strcmp(emonthstr, "MAR") == 0) {
				emonth = 3;
			}
			if (strcmp(emonthstr, "APR") == 0) {
				emonth = 4;
			}
			if (strcmp(emonthstr, "MAY") == 0) {
				emonth = 5;
			}
			if (strcmp(emonthstr, "JUN") == 0) {
				emonth = 6;
			}
			if (strcmp(emonthstr, "JUL") == 0) {
				emonth = 7;
			}
			if (strcmp(emonthstr, "AUG") == 0) {
				emonth = 8;
			}
			if (strcmp(emonthstr, "SEP") == 0) {
				emonth = 9;
			}
			if (strcmp(emonthstr, "OCT") == 0) {
				emonth = 10;
			}
			if (strcmp(emonthstr, "NOV") == 0) {
				emonth = 11;
			}
			if (strcmp(emonthstr, "DEC") == 0) {
				emonth = 12;
			}

			mjd_end = date2MJD(eyear, emonth, eday, ehour, emin, eseconds);
			memcpy(sensingStopTime, mphPtr + 380 + 14, 27);
			sprintf(ssensingStopTime, "%.27s", sensingStopTime);
		}
		oldFrameID = FrameID;

		free(mphPtr);
		free(sphPtr);
		fclose(imFilePtr);

	} /* end of for ii, input files*/

	printf("\nNumber of duplicate lines found between overlapping frames: %8d\n", duplicateLines);
	printf("\nTotal number of lines in output files:  %8d\n", outLines);

	/* updating the sensing stop time in MPH */
	memcpy(mphPtr2 + 380 + 14, ssensingStopTime, 27);

	/* Update duration on product name in MPH */
	mjd_diffsec = (mjd_end - mjd_start) * 86400.0;
	imjd_diffsec = floor(mjd_diffsec);

	duration = imjd_diffsec;
	sprintf(secduration, "%08d", duration);

	memcpy(mphPtr2 + 0 + 9 + 30, secduration, 8);

	/* Update DSD_SIZE and NUM_DSR in SPH of output frame file pointer */
	totfilesize = bytesToBeWritten + mphSize + mph.sphSize;
	sprintf(totsize, "%021d", totfilesize);

	memcpy(strchr(mphPtr2 + 1066 + 0, '=') + 1, totsize, 21);

	sprintf(ds_size, "%020d", bytesToBeWritten);
	sprintf(num_dsr, "%010d", outLines);

	memcpy(strchr(sphPtr2 + 836 + mph.dsdSize * 0 + 162 + 0, '=') + 2, ds_size, 20);
	memcpy(strchr(sphPtr2 + 836 + mph.dsdSize * 0 + 199 + 0, '=') + 2, num_dsr, 10);

	/* writing update MPH and SPH in outfile */
	fseek(outFilePtr, 0.0, SEEK_SET); /* go back to start of the file */

	printf("\nWriting updated MPH of output file...\n");
	if ((fwrite(mphPtr2, sizeof(char), mphSize, outFilePtr)) != mphSize) {
		printf(" ERROR - outFile write error\n\n");
		exit(-1);
	}

	printf("Writing updated SPH of output file...\n");
	if ((fwrite(sphPtr2, sizeof(char), mph.sphSize, outFilePtr)) != mph.sphSize) {
		printf(" ERROR - outFile write error\n\n");
		exit(-1);
	}

	free(mphPtr2);
	free(sphPtr2);
	fclose(outFilePtr);

	printf("\nDone.\n\n");
	return 0;

} /* end main */

/**********************************************************************************************************************************/

struct mphStruct readMph(const char *mphPtr, const int printMphIfZero) {

	struct mphStruct mph;

	if (1 == 0) {
		printf("check:\n%s\n", mphPtr + 1247);
	}

	memcpy(mph.product, mphPtr + 0 + 9, 62);
	memcpy(mph.procStage, mphPtr + 73 + 11, 1);
	memcpy(mph.refDoc, mphPtr + 86 + 9, 23);
	memcpy(mph.spare1, mphPtr + 120 + 0, 40);
	memcpy(mph.acquisitionStation, mphPtr + 161 + 21, 20);
	memcpy(mph.procCenter, mphPtr + 204 + 13, 6);
	memcpy(mph.procTime, mphPtr + 225 + 11, 27);
	memcpy(mph.softwareVer, mphPtr + 265 + 14, 14);
	memcpy(mph.spare2, mphPtr + 295 + 0, 40);
	memcpy(mph.sensingStart, mphPtr + 336 + 15, 27);
	memcpy(mph.sensingStop, mphPtr + 380 + 14, 27);
	memcpy(mph.spare3, mphPtr + 423 + 0, 40);
	memcpy(mph.phase, mphPtr + 464 + 6, 1);
	mph.cycle = atoi((char *)strchr(mphPtr + 472 + 0, '=') + 1);
	mph.relOrbit = atoi((char *)strchr(mphPtr + 483 + 0, '=') + 1);
	mph.absOrbit = atoi((char *)strchr(mphPtr + 500 + 0, '=') + 1);
	memcpy(mph.stateVectorTime, mphPtr + 517 + 19, 27);
	mph.deltaUt1 = atof((char *)strchr(mphPtr + 565 + 0, '=') + 1);
	mph.xPosition = atof((char *)strchr(mphPtr + 587 + 0, '=') + 1);
	mph.yPosition = atof((char *)strchr(mphPtr + 614 + 0, '=') + 1);
	mph.zPosition = atof((char *)strchr(mphPtr + 641 + 0, '=') + 1);
	mph.xVelocity = atof((char *)strchr(mphPtr + 668 + 0, '=') + 1);
	mph.yVelocity = atof((char *)strchr(mphPtr + 697 + 0, '=') + 1);
	mph.zVelocity = atof((char *)strchr(mphPtr + 726 + 0, '=') + 1);
	memcpy(mph.vectorSource, mphPtr + 755 + 15, 2);
	memcpy(mph.spare4, mphPtr + 774 + 0, 40);
	memcpy(mph.utcSbtTime, mphPtr + 815 + 14, 27);
	mph.satBinaryTime = atoi((char *)strchr(mphPtr + 858 + 0, '=') + 1);
	mph.clockStep = atoi((char *)strchr(mphPtr + 886 + 0, '=') + 1);
	memcpy(mph.spare5, mphPtr + 913 + 0, 32);
	memcpy(mph.leapUtc, mphPtr + 946 + 10, 27);
	mph.leapSign = atoi((char *)strchr(mphPtr + 985 + 0, '=') + 1);
	mph.leapErr = atoi((char *)strchr(mphPtr + 1000 + 0, '=') + 1);
	memcpy(mph.spare6, mphPtr + 1011 + 0, 40);
	mph.productErr = atoi((char *)strchr(mphPtr + 1052 + 0, '=') + 1);
	mph.totSize = atoi((char *)strchr(mphPtr + 1066 + 0, '=') + 1);
	mph.sphSize = atoi((char *)strchr(mphPtr + 1104 + 0, '=') + 1);
	mph.numDsd = atoi((char *)strchr(mphPtr + 1132 + 0, '=') + 1);
	mph.dsdSize = atoi((char *)strchr(mphPtr + 1152 + 0, '=') + 1);
	mph.numDataSets = atoi((char *)strchr(mphPtr + 1180 + 0, '=') + 1);
	memcpy(mph.spare7, mphPtr + 1206 + 0, 40);

	if (printMphIfZero == 0) {
		printf("%s%.62s\n", "product:                 ", mph.product);
		printf("%s%.1s\n", "procStage:               ", mph.procStage);
		printf("%s%.23s\n", "refDoc:                  ", mph.refDoc);
		printf("%s%.40s\n", "spare1:                  ", mph.spare1);
		printf("%s%.20s\n", "acquisitionStation:      ", mph.acquisitionStation);
		printf("%s%.6s\n", "procCenter:              ", mph.procCenter);
		printf("%s%.27s\n", "procTime:                ", mph.procTime);
		printf("%s%.14s\n", "softwareVer:             ", mph.softwareVer);
		printf("%s%.40s\n", "spare2:                  ", mph.spare2);
		printf("%s%.27s\n", "sensingStart:            ", mph.sensingStart);
		printf("%s%.27s\n", "sensingStop:             ", mph.sensingStop);
		printf("%s%.40s\n", "spare3:                  ", mph.spare3);
		printf("%s%.1s\n", "phase:                   ", mph.phase);
		printf("%s%d\n", "cycle:                   ", mph.cycle);
		printf("%s%d\n", "relOrbit:                ", mph.relOrbit);
		printf("%s%d\n", "absOrbit:                ", mph.absOrbit);
		printf("%s%.27s\n", "stateVectorTime:         ", mph.stateVectorTime);
		printf("%s%f\n", "deltaUt1:                ", mph.deltaUt1);
		printf("%s%f\n", "xPosition:               ", mph.xPosition);
		printf("%s%f\n", "yPosition:               ", mph.yPosition);
		printf("%s%f\n", "zPosition:               ", mph.zPosition);
		printf("%s%f\n", "xVelocity:               ", mph.xVelocity);
		printf("%s%f\n", "yVelocity:               ", mph.yVelocity);
		printf("%s%f\n", "zVelocity:               ", mph.zVelocity);
		printf("%s%.2s\n", "vectorSource:            ", mph.vectorSource);
		printf("%s%.40s\n", "spare4:                  ", mph.spare4);
		printf("%s%.27s\n", "utcSbtTime:              ", mph.utcSbtTime);
		printf("%s%u\n", "satBinaryTime:           ", mph.satBinaryTime);
		printf("%s%u\n", "clockStep:               ", mph.clockStep);
		printf("%s%.32s\n", "spare5:                  ", mph.spare5);
		printf("%s%.27s\n", "leapUtc:                 ", mph.leapUtc);
		printf("%s%d\n", "leapSign:                ", mph.leapSign);
		printf("%s%d\n", "leapErr:                 ", mph.leapErr);
		printf("%s%.40s\n", "spare6:                  ", mph.spare6);
		printf("%s%d\n", "productErr:              ", mph.productErr);
		printf("%s%d\n", "totSize:                 ", mph.totSize);
		printf("%s%d\n", "sphSize:                 ", mph.sphSize);
		printf("%s%d\n", "numDsd:                  ", mph.numDsd);
		printf("%s%d\n", "dsdSize:                 ", mph.dsdSize);
		printf("%s%d\n", "numDataSets:             ", mph.numDataSets);
		printf("%s%.40s\n", "spare7:                  ", mph.spare7);
		printf("\n");
	}

	return mph;

} /* end readMph */

/**********************************************************************************************************************************/

/**********************************************************************************************************************************/

struct sphStruct readSph(const char *sphPtr, const int printSphIfZero, const struct mphStruct mph) {

	struct sphStruct sph;
	int i;

	memcpy(sph.sphDescriptor, sphPtr + 0 + 16, 28);
	sph.startLat = atof((char *)strchr(sphPtr + 46 + 0, '=') + 1) * 1.e-6;
	sph.startLon = atof((char *)strchr(sphPtr + 78 + 0, '=') + 1) * 1.e-6;
	sph.stopLat = atof((char *)strchr(sphPtr + 111 + 0, '=') + 1) * 1.e-6;
	sph.stopLon = atof((char *)strchr(sphPtr + 142 + 0, '=') + 1) * 1.e-6;
	sph.satTrack = atof((char *)strchr(sphPtr + 174 + 0, '=') + 1);
	memcpy(sph.spare1, sphPtr + 205 + 0, 50);
	sph.ispErrorsSignificant = atoi((char *)strchr(sphPtr + 256 + 0, '=') + 1);
	sph.missingIspsSignificant = atoi((char *)strchr(sphPtr + 281 + 0, '=') + 1);
	sph.ispDiscardedSignificant = atoi((char *)strchr(sphPtr + 308 + 0, '=') + 1);
	sph.rsSignificant = atoi((char *)strchr(sphPtr + 336 + 0, '=') + 1);
	memcpy(sph.spare2, sphPtr + 353 + 0, 50);
	sph.numErrorIsps = atoi((char *)strchr(sphPtr + 404 + 0, '=') + 1);
	sph.errorIspsThresh = atof((char *)strchr(sphPtr + 431 + 0, '=') + 1);
	sph.numMissingIsps = atoi((char *)strchr(sphPtr + 468 + 0, '=') + 1);
	sph.missingIspsThresh = atof((char *)strchr(sphPtr + 497 + 0, '=') + 1);
	sph.numDiscardedIsps = atoi((char *)strchr(sphPtr + 536 + 0, '=') + 1);
	sph.discardedIspsThresh = atof((char *)strchr(sphPtr + 567 + 0, '=') + 1);
	sph.numRsIsps = atoi((char *)strchr(sphPtr + 608 + 0, '=') + 1);
	sph.rsThresh = atof((char *)strchr(sphPtr + 632 + 0, '=') + 1);
	memcpy(sph.spare3, sphPtr + 661 + 0, 100);
	memcpy(sph.txRxPolar, sphPtr + 762 + 13, 5);
	memcpy(sph.swath, sphPtr + 782 + 7, 3);
	memcpy(sph.spare4, sphPtr + 794 + 0, 41);

	if (1 == 0) {
		printf("check:\n%s\n", sphPtr + 836 + 0);
	}

	if (printSphIfZero == 0) {
		printf("%s%.28s\n", "sphDescriptor:           ", sph.sphDescriptor);
		printf("%s%f\n", "startLat:                ", sph.startLat);
		printf("%s%f\n", "startLon:                ", sph.startLon);
		printf("%s%f\n", "stopLat:                 ", sph.stopLat);
		printf("%s%f\n", "stopLon:                 ", sph.stopLon);
		printf("%s%f\n", "satTrack:                ", sph.satTrack);
		printf("%s%.50s\n", "spare1:                  ", sph.spare1);
		printf("%s%d\n", "ispErrorsSignificant:    ", sph.ispErrorsSignificant);
		printf("%s%d\n", "missingIspsSignificant:  ", sph.missingIspsSignificant);
		printf("%s%d\n", "ispDiscardedSignificant: ", sph.ispDiscardedSignificant);
		printf("%s%d\n", "rsSignificant:           ", sph.rsSignificant);
		printf("%s%.50s\n", "spare2:                  ", sph.spare2);
		printf("%s%d\n", "numErrorIsps:            ", sph.numErrorIsps);
		printf("%s%f\n", "errorIspsThresh:         ", sph.errorIspsThresh);
		printf("%s%d\n", "numMissingIsps:          ", sph.numMissingIsps);
		printf("%s%f\n", "missingIspsThresh:       ", sph.missingIspsThresh);
		printf("%s%d\n", "numDiscardedIsps:        ", sph.numDiscardedIsps);
		printf("%s%f\n", "discardedIspsThresh:     ", sph.discardedIspsThresh);
		printf("%s%d\n", "numRsIsps:               ", sph.numRsIsps);
		printf("%s%f\n", "rsThresh:                ", sph.rsThresh);
		printf("%s%.100s\n", "spare3:                  ", sph.spare3);
		printf("%s%.5s\n", "txRxPolar:               ", sph.txRxPolar);
		printf("%s%.3s\n", "swath:                   ", sph.swath);
		printf("%s%.41s\n", "spare4:                  ", sph.spare4);
	}

	for (i = 0; i < mph.numDsd; i++) { /* extract DSDs from SPH */
		if (i != 3) {                  /* fourth is a spare DSD - see pdf page 537 */
			if (1 == 0) {
				printf("check:\n%s\n", sphPtr + 836 + mph.dsdSize * i + 0 + 0);
			}
			memcpy(sph.dsd[i].dsName, sphPtr + 836 + mph.dsdSize * i + 0 + 9, 28);
			memcpy(sph.dsd[i].dsType, sphPtr + 836 + mph.dsdSize * i + 39 + 8, 1);
			memcpy(sph.dsd[i].filename, sphPtr + 836 + mph.dsdSize * i + 49 + 10, 62);
			sph.dsd[i].dsOffset = atoi((char *)strchr(sphPtr + 836 + mph.dsdSize * i + 123 + 0, '=') + 1);
			sph.dsd[i].dsSize = atoi((char *)strchr(sphPtr + 836 + mph.dsdSize * i + 162 + 0, '=') + 1);
			sph.dsd[i].numDsr = atoi((char *)strchr(sphPtr + 836 + mph.dsdSize * i + 199 + 0, '=') + 1);
			sph.dsd[i].dsrSize = atoi((char *)strchr(sphPtr + 836 + mph.dsdSize * i + 219 + 0, '=') + 1);
			/* write out a few things */
			if (printSphIfZero == 0) {
				printf("%s%d%s%.28s\n", "dsd[ ", i, " ].dsName:         ", sph.dsd[i].dsName);
				printf("%s%d%s%.1s\n", "dsd[ ", i, " ].dsType:         ", sph.dsd[i].dsType);
				printf("%s%d%s%.62s\n", "dsd[ ", i, " ].filename:       ", sph.dsd[i].filename);
				printf("%s%d%s%d\n", "dsd[ ", i, " ].dsOffset:       ", sph.dsd[i].dsOffset);
				printf("%s%d%s%d\n", "dsd[ ", i, " ].dsSize:         ", sph.dsd[i].dsSize);
				printf("%s%d%s%d\n", "dsd[ ", i, " ].numDsr:         ", sph.dsd[i].numDsr);
				printf("%s%d%s%d\n", "dsd[ ", i, " ].dsrSize:        ", sph.dsd[i].dsrSize);
			}
		}
	}

	if (printSphIfZero == 0) {
		printf("\n");
	}

	return sph;

} /* end readSph */

/**********************************************************************************************************************************/

/**********************************************************************************************************************************/

struct sphAuxStruct readSphAux(const char *sphPtr, const int printSphIfZero, const struct mphStruct mph) {

	struct sphAuxStruct sph;
	int i;

	memcpy(sph.sphDescriptor, sphPtr + 0 + 16, 28);
	memcpy(sph.spare1, sphPtr + 46 + 0, 51);

	if (printSphIfZero == 0) {
		printf("%s%.28s\n", "sphDescriptor:           ", sph.sphDescriptor);
		printf("%s%.51s\n", "spare1:                  ", sph.spare1);
	}

	for (i = 0; i < mph.numDsd; i++) { /* extract DSDs from SPH */
		memcpy(sph.dsd[i].dsName, sphPtr + 98 + mph.dsdSize * i + 0 + 9, 28);
		memcpy(sph.dsd[i].dsType, sphPtr + 98 + mph.dsdSize * i + 39 + 8, 1);
		memcpy(sph.dsd[i].filename, sphPtr + 98 + mph.dsdSize * i + 49 + 10, 62);
		sph.dsd[i].dsOffset = atoi((char *)strchr(sphPtr + 98 + mph.dsdSize * i + 123 + 0, '=') + 1);
		sph.dsd[i].dsSize = atoi((char *)strchr(sphPtr + 98 + mph.dsdSize * i + 162 + 0, '=') + 1);
		sph.dsd[i].numDsr = atoi((char *)strchr(sphPtr + 98 + mph.dsdSize * i + 199 + 0, '=') + 1);
		sph.dsd[i].dsrSize = atoi((char *)strchr(sphPtr + 98 + mph.dsdSize * i + 219 + 0, '=') + 1);
		/* write out a few things */
		if (printSphIfZero == 0) {
			printf("%s%d%s%.28s\n", "dsd[ ", i, " ].dsName:         ", sph.dsd[i].dsName);
			printf("%s%d%s%.1s\n", "dsd[ ", i, " ].dsType:         ", sph.dsd[i].dsType);
			printf("%s%d%s%.62s\n", "dsd[ ", i, " ].filename:       ", sph.dsd[i].filename);
			printf("%s%d%s%d\n", "dsd[ ", i, " ].dsOffset:       ", sph.dsd[i].dsOffset);
			printf("%s%d%s%d\n", "dsd[ ", i, " ].dsSize:         ", sph.dsd[i].dsSize);
			printf("%s%d%s%d\n", "dsd[ ", i, " ].numDsr:         ", sph.dsd[i].numDsr);
			printf("%s%d%s%d\n", "dsd[ ", i, " ].dsrSize:        ", sph.dsd[i].dsrSize);
		}
	}

	if (printSphIfZero == 0) {
		printf("\n");
	}

	return sph;

} /* end readSphAux */

/**********************************************************************************************************************************/

/**********************************************************************************************************************************/
/**********************************************************************************************************************************/
/**********************************************************
 ** Function: is_bigendian
 **
 ** Purpose: Test whether it is a bigendian machine
 **
 **	Return values: true: 1, false: 0
 **
 ** Comment:
 **
 ** Author: Eric J Fielding at JPL
 **
 ** Created:
 **
 ** Modified:
 **
;**********************************************************/
int is_bigendian() {

	int bigendian, littleendian, test;
	unsigned char t[4];

	littleendian = 256;
	bigendian = 256 * 256;

	t[0] = 0;
	t[1] = 1;
	t[2] = 0;
	t[3] = 0;

	memcpy(&test, &t[0], 4);

	/* printf("test: %i\n",test); */
	if (test == bigendian)
		return (1);
	if (test == littleendian)
		return (0);
	printf("Error in endian test, test= %i ********\n", test);
	return (-1);
}

/*
 * Function: byte_swap_short.c
 */
/**
 *
 * Swaps bytes within NUMBER_OF_SWAPS two-byte words,
 *   starting at address BUFFER.
 *
 * @param buffer the one element typed buffer
 * to convert for a little endian order machine
 *
 * @param number_of_swaps number of elements to convert
 *
 */
void byte_swap_short(short *buffer, uint number_of_swaps) {
	short *temp = buffer;
	uint swap_loop;

	for (swap_loop = 0, temp = buffer; swap_loop < number_of_swaps; swap_loop++, temp++) {
		*temp = (short)(((*temp & 0x00ff) << 8) | ((*temp & 0xff00) >> 8));
	}
}

/*
   Function: byte_swap_long.c
*/
/**
 *
 *  Swaps bytes within NUMBER_OF_SWAPS four-byte words,
 *     starting at address BUFFER.
 *
 *
 */
void byte_swap_long(int64_t *buffer, uint number_of_swaps) {
	int64_t *temp = buffer;
	uint swap_loop;

	for (swap_loop = 0, temp = buffer; swap_loop < number_of_swaps; swap_loop++, temp++) {
		*temp = ((*temp & 0x000000ff) << 24) | ((*temp & 0x0000ff00) << 8) | ((*temp & 0x00ff0000) >> 8) |
		        ((*temp & 0xff000000) >> 24);
	}
}

/* ADDED THESE LINES TO TEST THE 4-BYTE INT TYPE ON 64 BIT */
/*
   Function: byte_swap_int.c
*/
/**
 *
 *  Swaps bytes within NUMBER_OF_SWAPS four-byte words,
 *     starting at address BUFFER.
 *
 *
 */
void byte_swap_int(int *buffer, uint number_of_swaps) {
	int *temp = buffer;
	uint swap_loop;

	for (swap_loop = 0, temp = buffer; swap_loop < number_of_swaps; swap_loop++, temp++) {
		*temp = ((*temp & 0x000000ff) << 24) | ((*temp & 0x0000ff00) << 8) | ((*temp & 0x00ff0000) >> 8) |
		        ((*temp & 0xff000000) >> 24);
	}
}
/*
   Function: byte_swap_uint.c
*/
/**
 *
 *  Swaps bytes within NUMBER_OF_SWAPS four-byte words,
 *     starting at address BUFFER.
 *
 *
 */
void byte_swap_uint(uint *buffer, uint number_of_swaps) {
	uint *temp = buffer;
	uint swap_loop;

	for (swap_loop = 0, temp = buffer; swap_loop < number_of_swaps; swap_loop++, temp++) {
		*temp = ((*temp & 0x000000ff) << 24) | ((*temp & 0x0000ff00) << 8) | ((*temp & 0x00ff0000) >> 8) |
		        ((*temp & 0xff000000) >> 24);
	}
}
/* ADDDED NEW LINES ABOVE */
/*  **************************************************************************
 */

/*
   Function: byte_swap_short.c
*/
/**
 *
 * Swaps bytes within NUMBER_OF_SWAPS two-byte words,
 *   starting at address BUFFER.
 *
 * @param buffer the one element typed buffer
 * to convert for a little endian order machine
 *
 * @param number_of_swaps number of elements to convert
 *
 */
void byte_swap_ushort(ushort *buffer, uint number_of_swaps) { byte_swap_short((short *)buffer, number_of_swaps); }

/*
 *  Function: byte_swap_ulong.c
 */
/**
 *
 * Swaps bytes within NUMBER_OF_SWAPS four-byte words,
 *     starting at address BUFFER.
 *
 * @param buffer the one element typed buffer
 * to convert for a little endian order machine
 *
 * @param number_of_swaps number of elements to convert
 *
 */
void byte_swap_ulong(ulong *buffer, uint number_of_swaps) { byte_swap_long((int64_t *)buffer, number_of_swaps); }

/*
 *  Function: byte_swap_long.c
 */
/**
 *
 * Swaps bytes within NUMBER_OF_SWAPS four-byte words,
 *     starting at address BUFFER.
 *
 * @param buffer the one element typed buffer
 * to convert for a little endian order machine
 *
 * @param number_of_swaps number of elements to convert
 *
 */
void byte_swap_float(float *buffer, uint number_of_swaps) { byte_swap_int((int *)buffer, number_of_swaps); }

/*
   Function:    epr_swap_endian_order
   Access:      public API
   Changelog:   2002/02/04  mp nitial version
 */
/**
 * Converts bytes for a little endian order machine
 *
 * @param field the pointer at data reading in
 *
 */
void swap_endian_order(EPR_EDataTypeId data_type_id, void *elems, uint num_elems) {
	switch (data_type_id) {
	case e_tid_uchar:
	case e_tid_char:
	case e_tid_string:
		/* no conversion required */
		break;
	case e_tid_time:
		byte_swap_uint((uint *)elems, 3);
		break;
	case e_tid_spare:
		/* no conversion required */
		break;
	case e_tid_ushort:
		byte_swap_ushort((ushort *)elems, num_elems);
		break;
	case e_tid_short:
		byte_swap_short((short *)elems, num_elems);
		break;
	case e_tid_ulong:
		byte_swap_uint((uint *)elems, num_elems);
		break;
	case e_tid_long:
		byte_swap_int((int *)elems, num_elems);
		break;
	case e_tid_float:
		byte_swap_float((float *)elems, num_elems);
		break;
	case e_tid_double:
		printf("swap_endian_order: DOUBLE type was not yet processed\n");
		break;
	default:
		printf("swap_endian_order: unknown data type\n");
	}
}

double date2MJD(int yr, int mo, int day, int hr, int min, double sec) {
	/* convert to date to MJD */
	double part1, part2;
	double JD, MJD;

	part1 = 367 * ((double)yr) - floor(7 * ((double)yr + floor(((double)mo + 9) / 12.0)) / 4.0) + floor(275 * (double)mo / 9.0) +
	        (double)day;
	part2 = 1721013.5 + ((sec / 60.0 + (double)min) / 60.0 + (double)hr) / 24.0;

	JD = part1 + part2;
	MJD = JD - 2400000.5;

	return MJD;
}

void bubbleSort(double array[], int len) {

	double tmp;
	int pass;
	int j;

	for (pass = 0; pass < len - 1; pass++) {
		for (j = 0; j < len - 1 - pass; j++) {
			if (array[j + 1] < array[j]) {
				tmp = array[j];
				array[j] = array[j + 1];
				array[j + 1] = tmp;
			}
		}
	}
}
