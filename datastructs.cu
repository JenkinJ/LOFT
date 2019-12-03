#include <vector>
#include "macros.cpp"
#include "datastructs.h"
#include <iostream>
#ifndef DATASTRUCTS
#define DATASTRUCTS
using namespace std;

/* Allocate memory on the CPU and GPU for a grid. There are times,
    like for various MPI ranks, that you don't want to do this on both.
    See the similar function for doing this on just the CPU */
datagrid* allocate_grid_managed( int X0, int X1, int Y0, int Y1, int Z0, int Z1 ) {
    datagrid *grid;
    long NX, NY, NZ;

    cudaMallocManaged(&grid, sizeof(datagrid));
    grid->X0 = X0; grid->X1 = X1;
    grid->Y0 = Y0; grid->Y1 = Y1;
    grid->Z0 = Z0; grid->Z1 = Z1;

	NX = grid->X1 - grid->X0 + 1;
	NY = grid->Y1 - grid->Y0 + 1;
	NZ = grid->Z1 - grid->Z0 + 1;

    // set the grid attributes
    grid->NX = NX;
    grid->NY = NY;
    grid->NZ = NZ;

    // allocage grid arrays
    cudaMallocManaged(&(grid->xf), (NX+1)*sizeof(float));
    cudaMallocManaged(&(grid->xh), NX*sizeof(float));

    cudaMallocManaged(&(grid->yf), (NY+1)*sizeof(float));
    cudaMallocManaged(&(grid->yh), NY*sizeof(float));

    // +2 is +1 for stagger, +1 for potential bottom ghost zone
    cudaMallocManaged(&(grid->zf), (NZ+2)*sizeof(float));
    cudaMallocManaged(&(grid->zh), (NZ+2)*sizeof(float));

    cudaMallocManaged(&(grid->uf), (NX+2)*sizeof(float));
    cudaMallocManaged(&(grid->uh), (NX+2)*sizeof(float));

    cudaMallocManaged(&(grid->vf), (NY+2)*sizeof(float));
    cudaMallocManaged(&(grid->vh), (NY+2)*sizeof(float));

    cudaMallocManaged(&(grid->mf), (NZ+2)*sizeof(float));
    cudaMallocManaged(&(grid->mh), (NZ+2)*sizeof(float));

    // allocate base state arrays
    cudaMallocManaged(&(grid->u0), NZ*sizeof(float));
    cudaMallocManaged(&(grid->v0), NZ*sizeof(float));
    cudaMallocManaged(&(grid->qv0), NZ*sizeof(float));
    cudaMallocManaged(&(grid->th0), NZ*sizeof(float));
    cudaMallocManaged(&(grid->rho0), NZ*sizeof(float));
    cudaMallocManaged(&(grid->p0), NZ*sizeof(float));
    cudaDeviceSynchronize();

    return grid;
}

/* Allocate arrays only on the CPU for the grid. This is important
   for using with MPI, as only 1 rank should be allocating memory
   on the GPU */
datagrid* allocate_grid_cpu( int X0, int X1, int Y0, int Y1, int Z0, int Z1 ) {
    datagrid *grid = new datagrid();
    long NX, NY, NZ;

    grid->X0 = X0; grid->X1 = X1;
    grid->Y0 = Y0; grid->Y1 = Y1;
    grid->Z0 = Z0; grid->Z1 = Z1;

	NX = grid->X1 - grid->X0 + 1;
	NY = grid->Y1 - grid->Y0 + 1;
	NZ = grid->Z1 - grid->Z0 + 1;

    // set the grid attributes
    grid->NX = NX;
    grid->NY = NY;
    grid->NZ = NZ;

    // allocage grid arrays
    grid->xf = new float[NX+1];
    grid->xh = new float[NX];

    grid->yf = new float[NY+1];
    grid->yh = new float[NY];

    grid->zf = new float[NZ+2];
    grid->zh = new float[NZ+2];

    grid->uf = new float[NX+2];
    grid->uh = new float[NX+2];

    grid->vf = new float[NY+2];
    grid->vh = new float[NY+2];

    grid->mf = new float[NZ+2];
    grid->mh = new float[NZ+2];

    // allocate base state arrays
    grid->u0 = new float[NZ];
    grid->v0 = new float[NZ];
    grid->qv0 = new float[NZ];
    grid->th0 = new float[NZ];
    grid->rho0 = new float[NZ];
    grid->p0 = new float[NZ];

    return grid;
}

