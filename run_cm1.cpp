#include <iostream>
#include <fstream>
#include <string>

#include "mpi.h"
#include "datastructs.h"
#include "macros.cpp"
#include "readlofs.cpp"
#include "integrate.h"
#include "writenc.cpp"

using namespace std;

/* Utility function to find the nearest index to a
 * time value provided. It searches the array for the
 * closest value to the one provided and returns the index.
 * If the value isn't found, the index is returned as -1.
 */
int find_nearest_index(double *arr, double val, int N) {
    int nearest = -1;
    float mindist = 9999;
    for (int idx = 0; idx < N; ++idx) {
        float diff = fabs(val - arr[idx]);
        if (diff < mindist) {
            mindist = diff;
            nearest = idx;
        }
    }
    return nearest;
}

void nearest_grid_idx(float *point, datagrid *grid, int *idx_4D) {

	int near_i = -1;
	int near_j = -1;
	int near_k = -1;

    float pt_x = point[0];
    float pt_y = point[1];
    float pt_z = point[2];


	// loop over the X grid
	for ( int i = 0; i < grid->NX; i++ ) {
		// find the nearest grid point index at X
		if ( ( pt_x >= grid->xf[i] ) && ( pt_x <= grid->xf[i+1] ) ) { near_i = i; } 
	}

	// loop over the Y grid
	for ( int j = 0; j < grid->NY; j++ ) {
		// find the nearest grid point index in the Y
		if ( ( pt_y >= grid->yf[j] ) && ( pt_y <= grid->yf[j+1] ) ) { near_j = j; } 
	}

	// loop over the Z grid
    int k = 1;
    while (pt_z >= grid->zf[k+1]) {
        k = k + 1;
    }
    near_k = k;

	// if a nearest index was not found, set all indices to -1 to flag
	// that the point is not in the domain
	if ((near_i == -1) || (near_j == -1) || (near_k == -1)) {
		near_i = -1; near_j = -1; near_k = -1;
	}

	idx_4D[0] = near_i; idx_4D[1] = near_j; idx_4D[2] = near_k;
	return;
}

// this was stolen from LOFS/cm1tools-3.0 hdf2.c
// under the parce_cmdline_hdf2nc function. I could
// have just linked to it, but I want the LOFS dependency
// to only be I/O so that other backends can be used, hence
// copying it here.

/* The command line parser takes information from the user
 * on where to put the parcel initial seeds, how many parcels,
 * and the spacing between parcels. It also is where the user
 * specifies the integration start time and duration.
 */