/* Deallocate all of the arrays in the 
   struct for both the GPU and CPU */
void deallocate_grid_managed(datagrid *grid) {
    cudaFree(grid->xf);
    cudaFree(grid->xh);
    cudaFree(grid->yf);
    cudaFree(grid->yh);
    cudaFree(grid->zf);
    cudaFree(grid->zh);
    cudaFree(grid->uf);
    cudaFree(grid->uh);
    cudaFree(grid->vf);
    cudaFree(grid->vh);
    cudaFree(grid->mf);
    cudaFree(grid->mh);
    cudaFree(grid->u0);
    cudaFree(grid->v0);
    cudaFree(grid->rho0);
    cudaFree(grid->th0);
    cudaFree(grid->qv0);
    cudaFree(grid->p0);
    cudaDeviceSynchronize();
}

/* Deallocate all of the arrays in the
   struct only for the CPU */
void deallocate_grid_cpu(datagrid *grid) {
    delete[] grid->xf;
    delete[] grid->xh;
    delete[] grid->yf;
    delete[] grid->yh;
    delete[] grid->zf;
    delete[] grid->zh;
    delete[] grid->uf;
    delete[] grid->uh;
    delete[] grid->vf;
    delete[] grid->vh;
    delete[] grid->mf;
    delete[] grid->mh;
    delete[] grid->u0;
    delete[] grid->v0;
    delete[] grid->rho0;
    delete[] grid->th0;
    delete[] grid->qv0;
    delete[] grid->p0;
}

/* Allocate arrays for parcel info on both the CPU and GPU.
   This function should only be called by MPI Rank 0, so
   be sure to use the CPU function for Rank >= 1. */
parcel_pos* allocate_parcels_managed(int NX, int NY, int NZ, int nTotTimes) {
    int nParcels = NX*NY*NZ;
    parcel_pos *parcels;
    // create the struct on both the GPU and the CPU.
    cudaMallocManaged(&parcels, sizeof(parcel_pos));

    // allocate memory for the parcels
    // we are integrating for the entirety 
    // of the simulation.
    cudaMallocManaged(&(parcels->xpos), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->ypos), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->zpos), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclu), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclv), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclw), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pcluturb), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclvturb), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclwturb), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pcludiff), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclvdiff), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclwdiff), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclxvort), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclyvort), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclzvort), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclxvorttilt), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclyvorttilt), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclzvorttilt), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclxvortstretch), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclyvortstretch), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclzvortstretch), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclxvortturb), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclyvortturb), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclzvortturb), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclxvortdiff), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclyvortdiff), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclzvortdiff), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclxvortsolenoid), nParcels*nTotTimes*sizeof(float));
    cudaMallocManaged(&(parcels->pclyvortsolenoid), nParcels*nTotTimes*sizeof(float));
    cudaMallocManaged(&(parcels->pclzvortsolenoid), nParcels*nTotTimes*sizeof(float));

    cudaMallocManaged(&(parcels->pclppert), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclqvpert), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclrhopert), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclthetapert), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclthrhopert), nParcels*nTotTimes*sizeof(float)); 

    cudaMallocManaged(&(parcels->pclpbar), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclqvbar), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclrhobar), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclthetabar), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclthrhobar), nParcels*nTotTimes*sizeof(float)); 

    cudaMallocManaged(&(parcels->pclqc), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclqi), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclqs), nParcels*nTotTimes*sizeof(float)); 
    cudaMallocManaged(&(parcels->pclqg), nParcels*nTotTimes*sizeof(float)); 

    // set the static variables
    parcels->nParcels = nParcels;
    parcels->nTimes = nTotTimes;
    cudaDeviceSynchronize();

    return parcels;
}

/* Allocate arrays only on the CPU for the grid. This is important
   for using with MPI, as only 1 rank should be allocating memory
   on the GPU */