void parse_cmdline(int argc, char **argv, \
	char *histpath, char *base, double *time, int *nTimes, int *direction, \
	float *X0, float *Y0, float *Z0, int *NX, int *NY, int *NZ, \
    float *DX, float *DY, float *DZ )
{
	int got_histpath,got_base,got_time,got_ntimes,got_X0,got_NX,got_Y0,got_NY,got_Z0,got_NZ,got_DX,got_DY,got_DZ;
    int optcount=0;
	enum { OPT_HISTPATH = 1000, OPT_BASE, OPT_TIME, OPT_NTIMES, OPT_X0, OPT_Y0, OPT_Z0, OPT_NX, OPT_NY, OPT_NZ, OPT_DX,
		OPT_DY, OPT_DZ, OPT_DEBUG, OPT_DIRECTION };
	// see https://stackoverflow.com/questions/23758570/c-getopt-long-only-without-alias
	static struct option long_options[] =
	{
		{"histpath", required_argument, 0, OPT_HISTPATH},
		{"base",     required_argument, 0, OPT_BASE},
		{"time",     required_argument, 0, OPT_TIME},
		{"ntimes",   required_argument, 0, OPT_NTIMES},
		{"x0",       required_argument, 0, OPT_X0},
		{"y0",       required_argument, 0, OPT_Y0},
		{"z0",       required_argument, 0, OPT_Z0},
		{"nx",       required_argument, 0, OPT_NX},
		{"ny",       required_argument, 0, OPT_NY},
		{"nz",       required_argument, 0, OPT_NZ},
		{"dx",       required_argument, 0, OPT_DX},
		{"dy",       required_argument, 0, OPT_DY},
		{"dz",       required_argument, 0, OPT_DZ},
		{"direction",optional_argument, 0, OPT_DIRECTION},
		{"debug",    optional_argument, 0, OPT_DEBUG},
		{0, 0, 0, 0}//sentinel, needed!
	};

	got_histpath=got_base=got_time=got_ntimes=got_X0=got_NX=got_DX=got_Y0=got_NY=got_DY=got_Z0=got_NZ=got_DZ=0;

	int bail = 0;

    // print the usage information for the
    // command line options
	if (argc == 1)
	{
		fprintf(stderr,
		"Usage: %s --histpath=[histpath] --base=[base] --x0=[X0] --y0=[Y0] --z0=[Z0] --nx=[NX] --ny=[NY] --nz=[NZ] --dx=[DX] --dy=[DY] --dz=[DZ] --direction=[-1|1] --time=[time] --ntimes[nTimes]\n\
        --direction=-1 specifies backward trajectory, forward is default\n",argv[0]);
		exit(0);
	}

	while (1)
	{
		int r;
		int option_index = 0;
		r = getopt_long_only (argc, argv,"",long_options,&option_index);
		if (r == -1) break;

		switch(r)
		{
			case OPT_HISTPATH:
				strcpy(histpath,optarg);
				got_histpath=1;
				printf("histpath = %s\n",histpath);
				break;
			case OPT_BASE:
				strcpy(base,optarg);
				got_base=1;
				printf("base = %s\n",base);
				break;
			case OPT_TIME:
				*time = atof(optarg);
				got_time=1;
				printf("parcel start time time = %f\n",*time);
				break;
			case OPT_NTIMES:
				*nTimes = atoi(optarg);
				got_ntimes=1;
				printf("number of steps to integrate ntimes = %i\n",*nTimes);
				break;
			case OPT_X0:
				*X0 = atof(optarg);
				got_X0=1;
				optcount++;
				printf("parcel seed start X0 = %f\n",*X0);
				break;
			case OPT_Y0:
				*Y0 = atof(optarg);
				got_Y0=1;
				optcount++;
				printf("parcel seed start Y0 = %f\n",*Y0);
				break;
			case OPT_Z0:
				*Z0 = atof(optarg);
				got_Z0=1;
				optcount++;
				printf("parcel seed start Z0 = %f\n",*Z0);
				break;
			case OPT_NX:
				*NX = atoi(optarg);
				got_NX=1;
				optcount++;
				printf("number of parcels NX = %i\n",*NX);
				break;
			case OPT_NY:
				*NY = atoi(optarg);
				got_NY=1;
				optcount++;
				printf("number of parcels NY = %i\n",*NY);
				break;
			case OPT_NZ:
				*NZ = atoi(optarg);
				got_NZ=1;
				optcount++;
				printf("number of parcels NZ = %i\n",*NZ);
				break;
			case OPT_DX:
				*DX = atof(optarg);
				got_DX=1;
				optcount++;
				printf("spacing of parcels DX = %f\n",*DX);
				break;
			case OPT_DY:
				*DY = atof(optarg);
				got_DY=1;
				optcount++;
				printf("spacing of parcels DY = %f\n",*DY);
				break;
			case OPT_DZ:
				*DZ = atof(optarg);
				got_DZ=1;
				optcount++;
				printf("spacing of parcels DZ = %f\n",*DZ);
				break;
			case OPT_DEBUG:
				debug=1;
				optcount++;
				break;
			case OPT_DIRECTION:
				*direction = atoi(optarg);
				optcount++;
                printf("integration direction = %i\n", *direction);
				break;
			case '?':
				fprintf(stderr,"Exiting: unknown command line option.\n");
				exit(0);
				break;
		}
	}

		if (got_histpath==0) { fprintf(stderr,"--histpath not specified; I need to know where your data resides!\n"); bail = 1; }
		if (got_base==0)   { fprintf(stderr,"--base not specified; I need to know what you want your saved data called!\n"); bail = 1; }
		if (got_time==0)   { fprintf(stderr,"--time not specified; I need to know when to start integration!\n"); bail = 1; }
		if (got_ntimes==0)   { fprintf(stderr,"--ntimes not specified; I need to know how long to integrate for!\n"); bail = 1; }

/* These are now optional */
		if (!got_X0)      fprintf(stderr,"--x0 not specified; where do you want your parcels?\n");
		if (!got_Y0)      fprintf(stderr,"--y0 not specified; where do you want your parcels?\n");
		if (!got_Z0)      fprintf(stderr,"--z0 not specified; where do you want your parcels?\n");
		if (!got_NX)      fprintf(stderr,"--nx not specified; how many parcels do you want?\n");
		if (!got_NY)      fprintf(stderr,"--ny not specified; how many parcels do you want?\n");
		if (!got_NZ)      fprintf(stderr,"--nz not specified; how many parcels do you want?\n");
		if (!got_DX)      fprintf(stderr,"--dx not specified; how dense do you want your parcels?\n");
		if (!got_DY)      fprintf(stderr,"--dy not specified; how dense do you want your parcels?\n");
		if (!got_DZ)      fprintf(stderr,"--dz not specified; how dense do you want your parcels?\n");

		if (bail)           { fprintf(stderr,"Insufficient arguments to %s, exiting.\n",argv[0]); exit(-1); }
}

/* Load the grid metadata and request a domain subset based on the 
 * current parcel positioning for the current time step. The idea is that 
 * for the first chunk of times read in (from 0 to N MPI ranks for time)
 * only the subset of the domain that matters for that period of time. 
 * When the next chunk of time is read in, check and see where the parcels
 * are currently and request a subset that is relevent to those parcels.   
 */
datagrid* loadMetadataAndGrid(string base_dir, parcel_pos *parcels, int rank) {
    // get the HDF metadata from LOFS - return the first filename
    cout << "Retrieving HDF Metadata" << endl;
    get_hdf_metadata(firstfilename,&nx,&ny,&nz,&nodex,&nodey);

    // Create a temporary full grid that we will then subset. We will
    // only do this in CPU memory because this will get deleted
    datagrid *temp_grid;
    // this is the grid we will return
    datagrid *requested_grid;
        

    // load the saved grid dimmensions into 
    // the temporary grid, then we will find
    // a smaller subset to load into memory.
    //  nz comes from readlofs
    cout << "Allocating temporary grid" << endl;
    temp_grid = allocate_grid_cpu( saved_X0, saved_X1, saved_Y0, saved_Y1, 0, nz-1);

    // request the full grid so that we can find the indices
    // of where our parcels are, and then request a smaller
    // subset from there.
    cout << "Calling LOFS on temporary grid" << endl;
    lofs_get_grid(temp_grid);

    // find the min/max index bounds of 
    // our parcels
    float point[3];
    int idx_4D[4];
    int min_i = temp_grid->NX+1;
    int min_j = temp_grid->NY+1;
    int min_k = temp_grid->NZ+1;
    int max_i = -1;
    int max_j = -1;
    int max_k = -1;
    int invalidCount = 0;
    cout << "Searching the parcel bounds" << endl;
    for (int pcl = 0; pcl < parcels->nParcels; ++pcl) {
        point[0] = parcels->xpos[PCL(0, pcl, parcels->nTimes)];
        point[1] = parcels->ypos[PCL(0, pcl, parcels->nTimes)];
        point[2] = parcels->zpos[PCL(0, pcl, parcels->nTimes)];
        // find the nearest grid point!
        nearest_grid_idx(point, temp_grid, idx_4D);
        if ( (idx_4D[0] == -1) || (idx_4D[1] == -1) || (idx_4D[2] == -1) ) {
            cout << "INVALID POINT X " << point[0] << " Y " << point[1] << " Z " << point[2] << endl;
            cout << "Parcel X " << parcels->xpos[PCL(0, pcl, parcels->nTimes)];
            cout << " Parcel Y " << parcels->ypos[PCL(0, pcl, parcels->nTimes)];
            cout << " Parcel Z " << parcels->zpos[PCL(0, pcl, parcels->nTimes)] << endl;
            invalidCount += 1;
        }

        // check to see if we've found the min/max
        // for the dimension
        if (idx_4D[0] < min_i) min_i = idx_4D[0]; 
        if (idx_4D[0] > max_i) max_i = idx_4D[0]; 
        if (idx_4D[1] < min_j) min_j = idx_4D[1]; 
        if (idx_4D[1] > max_j) max_j = idx_4D[1]; 
        if (idx_4D[2] < min_k) min_k = idx_4D[2]; 
        if (idx_4D[2] > max_k) max_k = idx_4D[2]; 
    }
    cout << "Finished searching parcel bounds" << endl;
    // clear the memory from the temp grid
    cout << "Deallocating temporary grid" << endl;
    deallocate_grid_cpu(temp_grid);

    // we want to add a buffer to our dimensions so that
    // the parcels don't accidentally move outside of our
    // requested data. If the buffer goes outside the 
    // saved dimensions, set it to the saved dimensions.
    // We also do this for our staggered grid calculations
    min_i = saved_X0 + min_i - 5;
    max_i = saved_X0 + max_i + 5;
    min_j = saved_Y0 + min_j - 5;
    max_j = saved_Y0 + max_j + 5;
    min_k = min_k - 5;
    max_k = max_k + 5;
    cout << "Attempted Parcel Bounds In Grid" << endl;
    cout << "X0: " << min_i << " X1: " << max_i << endl;
    cout << "Y0: " << min_j << " Y1: " << max_j << endl;
    cout << "Z0: " << min_k << " Z1: " << max_k << endl;

    // keep the data in our saved bounds
    if (min_i < saved_X0) min_i = saved_X0;
    if (max_i > saved_X1) max_i = saved_X1;
    if (min_j < saved_Y0) min_j = saved_Y0;
    if (max_j > saved_Y1) max_j = saved_Y1;
    if (min_k < 0) min_k = 0;
    if (max_k > nz-1) max_k = nz-1;


    cout << "Parcel Bounds In Grid" << endl;
    cout << "X0: " << min_i << " X1: " << max_i << endl;
    cout << "Y0: " << min_j << " Y1: " << max_j << endl;
    cout << "Z0: " << min_k << " Z1: " << max_k << endl;


    // request our grid subset now
    cout << "REQUESTING METADATA & GRID" << endl;
    // on rank zero, allocate our grid on both the
    // CPU and GPU so that the GPU knows something
    // about our data for future integration.
    if (rank == 0) {
        requested_grid = allocate_grid_managed( min_i, max_i, min_j, max_j, min_k, max_k);
    }
    // For the other MPI ranks, we only need to
    // allocate the grids on the CPU for copying
    // data to the MPI_Gather call
    else {
        requested_grid = allocate_grid_cpu( min_i, max_i, min_j, max_j, min_k, max_k);
    }

    requested_grid->isValid = 1;
    // if literally all of our parcels aren't
    // in the domain then something has gone
    // horribly wrong
    if (invalidCount == parcels->nParcels) {
        requested_grid->isValid = 0;
        return requested_grid;
    }


    lofs_get_grid(requested_grid);
    cout << "END METADATA & GRID REQUEST" << endl;
    return requested_grid;
}