parcel_pos* allocate_parcels_cpu(int NX, int NY, int NZ, int nTotTimes) {
    int nParcels = NX*NY*NZ;
    parcel_pos *parcels = new parcel_pos();

    // allocate memory for the parcels
    // we are integrating for the entirety 
    // of the simulation.
    parcels->xpos = new float[nParcels*nTotTimes]; 
    parcels->ypos = new float[nParcels*nTotTimes]; 
    parcels->zpos = new float[nParcels*nTotTimes]; 
    parcels->pclu = new float[nParcels*nTotTimes]; 
    parcels->pclv = new float[nParcels*nTotTimes]; 
    parcels->pclw = new float[nParcels*nTotTimes]; 
    parcels->pcluturb = new float[nParcels*nTotTimes]; 
    parcels->pclvturb = new float[nParcels*nTotTimes]; 
    parcels->pclwturb = new float[nParcels*nTotTimes]; 
    parcels->pcludiff = new float[nParcels*nTotTimes]; 
    parcels->pclvdiff = new float[nParcels*nTotTimes]; 
    parcels->pclwdiff = new float[nParcels*nTotTimes]; 
    parcels->pclxvort = new float[nParcels*nTotTimes]; 
    parcels->pclyvort = new float[nParcels*nTotTimes]; 
    parcels->pclzvort = new float[nParcels*nTotTimes]; 
    parcels->pclxvorttilt = new float[nParcels*nTotTimes]; 
    parcels->pclyvorttilt = new float[nParcels*nTotTimes]; 
    parcels->pclzvorttilt = new float[nParcels*nTotTimes]; 
    parcels->pclxvortstretch = new float[nParcels*nTotTimes]; 
    parcels->pclyvortstretch = new float[nParcels*nTotTimes]; 
    parcels->pclzvortstretch = new float[nParcels*nTotTimes]; 
    parcels->pclxvortturb = new float[nParcels*nTotTimes]; 
    parcels->pclyvortturb = new float[nParcels*nTotTimes]; 
    parcels->pclzvortturb = new float[nParcels*nTotTimes]; 
    parcels->pclxvortdiff = new float[nParcels*nTotTimes]; 
    parcels->pclyvortdiff = new float[nParcels*nTotTimes]; 
    parcels->pclzvortdiff = new float[nParcels*nTotTimes]; 
    parcels->pclxvortsolenoid = new float[nParcels*nTotTimes];
    parcels->pclyvortsolenoid = new float[nParcels*nTotTimes];
    parcels->pclzvortsolenoid = new float[nParcels*nTotTimes];

    parcels->pclppert = new float[nParcels*nTotTimes];
    parcels->pclqvpert = new float[nParcels*nTotTimes];
    parcels->pclrhopert = new float[nParcels*nTotTimes];
    parcels->pclthetapert = new float[nParcels*nTotTimes];
    parcels->pclthrhopert = new float[nParcels*nTotTimes];

    parcels->pclpbar = new float[nParcels*nTotTimes];
    parcels->pclqvbar = new float[nParcels*nTotTimes];
    parcels->pclrhobar = new float[nParcels*nTotTimes];
    parcels->pclthetabar = new float[nParcels*nTotTimes];
    parcels->pclthrhobar = new float[nParcels*nTotTimes];

    parcels->pclqc = new float[nParcels*nTotTimes];
    parcels->pclqi = new float[nParcels*nTotTimes];
    parcels->pclqs = new float[nParcels*nTotTimes];
    parcels->pclqg = new float[nParcels*nTotTimes];
    // set the static variables
    parcels->nParcels = nParcels;
    parcels->nTimes = nTotTimes;

    return parcels;
}

/* Deallocate parcel arrays on both the CPU and the
   GPU */