/* Read in the U, V, and W vector components plus the buoyancy and turbulence fields 
 * from the disk, provided previously allocated memory buffers
 * and the time requested in the dataset. 
 */
void loadDataFromDisk(datagrid *requested_grid, float *ustag, float *vstag, float *wstag, \
                        float *pbuffer, float *thbuffer, float *rhobuffer, float *khhbuffer, float*kmhbuffer, double t0) {
    // request 3D field!
    // u,v, and w are on their
    // respective staggered grids

    // we need the boolean variables to tell the code
    // what type of array indexing we're using, and what
    // grid bounds should be requested to accomodate the
    // data. 
    bool istag = true;
    lofs_read_3dvar(requested_grid, ustag, (char *)"u", istag, t0);
    lofs_read_3dvar(requested_grid, vstag, (char *)"v", istag, t0);
    lofs_read_3dvar(requested_grid, wstag, (char *)"w", istag, t0);
    lofs_read_3dvar(requested_grid, khhbuffer, (char *)"khh", istag, t0);
    lofs_read_3dvar(requested_grid, kmhbuffer, (char *)"kmh", istag, t0);

    // request additional fields for calculations
    istag = false;
    lofs_read_3dvar(requested_grid, pbuffer, (char *)"prespert", istag, t0);
    lofs_read_3dvar(requested_grid, thbuffer, (char *)"thrhopert", istag, t0);
    lofs_read_3dvar(requested_grid, rhobuffer, (char *)"rhopert", istag, t0);

}

/* This handles the vertical dimension offset so that we can
 * include a lower ghost zone later on down the road*/
void buffer_offset_stag(datagrid *grid, float *ubufin, float *vbufin, float *wbufin, float *khhbufin, float *kmhbufin, \
                   float *ubufout, float *vbufout, float *wbufout, float *khhbufout, float *kmhbufout) {
    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    for (int i = 0; i < NX+2; i++) {
        for (int j = 0; j < NY+2; j++) {
            for (int k = 0; k < NZ; ++k) {
                if (k == 0) {
                    // fill the lower ghost zone with zeroes. May consider
                    // applying the boundary condition here, but makes more
                    // sense to apply it in GPU land for clarity. 
                    ubufout[P3(i, j, 0, NX+2, NY+2)] = 0.0;
                    vbufout[P3(i, j, 0, NX+2, NY+2)] = 0.0;
                    wbufout[P3(i, j, 0, NX+2, NY+2)] = 0.0;
                    khhbufout[P3(i, j, 0, NX+2, NY+2)] = 0.0;
                    kmhbufout[P3(i, j, 0, NX+2, NY+2)] = 0.0;
                }
                ubufout[P3(i, j, k+1, NX+2, NY+2)] = ubufin[P3(i, j, k, NX+2, NY+2)];
                vbufout[P3(i, j, k+1, NX+2, NY+2)] = vbufin[P3(i, j, k, NX+2, NY+2)];
                wbufout[P3(i, j, k+1, NX+2, NY+2)] = wbufin[P3(i, j, k, NX+2, NY+2)];
                khhbufout[P3(i, j, k+1, NX+2, NY+2)] = khhbufin[P3(i, j, k, NX+2, NY+2)];
                kmhbufout[P3(i, j, k+1, NX+2, NY+2)] = kmhbufin[P3(i, j, k, NX+2, NY+2)];
            }
        }
    }
}

void buffer_offset_scal(datagrid *grid, float *pbufin, float *thbufin, float *rhobufin, \
                        float *pbufout, float *thbufout, float *rhobufout) {
    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    for (int i = 0; i < NX; i++) {
        for (int j = 0; j < NY; j++) {
            for (int k = 0; k < NZ; ++k) {
                if (k == 0) {
                    pbufout[P3(i, j, 0, NX, NY)] = pbufin[P3(i, j, 0, NX, NY)];
                    thbufout[P3(i, j, 0, NX, NY)] = thbufin[P3(i, j, 0, NX, NY)];
                    rhobufout[P3(i, j, 0, NX, NY)] = rhobufin[P3(i, j, 0, NX, NY)];
                }
                pbufout[P3(i, j, k+1, NX, NY)] = pbufin[P3(i, j, k, NX, NY)];
                thbufout[P3(i, j, k+1, NX, NY)] = thbufin[P3(i, j, k, NX, NY)];
                rhobufout[P3(i, j, k+1, NX, NY)] = rhobufin[P3(i, j, k, NX, NY)];
            }
        }
    }
}

/* Seed some parcels into the domain
 * in physical gridpoint space, and then
 * fill the remainder of the parcel traces
 * with missing values. 
 */
void seed_parcels(parcel_pos *parcels, float X0, float Y0, float Z0, int NX, int NY, int NZ, \
                    float DX, float DY, float DZ, int nTotTimes) {
    int nParcels = NX*NY*NZ;

    int pid = 0;
    for (int k = 0; k < NZ; ++k) {
        for (int j = 0; j < NY; ++j) {
            for (int i = 0; i < NX; ++i) {
                parcels->xpos[PCL(0, pid, parcels->nTimes)] = X0 + i*DX;
                parcels->ypos[PCL(0, pid, parcels->nTimes)] = Y0 + j*DY;
                parcels->zpos[PCL(0, pid, parcels->nTimes)] = Z0 + k*DZ;
                pid += 1;
            }
        }
    }

    // fill the remaining portions of the array
    // with the missing value flag for the future
    // times that we haven't integrated to yet.
    for (int p = 0; p < nParcels; ++p) {
        for (int t = 1; t < parcels->nTimes; ++t) {
            parcels->xpos[PCL(t, p, parcels->nTimes)] = NC_FILL_FLOAT;
            parcels->ypos[PCL(t, p, parcels->nTimes)] = NC_FILL_FLOAT;
            parcels->zpos[PCL(t, p, parcels->nTimes)] = NC_FILL_FLOAT;
        }
    }
    cout << "END PARCEL SEED" << endl;
}


/* This is the main program that does the parcel trajectory analysis.
 * It first sets up the parcel vectors and seeds the starting locations.
 * It then loads a chunk of times into memory by calling the LOFS api
 * wrappers, with the number of times read in being determined by the
 * number of MPI ranks launched. It then passes the vectors and the 4D u/v/w 
 * data chunks to the GPU, and then proceeds with another time chunk.
 */