void deallocate_parcels_managed(parcel_pos *parcels) {
    cudaFree(parcels->xpos);
    cudaFree(parcels->ypos);
    cudaFree(parcels->zpos);
    cudaFree(parcels->pclu);
    cudaFree(parcels->pclv);
    cudaFree(parcels->pclw);
    cudaFree(parcels->pcluturb);
    cudaFree(parcels->pclvturb);
    cudaFree(parcels->pclwturb);
    cudaFree(parcels->pcludiff);
    cudaFree(parcels->pclvdiff);
    cudaFree(parcels->pclwdiff);
    cudaFree(parcels->pclxvort);
    cudaFree(parcels->pclyvort);
    cudaFree(parcels->pclzvort);
    cudaFree(parcels->pclxvorttilt);
    cudaFree(parcels->pclyvorttilt);
    cudaFree(parcels->pclzvorttilt);
    cudaFree(parcels->pclxvortstretch);
    cudaFree(parcels->pclyvortstretch);
    cudaFree(parcels->pclzvortstretch);
    cudaFree(parcels->pclxvortturb);
    cudaFree(parcels->pclyvortturb);
    cudaFree(parcels->pclzvortturb);
    cudaFree(parcels->pclxvortdiff);
    cudaFree(parcels->pclyvortdiff);
    cudaFree(parcels->pclzvortdiff);
    cudaFree(parcels->pclxvortsolenoid);
    cudaFree(parcels->pclyvortsolenoid);
    cudaFree(parcels->pclzvortsolenoid);


    cudaFree(parcels->pclppert);
    cudaFree(parcels->pclqvpert);
    cudaFree(parcels->pclrhopert);
    cudaFree(parcels->pclthetapert);
    cudaFree(parcels->pclthrhopert);

    cudaFree(parcels->pclpbar);
    cudaFree(parcels->pclqvbar);
    cudaFree(parcels->pclrhobar);
    cudaFree(parcels->pclthetabar);
    cudaFree(parcels->pclthrhobar);

    cudaFree(parcels->pclqc);
    cudaFree(parcels->pclqi);
    cudaFree(parcels->pclqs);
    cudaFree(parcels->pclqg);
    cudaFree(parcels);
    cudaDeviceSynchronize();
}

/* Deallocate parcel arrays only on the CPU */
void deallocate_parcels_cpu(parcel_pos *parcels) {
    delete[] parcels->xpos;
    delete[] parcels->ypos;
    delete[] parcels->zpos;
    delete[] parcels->pclu;
    delete[] parcels->pclv;
    delete[] parcels->pclw;
    delete[] parcels->pcluturb;
    delete[] parcels->pclvturb;
    delete[] parcels->pclwturb;
    delete[] parcels->pcludiff;
    delete[] parcels->pclvdiff;
    delete[] parcels->pclwdiff;
    delete[] parcels->pclxvort;
    delete[] parcels->pclyvort;
    delete[] parcels->pclzvort;
    delete[] parcels->pclxvorttilt;
    delete[] parcels->pclyvorttilt;
    delete[] parcels->pclzvorttilt;
    delete[] parcels->pclxvortstretch;
    delete[] parcels->pclyvortstretch;
    delete[] parcels->pclzvortstretch;
    delete[] parcels->pclxvortturb;
    delete[] parcels->pclyvortturb;
    delete[] parcels->pclzvortturb;
    delete[] parcels->pclxvortdiff;
    delete[] parcels->pclyvortdiff;
    delete[] parcels->pclzvortdiff;
    delete[] parcels->pclxvortsolenoid;
    delete[] parcels->pclyvortsolenoid;
    delete[] parcels->pclzvortsolenoid;

    delete[] parcels->pclppert;
    delete[] parcels->pclqvpert;
    delete[] parcels->pclrhopert;
    delete[] parcels->pclthetapert;
    delete[] parcels->pclthrhopert;

    delete[] parcels->pclpbar;
    delete[] parcels->pclqvbar;
    delete[] parcels->pclrhobar;
    delete[] parcels->pclthetabar;
    delete[] parcels->pclthrhobar;

    delete[] parcels->pclqc;
    delete[] parcels->pclqi;
    delete[] parcels->pclqs;
    delete[] parcels->pclqg;
    delete[] parcels;
}

/* Allocate the struct of 4D arrays that store
   fields for integration and calculation. This
   only ever gets called by Rank 0, so there 
   should be no need for a CPU counterpart. */