int main(int argc, char **argv ) {
    // variables for parcel seed locations,
    // amount, and spacing
    float pX0, pDX, pY0, pDY, pZ0, pDZ;
    int pNX, pNY, pNZ;
    // what is our integration start point in the simulation?
    double time;
    int nTimeSteps;
    // parcel integration direction; default is forward
    int direct = 1;
    // variables for specifying our
    // data path and our output data 
    // path
    char *base = new char[256];
    char *histpath = new char[256];
    
    // call the command line parser and store the user input in the
    // appropriate variables. Stole this and modified it from LOFS
    // because I'm too lazy to write my own and using a library I
    // have to link to sounds really cumbersome. 
    parse_cmdline(argc, argv, histpath, base, &time, &nTimeSteps, &direct, &pX0, &pY0, &pZ0, &pNX, &pNY, &pNZ, &pDX, &pDY, &pDZ );

    // convert the char arrays to strings
    // because this is C++ and we can use
    // objects in the 21st centuryc
    string base_dir = string(histpath);
    string outfilename = string(base) + ".nc";
    // get rid of useless dead weight
    // because we're good programmers
    delete[] base;
    delete[] histpath;

    int rank, size;
    long N_stag_ghost, N_stag_read, N_scal_read, N_scal_ghost, MX, MY, MZ;
    //int nTimeChunks = 120*2;

    // initialize a bunch of MPI stuff.
    // Rank tells you which process
    // you are and size tells y ou how
    // many processes there are total
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    MPI_Comm_set_errhandler(MPI_COMM_WORLD, MPI_ERRORS_ARE_FATAL);
    MPI_Barrier(MPI_COMM_WORLD);

    int nTimeChunks = (int) (nTimeSteps / size); // this is a temporary hack
    if (nTimeSteps % size > 0) nTimeChunks += 1;
    // to make the command line parser stuff work with the
    // existing code.
    // KELTON PLEASE REMEMBER TO CHANGE THIS SO THAT WE
    // DON'T HAVE 800000000 VARIABLES DOING THE SAME THING
    // LYING AROUND


    // the number of time steps we have is 
    // the number of MPI ranks there are
    // plus the very last integration end time
    int nTotTimes = size+1;
    
    // Query our dataset structure.
    // If this has been done before, it reads
    // the information from cache files in the 
    // runtime directory. If it hasn't been run,
    // this step can take fair amount of time.
    lofs_get_dataset_structure(base_dir);
    // our parcel struct containing 
    // the position arrays
    datagrid *requested_grid;
    parcel_pos *parcels;

    // This is the main loop that does the data reading and eventually
    // calls the CUDA code to integrate forward.
    for (int tChunk = 0; tChunk < nTimeChunks; ++tChunk) {
        // if this is the first chunk of time, seed the
        // parcel start locations
        if (tChunk == 0) {
            cout << "SEEDING PARCELS" << endl;
            if (rank == 0) {
                // allocate parcels on both CPU and GPU
                parcels = allocate_parcels_managed(pNX, pNY, pNZ, nTotTimes);
            }
            else {
                // for all other ranks, only
                // allocate on CPU
                parcels = allocate_parcels_cpu(pNX, pNY, pNZ, nTotTimes);
            }
            
            // seed the parcel starting positions based on the command line
            // arguments provided by the user. I don't think any sanity checking is done
            // here for out of bounds positions so we probably need to be careful
            // of this and consider fixing that
            seed_parcels(parcels, pX0, pY0, pZ0, pNX, pNY, pNZ, pDX, pDY, pDZ, nTotTimes);
            // we also initialize the output netcdf file here
            if (rank == 0) init_nc(outfilename, parcels);
        }

        // Read in the metadata and request a grid subset 
        // that is dynamically based on where our parcels
        // are in the simulation. This is done for all MPI
        // ranks so that they can request different time
        // steps, but only Rank 0 will allocate the grid
        // arrays on both the CPU and GPU.
        
        requested_grid = loadMetadataAndGrid(base_dir, parcels, rank); 
        if (requested_grid->isValid == 0) {
            cout << "Something went horribly wrong when requesting a domain subset. Abort." << endl;
            exit(-1);
        }


        // The number of grid points requested...
        // There's some awkwardness here I have to figure out a better way around,
        // but MPI Scatter/Gather behaves weird if I use the generic large buffer,
        // so I use N_scalar for the MPI calls to non staggered/scalar fields. 
        N_stag_read = (requested_grid->NX+2)*(requested_grid->NY+2)*(requested_grid->NZ+1);
        N_stag_ghost = (requested_grid->NX+2)*(requested_grid->NY+2)*(requested_grid->NZ+2);

        N_scal_read = (requested_grid->NX)*(requested_grid->NY)*(requested_grid->NZ);
        N_scal_ghost = (requested_grid->NX)*(requested_grid->NY)*(requested_grid->NZ+1);


        // allocate space for U, V, and W arrays
        // for all ranks, because this is what
        // LOFS will return it's data subset to
        float *ubuf_tem, *vbuf_tem, *wbuf_tem, *pbuf_tem, *thbuf_tem, *rhobuf_tem, *khhbuf_tem, *kmhbuf_tem;
        float *ubuf, *vbuf, *wbuf, *pbuf, *thbuf, *rhobuf, *khhbuf, *kmhbuf;
        // These temporary buffers are our un-offset arrays
        ubuf_tem = new float[N_stag_read];
        vbuf_tem = new float[N_stag_read];
        wbuf_tem = new float[N_stag_read];
        // khh and kmh are on the staggered W mesh
        khhbuf_tem = new float[N_stag_read];
        kmhbuf_tem = new float[N_stag_read];
        pbuf_tem = new float[N_scal_read];
        thbuf_tem = new float[N_scal_read];
        rhobuf_tem = new float[N_scal_read];

        // These non temporary arrays are offset in the vertical by 1
        // to account for potential ghost zone
        ubuf = new float[N_stag_ghost];
        vbuf = new float[N_stag_ghost];
        wbuf = new float[N_stag_ghost];
        // khh and kmh are on the staggered W mesh
        khhbuf = new float[N_stag_ghost];
        kmhbuf = new float[N_stag_ghost];
        // As far as I'm aware, these do not need to be offset
        pbuf = new float[N_scal_ghost];
        thbuf = new float[N_scal_ghost];
        rhobuf = new float[N_scal_ghost];


        // construct a 4D contiguous array to store stuff in.
        // bufsize is the size of the 3D component and size is
        // the number of MPI ranks (which is also the number of times)
        // read in
        //
        // declare the struct on all ranks, but only
        // allocate space for it on Rank 0
        integration_data *data;
        if (rank == 0) {
            data = allocate_integration_managed(N_stag_ghost*size);
        }
        else {
            data = new integration_data();
        }


        // we need to find the index of the nearest time to the user requested
        // time. If the index isn't found, abort.
        int nearest_tidx = find_nearest_index(alltimes, time, ntottimes);
        if (nearest_tidx < 0) {
            cout << "Invalid time index: " << nearest_tidx << " for time " << time << ". Abort." << endl;
            return 0;
        }
        printf("TIMESTEP %d/%d %d %f\n", rank, size, rank + tChunk*size, alltimes[nearest_tidx + direct*( rank + tChunk*size)]);
        // load u, v, and w into memory
        loadDataFromDisk(requested_grid, ubuf_tem, vbuf_tem, wbuf_tem, \
                         pbuf_tem, thbuf_tem, rhobuf_tem, khhbuf_tem, \
                         kmhbuf_tem, alltimes[nearest_tidx + direct*(rank + tChunk*size)]);

        buffer_offset_stag(requested_grid, ubuf_tem, vbuf_tem, wbuf_tem, khhbuf_tem, \
                           kmhbuf_tem, ubuf, vbuf, wbuf, khhbuf, kmhbuf);
        buffer_offset_scal(requested_grid, pbuf_tem, thbuf_tem, rhobuf_tem, \
                           pbuf, thbuf, rhobuf);
        
        // for MPI runs that load multiple time steps into memory,
        // communicate the data you've read into our 4D array

        int senderr_u = MPI_Gather(ubuf, N_stag_ghost, MPI_FLOAT, data->u_4d_chunk, N_stag_ghost, MPI_FLOAT, 0, MPI_COMM_WORLD);
        int senderr_v = MPI_Gather(vbuf, N_stag_ghost, MPI_FLOAT, data->v_4d_chunk, N_stag_ghost, MPI_FLOAT, 0, MPI_COMM_WORLD);
        int senderr_w = MPI_Gather(wbuf, N_stag_ghost, MPI_FLOAT, data->w_4d_chunk, N_stag_ghost, MPI_FLOAT, 0, MPI_COMM_WORLD);
        int senderr_khh = MPI_Gather(khhbuf, N_stag_ghost, MPI_FLOAT, data->khh_4d_chunk, N_stag_ghost, MPI_FLOAT, 0, MPI_COMM_WORLD);
        int senderr_kmh = MPI_Gather(kmhbuf, N_stag_ghost, MPI_FLOAT, data->kmh_4d_chunk, N_stag_ghost, MPI_FLOAT, 0, MPI_COMM_WORLD);

        // Use N_scalar here so that there aren't random zeroes throughout the middle of the array
        int senderr_p = MPI_Gather(pbuf, N_scal_ghost, MPI_FLOAT, data->pres_4d_chunk, N_scal_ghost, MPI_FLOAT, 0, MPI_COMM_WORLD);
        int senderr_th = MPI_Gather(thbuf, N_scal_ghost, MPI_FLOAT, data->th_4d_chunk, N_scal_ghost, MPI_FLOAT, 0, MPI_COMM_WORLD);
        int senderr_rho = MPI_Gather(rhobuf, N_scal_ghost, MPI_FLOAT, data->rho_4d_chunk, N_scal_ghost, MPI_FLOAT, 0, MPI_COMM_WORLD);


        if (rank == 0) {
            // send to the GPU!!
            cout << "MPI Gather Error U: " << senderr_u << endl;
            cout << "MPI Gather Error V: " << senderr_v << endl;
            cout << "MPI Gather Error W: " << senderr_w << endl;
            cout << "MPI Gather Error P: " << senderr_p << endl;
            cout << "MPI Gather Error TH: " << senderr_th << endl;
            cout << "MPI Gather Error RHO: " << senderr_rho << endl;
            cout << "MPI Gather Error KHH: " << senderr_khh << endl;
            cout << "MPI Gather Error KMH: " << senderr_khh << endl;
            int nParcels = parcels->nParcels;
            cout << "Beginning parcel integration! Heading over to the GPU to do GPU things..." << endl;
            cudaIntegrateParcels(requested_grid, data, parcels, size, nTotTimes, direct); 
            cout << "Finished integrating parcels!" << endl;
            // write out our information to disk
            cout << "Beginning to write to disk..." << endl;
            write_parcels(outfilename, parcels, tChunk);

            // Now that we've integrated forward and written to disk, before we can go again
            // we have to set the current end position of the parcel to the beginning for 
            // the next leg of integration. Do that, and then reset all the other values
            // to missing.
            cout << "Setting final parcel position to beginning of array for next integration cycle..." << endl;
            for (int pcl = 0; pcl < parcels->nParcels; ++pcl) {
                parcels->xpos[P2(0, pcl, parcels->nTimes)] = parcels->xpos[P2(size, pcl, parcels->nTimes)];
                parcels->ypos[P2(0, pcl, parcels->nTimes)] = parcels->ypos[P2(size, pcl, parcels->nTimes)];
                parcels->zpos[P2(0, pcl, parcels->nTimes)] = parcels->zpos[P2(size, pcl, parcels->nTimes)];
                // empty out our parcel data arrays too
                parcels->pclu[P2(0, pcl, parcels->nTimes)] = NC_FILL_FLOAT;
                parcels->pclv[P2(0, pcl, parcels->nTimes)] = NC_FILL_FLOAT;
                parcels->pclw[P2(0, pcl, parcels->nTimes)] = NC_FILL_FLOAT;
            }
            cout << "Parcel position arrays reset." << endl;

            // memory management for root rank
            deallocate_grid_managed(requested_grid);

            delete[] ubuf;
            delete[] vbuf;
            delete[] wbuf;
            delete[] ubuf_tem;
            delete[] vbuf_tem;
            delete[] wbuf_tem;
            delete[] pbuf_tem;
            delete[] thbuf_tem;
            delete[] rhobuf_tem;
            delete[] khhbuf_tem;
            delete[] kmhbuf_tem;
            delete[] pbuf;
            delete[] thbuf;
            delete[] rhobuf;
            delete[] khhbuf;
            delete[] kmhbuf;

            deallocate_integration_managed(data);
        }

        // house keeping for the non-master
        // MPI ranks
        else {
            // memory management
            deallocate_grid_cpu(requested_grid);

            delete[] ubuf;
            delete[] vbuf;
            delete[] wbuf;
            delete[] ubuf_tem;
            delete[] vbuf_tem;
            delete[] wbuf_tem;
            delete[] pbuf_tem;
            delete[] thbuf_tem;
            delete[] rhobuf_tem;
            delete[] khhbuf_tem;
            delete[] kmhbuf_tem;
            delete[] pbuf;
            delete[] thbuf;
            delete[] rhobuf;
            delete[] khhbuf;
            delete[] kmhbuf;
        }
        // receive the updated parcel arrays
        // so that we can do proper subseting. This happens
        // after integration is complete from CUDA.
        MPI_Status status;
        MPI_Bcast(parcels->xpos, parcels->nParcels*nTotTimes, MPI_FLOAT, 0, MPI_COMM_WORLD);
        MPI_Bcast(parcels->ypos, parcels->nParcels*nTotTimes, MPI_FLOAT, 0, MPI_COMM_WORLD);
        MPI_Bcast(parcels->zpos, parcels->nParcels*nTotTimes, MPI_FLOAT, 0, MPI_COMM_WORLD);

    }

    if (rank == 0) {
        cout << "Finished!" << endl << endl;
    }
    MPI_Finalize();
}