integration_data* allocate_integration_managed(long bufsize) {
    integration_data *data;
    // create the struct on both the GPU and the CPU.
    cudaMallocManaged(&data, sizeof(integration_data));

    // allocate the arrays in the struct
    cudaMallocManaged(&(data->u_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->v_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->w_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->pi_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->pres_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->th_4d_chunk),  bufsize*sizeof(float));
    cudaMallocManaged(&(data->t_4d_chunk),  bufsize*sizeof(float));
    cudaMallocManaged(&(data->rho_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->rhof_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->kmh_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->qc_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->qi_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->qs_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->qg_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->qv_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->turbu_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->turbv_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->turbw_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->diffu_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->diffv_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->diffw_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->tem1_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->tem2_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->tem3_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->tem4_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->tem5_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->tem6_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->xvort_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->yvort_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->zvort_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->xvtilt_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->yvtilt_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->zvtilt_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->xvstretch_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->yvstretch_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->zvstretch_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->turbxvort_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->turbyvort_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->turbzvort_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->diffxvort_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->diffyvort_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->diffzvort_4d_chunk), bufsize*sizeof(float));
    cudaMallocManaged(&(data->xvort_solenoid_4d_chunk), bufsize*sizeof(float)); 
    cudaMallocManaged(&(data->yvort_solenoid_4d_chunk), bufsize*sizeof(float)); 
    cudaMallocManaged(&(data->zvort_solenoid_4d_chunk), bufsize*sizeof(float)); 

    for (int i = 0; i < bufsize; ++i) {
        data->u_4d_chunk[i] = 0;
        data->v_4d_chunk[i] = 0;
        data->w_4d_chunk[i] = 0;
        data->pi_4d_chunk[i] = 0;
        data->pres_4d_chunk[i] = 0;
        data->th_4d_chunk[i] = 0;
        data->rho_4d_chunk[i] = 0;
        data->kmh_4d_chunk[i] = 0;
        data->u_4d_chunk[i] = 0;
    }
    cudaDeviceSynchronize();

    return data;

}

/* Deallocate the struct of 4D arrays that store
   fields for integration and calculation. This 
   only ever gets called by Rank 0, so there
   should be no need for a CPU counterpart. */
void deallocate_integration_managed(integration_data *data) {
    cudaFree(data->u_4d_chunk);
    cudaFree(data->v_4d_chunk);
    cudaFree(data->w_4d_chunk);
    cudaFree(data->pi_4d_chunk);
    cudaFree(data->pres_4d_chunk);
    cudaFree(data->t_4d_chunk);
    cudaFree(data->th_4d_chunk);
    cudaFree(data->rho_4d_chunk);
    cudaFree(data->rhof_4d_chunk);
    cudaFree(data->kmh_4d_chunk);
    cudaFree(data->qc_4d_chunk);
    cudaFree(data->qi_4d_chunk);
    cudaFree(data->qs_4d_chunk);
    cudaFree(data->qg_4d_chunk);
    cudaFree(data->qv_4d_chunk);
    cudaFree(data->turbu_4d_chunk);
    cudaFree(data->turbv_4d_chunk);
    cudaFree(data->turbw_4d_chunk);
    cudaFree(data->diffu_4d_chunk);
    cudaFree(data->diffv_4d_chunk);
    cudaFree(data->diffw_4d_chunk);
    cudaFree(data->tem1_4d_chunk);
    cudaFree(data->tem2_4d_chunk);
    cudaFree(data->tem3_4d_chunk);
    cudaFree(data->tem4_4d_chunk);
    cudaFree(data->tem5_4d_chunk);
    cudaFree(data->tem6_4d_chunk);
    cudaFree(data->xvort_4d_chunk);
    cudaFree(data->yvort_4d_chunk);
    cudaFree(data->zvort_4d_chunk);
    cudaFree(data->xvtilt_4d_chunk);
    cudaFree(data->yvtilt_4d_chunk);
    cudaFree(data->zvtilt_4d_chunk);
    cudaFree(data->xvstretch_4d_chunk);
    cudaFree(data->yvstretch_4d_chunk);
    cudaFree(data->zvstretch_4d_chunk);
    cudaFree(data->turbxvort_4d_chunk);
    cudaFree(data->turbyvort_4d_chunk);
    cudaFree(data->turbzvort_4d_chunk);
    cudaFree(data->diffxvort_4d_chunk);
    cudaFree(data->diffyvort_4d_chunk);
    cudaFree(data->diffzvort_4d_chunk);
    cudaFree(data->xvort_solenoid_4d_chunk); 
    cudaFree(data->yvort_solenoid_4d_chunk); 
    cudaFree(data->zvort_solenoid_4d_chunk); 
}
#endif

