#include <iostream>
#include <stdio.h>
#include "../include/datastructs.h"
#include "../include/macros.h"
#include "../calc/calcvort.cu"
#ifndef VORT_CU
#define VORT_CU

/* When doing the parcel trajectory integration, George Bryan does
   some fun stuff with the lower boundaries/ghost zones of the arrays, presumably
   to prevent the parcels from exiting out the bottom of the domain
   or experience artificial values. This sets the ghost zone values. */
__global__ void applyMomentumBC(float *ustag, float *vstag, float *wstag, int NX, int NY, int NZ, int tStart, int tEnd) {
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    int j = blockIdx.y*blockDim.y + threadIdx.y;
    int k = blockIdx.z*blockDim.z + threadIdx.z;

    // this is done for easy comparison to CM1 code
    int ni = NX; int nj = NY;

    // this is a lower boundary condition, so only when k is 0
    // also this is on the u staggered mesh
    if (( j < nj+1) && ( i < ni+1) && ( k == 0)) {
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            // use the u stagger macro to handle the
            // proper indexing
            UA4D(i, j, 0, tidx) = UA4D(i, j, 1, tidx);
        }
    }
    
    // do the same but now on the v staggered grid
    if (( j < nj+1) && ( i < ni+1) && ( k == 0)) {
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            // use the v stagger macro to handle the
            // proper indexing
            VA4D(i, j, 0, tidx) = VA4D(i, j, 1, tidx);
        }
    }

    // do the same but now on the w staggered grid
    if (( j < nj+1) && ( i < ni+1) && ( k == 0)) {
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            // use the w stagger macro to handle the
            // proper indexing
            WA4D(i, j, 0, tidx) = -1*WA4D(i, j, 2, tidx);
        }
    }
}

__global__ void calcpipert(datagrid *grid, model_data *data, int tStart, int tEnd) {
    // get our 3D index based on our blocks/threads
    int i = (blockIdx.x*blockDim.x) + threadIdx.x;
    int j = (blockIdx.y*blockDim.y) + threadIdx.y;
    int k = (blockIdx.z*blockDim.z) + threadIdx.z;
    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    long bufidx;

    if ((i < NX+2) && (j < NY+2) && (k < NZ+1)) {
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            // we pass through the reference to the starting point
            // of the next 3D buffer since stencils operate in 3D space
            calc_pipert(&(data->prespert[bufidx]), grid->p0, &(data->pipert[bufidx]), i, j, k, NX, NY);
        }
    }
}

__global__ void calcvort(datagrid *grid, model_data *data, int tStart, int tEnd) {
    // get our 3D index based on our blocks/threads
    int i = (blockIdx.x*blockDim.x) + threadIdx.x;
    int j = (blockIdx.y*blockDim.y) + threadIdx.y;
    int k = (blockIdx.z*blockDim.z) + threadIdx.z;
    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    long bufidx;
    float dx, dy, dz;

    if ((i < NX) && (j < NY+1) && (k > 0) && (k < NZ)) {
        dy = yf(j) - yf(j-1);
        dz = zf(k) - zf(k-1);
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            calc_xvort(&(data->vstag[bufidx]), &(data->wstag[bufidx]), &(data->tem1[bufidx]), dy, dz, i, j, k, NX, NY);
            // lower boundary condition of stencil
            if ((k == 1) && (zf(k-1) == 0)) {
                data->tem1[P4(i, j, 0, tidx, NX, NY, NZ)] = data->tem1[P4(i, j, 1, tidx, NX, NY, NZ)];
            }
        }
    }

    if ((i < NX+1) && (j < NY) && (k > 0) && (k < NZ+1)) {
        dx = xf(i) - xf(i-1);
        dz = zf(k) - zf(k-1);
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            calc_yvort(&(data->ustag[bufidx]), &(data->wstag[bufidx]), &(data->tem2[bufidx]), dx, dz, i, j, k, NX, NY);
            // lower boundary condition of stencil
            if ((k == 1) && (zf(k-1) == 0)) {
                data->tem2[P4(i, j, 0, tidx, NX, NY, NZ)] = data->tem2[P4(i, j, 1, tidx, NX, NY, NZ)];
            }
        }
    }

    if ((i < NX+1) && (j < NY+1) && (k < NZ+1)) {
        dx = xf(i) - xf(i-1);
        dy = yf(j) - yf(j-1);
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            calc_zvort(&(data->ustag[bufidx]), &(data->vstag[bufidx]), &(data->tem3[bufidx]), dx, dy, i, j, k, NX, NY);
        }
    }
}

__global__ void doDiffVort(datagrid *grid, model_data *data, int tStart, int tEnd) {
    // get our 3D index based on our blocks/threads
    int i = (blockIdx.x*blockDim.x) + threadIdx.x;
    int j = (blockIdx.y*blockDim.y) + threadIdx.y;
    int k = (blockIdx.z*blockDim.z) + threadIdx.z;
    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    long bufidx;
    float dx, dy, dz;

    if ((i < NX) && (j < NY+1) && (k > 0) && (k < NZ)) {
        dy = yf(j) - yf(j-1);
        dz = zf(k) - zf(k-1);
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            calc_xvort(&(data->diffv[bufidx]), &(data->diffw[bufidx]), &(data->tem1[bufidx]), dy, dz, i, j, k, NX, NY);

            // lower boundary condition of stencil
            if ((k == 1) && (zf(k-1) == 0)) {
                data->tem1[P4(i, j, 0, tidx, NX, NY, NZ)] = data->tem1[P4(i, j, 1, tidx, NX, NY, NZ)];
            }
        }
    }

    if ((i < NX+1) && (j < NY) && (k > 0) && (k < NZ+1)) {
        dx = xf(i) - xf(i-1);
        dz = zf(k) - zf(k-1);
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            calc_yvort(&(data->diffu[bufidx]), &(data->diffw[bufidx]), &(data->tem2[bufidx]), dx, dz, i, j, k, NX, NY);
            // lower boundary condition of stencil
            if ((k == 1) && (zf(k-1) == 0)) {
                data->tem2[P4(i, j, 0, tidx, NX, NY, NZ)] = data->tem2[P4(i, j, 1, tidx, NX, NY, NZ)];
            }
        }
    }

    if ((i < NX+1) && (j < NY+1) && (k < NZ+1)) {
        dx = xf(i) - xf(i-1);
        dy = yf(j) - yf(j-1);
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            calc_zvort(&(data->diffu[bufidx]), &(data->diffv[bufidx]), &(data->tem3[bufidx]), dx, dy, i, j, k, NX, NY);
        }
    }
}


__global__ void doTurbVort(datagrid *grid, model_data *data, int tStart, int tEnd) {
    // get our 3D index based on our blocks/threads
    int i = (blockIdx.x*blockDim.x) + threadIdx.x;
    int j = (blockIdx.y*blockDim.y) + threadIdx.y;
    int k = (blockIdx.z*blockDim.z) + threadIdx.z;
    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    long bufidx;
    float dx, dy, dz;

    if ((i < NX) && (j < NY+1) && (k > 0) && (k < NZ)) {
        dy = yf(j) - yf(j-1);
        dz = zf(k) - zf(k-1);
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            calc_xvort(&(data->turbv[bufidx]), &(data->turbw[bufidx]), &(data->tem1[bufidx]), dy, dz, i, j, k, NX, NY);

            // lower boundary condition of stencil
            if ((k == 1) && (zf(k-1) == 0)) {
                data->tem1[P4(i, j, 0, tidx, NX, NY, NZ)] = data->tem1[P4(i, j, 1, tidx, NX, NY, NZ)];
            }
        }
    }

    if ((i < NX+1) && (j < NY) && (k > 0) && (k < NZ+1)) {
        dx = xf(i) - xf(i-1);
        dz = zf(k) - zf(k-1);
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            calc_yvort(&(data->turbu[bufidx]), &(data->turbw[bufidx]), &(data->tem2[bufidx]), dx, dz, i, j, k, NX, NY);
            // lower boundary condition of stencil
            if ((k == 1) && (zf(k-1) == 0)) {
                data->tem2[P4(i, j, 0, tidx, NX, NY, NZ)] = data->tem2[P4(i, j, 1, tidx, NX, NY, NZ)];
            }
        }
    }

    if ((i < NX+1) && (j < NY+1) && (k < NZ+1)) {
        dx = xf(i) - xf(i-1);
        dy = yf(j) - yf(j-1);
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            calc_zvort(&(data->turbu[bufidx]), &(data->turbv[bufidx]), &(data->tem3[bufidx]), dx, dy, i, j, k, NX, NY);
        }
    }
}

/* Compute the forcing tendencies from the Vorticity Equation */
__global__ void calcvortstretch(datagrid *grid, model_data *data, int tStart, int tEnd) {
    // get our 3D index based on our blocks/threads
    int i = (blockIdx.x*blockDim.x) + threadIdx.x;
    int j = (blockIdx.y*blockDim.y) + threadIdx.y;
    int k = (blockIdx.z*blockDim.z) + threadIdx.z;
    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    long bufidx;
    float dx, dy, dz;

    if ((i < NX) && (j < NY) && (k < NZ)) {
        dy = yf(j+1) - yf(j);
        dz = zf(k+1) - zf(k);
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            calc_xvort_stretch(&(data->ustag[bufidx]), &(data->wstag[bufidx]), \
                               &(data->xvort[bufidx]), &(data->xvort_stretch[bufidx]), \
                               dy, dz, i, j, k, NX, NY, NZ);
            if ((k == 1) && (zf(k-1) == 0)) {
                data->xvort_stretch[P4(i, j, 0, tidx, NX, NY, NZ)] = data->xvort_stretch[P4(i, j, 1, tidx, NX, NY, NZ)];
            }
        }
    }

    if ((i < NX) && (j < NY) && (k < NZ)) {
        dx = xf(i+1) - xf(i);
        dz = zf(k+1) - zf(k);
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            calc_yvort_stretch(&(data->vstag[bufidx]), &(data->wstag[bufidx]), \
                               &(data->yvort[bufidx]), &(data->yvort_stretch[bufidx]), \
                               dx, dz, i, j, k, NX, NY, NZ);
            if ((k == 1) && (zf(k-1) == 0)) {
                data->yvort_stretch[P4(i, j, 0, tidx, NX, NY, NZ)] = data->yvort_stretch[P4(i, j, 1, tidx, NX, NY, NZ)];
            }
        }
    }

    if ((i < NX) && (j < NY) && (k < NZ)) {
        dx = xf(i+1) - xf(i);
        dz = yf(j+1) - yf(j);
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            calc_zvort_stretch(&(data->ustag[bufidx]), &(data->vstag[bufidx]), \
                               &(data->zvort[bufidx]), &(data->zvort_stretch[bufidx]), \
                               dx, dy, i, j, k, NX, NY, NZ);
        }
    }
}

/* Compute the forcing tendencies from the Vorticity Equation */
__global__ void calcxvorttilt(datagrid *grid, model_data *data, int tStart, int tEnd) {
    // get our 3D index based on our blocks/threads
    int i = (blockIdx.x*blockDim.x) + threadIdx.x;
    int j = (blockIdx.y*blockDim.y) + threadIdx.y;
    int k = (blockIdx.z*blockDim.z) + threadIdx.z;
    int idx_4D[4];
    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    //printf("%i, %i, %i\n", i, j, k);

    idx_4D[0] = i; idx_4D[1] = j; idx_4D[2] = k;
    if ((i < NX) && (j < NY) && (k > 0) && (k < NZ)) {
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            idx_4D[3] = tidx;
            calc_xvort_tilt(grid, data, idx_4D, NX, NY, NZ);
        }
    }
}

/* Compute the forcing tendencies from the Vorticity Equation */
__global__ void calcyvorttilt(datagrid *grid, model_data *data, int tStart, int tEnd) {
    // get our 3D index based on our blocks/threads
    int i = (blockIdx.x*blockDim.x) + threadIdx.x;
    int j = (blockIdx.y*blockDim.y) + threadIdx.y;
    int k = (blockIdx.z*blockDim.z) + threadIdx.z;
    int idx_4D[4];
    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    //printf("%i, %i, %i\n", i, j, k);

    idx_4D[0] = i; idx_4D[1] = j; idx_4D[2] = k;
    if ((i < NX) && (j < NY) && (k > 0) && (k < NZ)) {
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            idx_4D[3] = tidx;
            calc_yvort_tilt(grid, data, idx_4D, NX, NY, NZ);
        }
    }
}

/* Compute the forcing tendencies from the Vorticity Equation */
__global__ void calczvorttilt(datagrid *grid, model_data *data, int tStart, int tEnd) {
    // get our 3D index based on our blocks/threads
    int i = (blockIdx.x*blockDim.x) + threadIdx.x;
    int j = (blockIdx.y*blockDim.y) + threadIdx.y;
    int k = (blockIdx.z*blockDim.z) + threadIdx.z;
    int idx_4D[4];
    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    //printf("%i, %i, %i\n", i, j, k);

    idx_4D[0] = i; idx_4D[1] = j; idx_4D[2] = k;
    if ((i < NX) && (j < NY) && (k > 0) && (k < NZ)) {
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            idx_4D[3] = tidx;
            calc_zvort_tilt(grid, data, idx_4D, NX, NY, NZ);
        }
    }
}

/* Compute the forcing tendencies from the buoyancy/baroclinic term */ 
__global__ void calcvortbaro(datagrid *grid, model_data *data, int tStart, int tEnd) {
    // get our 3D index based on our blocks/threads
    int i = (blockIdx.x*blockDim.x) + threadIdx.x;
    int j = (blockIdx.y*blockDim.y) + threadIdx.y;
    int k = (blockIdx.z*blockDim.z) + threadIdx.z;
    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    long bufidx;
    float dx, dy;

    if ((i < NX-1) && (j < NY-1) && (k < NZ) && ( i > 0 ) && (j > 0) && (k > 0)) {
        // loop over the number of time steps we have in memory
        dx = xh(i+1) - xh(i-1);
        dy = yh(j+1) - yh(j-1);
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            calc_xvort_baro(&(data->thrhopert[bufidx]), data->th0, data->qv0, &(data->xvort_baro[bufidx]), dx, i, j, k, NX, NY, NZ);
            calc_yvort_baro(&(data->thrhopert[bufidx]), data->th0, data->qv0, &(data->yvort_baro[bufidx]), dy, i, j, k, NX, NY, NZ);
        }
    }
}

/* Compute the forcing tendencies from the pressure-volume solenoid term */
__global__ void calcvortsolenoid(datagrid *grid, model_data *data, int tStart, int tEnd) {
    // get our 3D index based on our blocks/threads
    int i = (blockIdx.x*blockDim.x) + threadIdx.x;
    int j = (blockIdx.y*blockDim.y) + threadIdx.y;
    int k = (blockIdx.z*blockDim.z) + threadIdx.z;
    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    float dx, dy, dz;
    long bufidx;

    // Even though there are NZ points, it's a center difference
    // and we reach out NZ+1 points to get the derivatives
    if ((i < NX-1) && (j < NY-1) && (k < NZ) && ( i > 0 ) && (j > 0)) {
        dx = xh(i+1)-xh(i-1);
        dy = yh(i+1)-yh(i-1);
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            calc_zvort_solenoid(&(data->pipert[bufidx]), &(data->thrhopert[bufidx]), \
                                &(data->zvort_solenoid[bufidx]), dx, dy, i, j, k, NX, NY, NZ);
        }
    }
    if ((i < NX-1) && (j < NY-1) && (k < NZ) && ( i > 0 ) && (j > 0) && (k > 0)) {
        // loop over the number of time steps we have in memory
        dx = xh(i+1)-xh(i-1);
        dy = yh(i+1)-yh(i-1);
        dz = zh(i+1)-zh(i-1);
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            bufidx = P4(0, 0, 0, tidx, NX, NY, NZ);
            calc_xvort_solenoid(&(data->pipert[bufidx]), &(data->thrhopert[bufidx]), grid->th0, grid->qv0, \
                                &(data->xvort_solenoid[bufidx]), dy, dz, i, j, k, NX, NY, NZ);
            calc_yvort_solenoid(&(data->pipert[bufidx]), &(data->thrhopert[bufidx]), grid->th0, grid->qv0, \
                                &(data->yvort_solenoid[bufidx]), dx, dz, i, j, k, NX, NY, NZ);
            if ((k == 1) && (zf(k-1) == 0)) {
                data->xvort_solenoid[P4(i, j, 0, tidx, NX, NY, NZ)] = data->xvort_solenoid[P4(i, j, 1, tidx, NX, NY, NZ)];
                data->yvort_solenoid[P4(i, j, 0, tidx, NX, NY, NZ)] = data->yvort_solenoid[P4(i, j, 1, tidx, NX, NY, NZ)];
            }
        }
    }
}

/* Zero out the temporary arrays */
__global__ void zeroTemArrays(datagrid *grid, model_data *data, int tStart, int tEnd) {
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    int j = blockIdx.y*blockDim.y + threadIdx.y;
    int k = blockIdx.z*blockDim.z + threadIdx.z;

    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    float *dum0;
    if (( i < NX+1) && ( j < NY+1) && ( k < NZ+1)) {
        dum0 = data->tem1;
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            TEM4D(i, j, k, tidx) = 0.0;
        }
        dum0 = data->tem2;
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            TEM4D(i, j, k, tidx) = 0.0;
        }
        dum0 = data->tem3;
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            TEM4D(i, j, k, tidx) = 0.0;
        }
        dum0 = data->tem4;
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            TEM4D(i, j, k, tidx) = 0.0;
        }
        dum0 = data->tem5;
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            TEM4D(i, j, k, tidx) = 0.0;
        }
        dum0 = data->tem6;
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            TEM4D(i, j, k, tidx) = 0.0;
        }
    }
}


/* Average our vorticity values back to the scalar grid for interpolation
   to the parcel paths. We're able to do this in parallel by making use of
   the three temporary arrays allocated on our grid, which means that the
   xvort/yvort/zvort arrays will be averaged into tem1/tem2/tem3. After
   calling this kernel, you MUST set the new pointers appropriately. */
__global__ void doVortAvg(datagrid *grid, model_data *data, int tStart, int tEnd) {

    // get our grid indices based on our block and thread info
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    int j = blockIdx.y*blockDim.y + threadIdx.y;
    int k = blockIdx.z*blockDim.z + threadIdx.z;

    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    float *buf0, *dum0;

    if ((i < NX) && (j < NY) && (k < NZ)) {
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            // average the temporary arrays into the result arrays
            dum0 = data->tem1;
            buf0 = data->xvort;
            BUF4D(i, j, k, tidx) = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i, j+1, k, tidx) +\
                                            TEM4D(i, j, k+1, tidx) + TEM4D(i, j+1, k+1, tidx) );

            dum0 = data->tem2;
            buf0 = data->yvort;
            BUF4D(i, j, k, tidx) = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i+1, j, k, tidx) +\
                                            TEM4D(i, j, k+1, tidx) + TEM4D(i+1, j, k+1, tidx) );

            dum0 = data->tem3;
            buf0 = data->zvort;
            BUF4D(i, j, k, tidx) = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i+1, j, k, tidx) +\
                                            TEM4D(i, j+1, k, tidx) + TEM4D(i+1, j+1, k, tidx) );
        }
    }
}

__global__ void doTurbVortAvg(datagrid *grid, model_data *data, int tStart, int tEnd) {

    // get our grid indices based on our block and thread info
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    int j = blockIdx.y*blockDim.y + threadIdx.y;
    int k = blockIdx.z*blockDim.z + threadIdx.z;

    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    float *buf0, *dum0;

    if ((i < NX) && (j < NY) && (k < NZ)) {
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            // average the temporary arrays into the result arrays
            dum0 = data->tem1;
            buf0 = data->turbxvort;
            BUF4D(i, j, k, tidx) = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i, j+1, k, tidx) +\
                                            TEM4D(i, j, k+1, tidx) + TEM4D(i, j+1, k+1, tidx) );

            dum0 = data->tem2;
            buf0 = data->turbyvort;
            BUF4D(i, j, k, tidx) = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i+1, j, k, tidx) +\
                                            TEM4D(i, j, k+1, tidx) + TEM4D(i+1, j, k+1, tidx) );

            dum0 = data->tem3;
            buf0 = data->turbzvort;
            BUF4D(i, j, k, tidx) = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i+1, j, k, tidx) +\
                                            TEM4D(i, j+1, k, tidx) + TEM4D(i+1, j+1, k, tidx) );
        }
    }
}


__global__ void doDiffVortAvg(datagrid *grid, model_data *data, int tStart, int tEnd) {

    // get our grid indices based on our block and thread info
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    int j = blockIdx.y*blockDim.y + threadIdx.y;
    int k = blockIdx.z*blockDim.z + threadIdx.z;

    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    float *buf0, *dum0;

    if ((i < NX) && (j < NY) && (k < NZ)) {
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            // average the temporary arrays into the result arrays
            dum0 = data->tem1;
            buf0 = data->diffxvort;
            BUF4D(i, j, k, tidx) = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i, j+1, k, tidx) +\
                                            TEM4D(i, j, k+1, tidx) + TEM4D(i, j+1, k+1, tidx) );

            dum0 = data->tem2;
            buf0 = data->diffyvort;
            BUF4D(i, j, k, tidx) = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i+1, j, k, tidx) +\
                                            TEM4D(i, j, k+1, tidx) + TEM4D(i+1, j, k+1, tidx) );

            dum0 = data->tem3;
            buf0 = data->diffzvort;
            BUF4D(i, j, k, tidx) = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i+1, j, k, tidx) +\
                                            TEM4D(i, j+1, k, tidx) + TEM4D(i+1, j+1, k, tidx) );
        }
    }
}

/* Average the derivatives within the temporary arrays used to compute
   the tilting rate and then combine the terms into the final xvtilt
   array. It is assumed that the derivatives have been precomputed into
   the temporary arrays. */
__global__ void doXVortTiltAvg(datagrid *grid, model_data *data, int tStart, int tEnd) {
    // get our grid indices based on our block and thread info
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    int j = blockIdx.y*blockDim.y + threadIdx.y;
    int k = blockIdx.z*blockDim.z + threadIdx.z;

    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    float *buf0, *dum0;
    float dudy,dudz;

    // We do the average for each array at a given point
    // and then finish the computation for the zvort tilt
    if ((i < NX) && (j < NY) && (k < NZ)) {
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            dum0 = data->tem1;
            //dudy = TEM4D(i, j, k, tidx);
            dudy = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i+1, j, k, tidx) + \
                            TEM4D(i, j+1, k, tidx) + TEM4D(i+1, j+1, k, tidx) );

            dum0 = data->tem2;
            //dudz = TEM4D(i, j, k, tidx);
            dudz = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i+1, j, k, tidx) + \
                            TEM4D(i, j, k+1, tidx) + TEM4D(i+1, j, k+1, tidx) );

            buf0 = data->zvort;
            float zvort = BUF4D(i, j, k, tidx);
            buf0 = data->yvort;
            float yvort = BUF4D(i, j, k, tidx);

            buf0 = data->xvtilt;
            BUF4D(i, j, k, tidx) = zvort * dudz + yvort * dudy; 
        }
    }
}

/* Average the derivatives within the temporary arrays used to compute
   the tilting rate and then combine the terms into the final yvtilt
   array. It is assumed that the derivatives have been precomputed into
   the temporary arrays. */
__global__ void doYVortTiltAvg(datagrid *grid, model_data *data, int tStart, int tEnd) {
    // get our grid indices based on our block and thread info
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    int j = blockIdx.y*blockDim.y + threadIdx.y;
    int k = blockIdx.z*blockDim.z + threadIdx.z;

    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    float *buf0, *dum0;
    float dvdx, dvdz;

    // We do the average for each array at a given point
    // and then finish the computation for the zvort tilt
    if ((i < NX) && (j < NY) && (k < NZ)) {
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            dum0 = data->tem1;
            //dvdx = TEM4D(i, j, k, tidx);
            dvdx = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i+1, j, k, tidx) + \
                            TEM4D(i, j+1, k, tidx) + TEM4D(i+1, j+1, k, tidx) );

            dum0 = data->tem2;
            //dvdz = TEM4D(i, j, k, tidx);
            dvdz = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i, j+1, k, tidx) + \
                            TEM4D(i, j, k+1, tidx) + TEM4D(i, j+1, k+1, tidx) );

            buf0 = data->xvort;
            float xvort = BUF4D(i, j, k, tidx);
            buf0 = data->zvort;
            float zvort = BUF4D(i, j, k, tidx);

            buf0 = data->yvtilt;
            BUF4D(i, j, k, tidx) = xvort * dvdx + zvort * dvdz; 
        }
    }
}

/* Average the derivatives within the temporary arrays used to compute
   the tilting rate and then combine the terms into the final zvtilt
   array. It is assumed that the derivatives have been precomputed into
   the temporary arrays. */
__global__ void doZVortTiltAvg(datagrid *grid, model_data *data, int tStart, int tEnd) {
    // get our grid indices based on our block and thread info
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    int j = blockIdx.y*blockDim.y + threadIdx.y;
    int k = blockIdx.z*blockDim.z + threadIdx.z;

    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    float *buf0, *dum0;
    float dwdx, dwdy;

    // We do the average for each array at a given point
    // and then finish the computation for the zvort tilt
    if ((i < NX) && (j < NY) && (k < NZ)) {
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            dum0 = data->tem1;
            //dwdx = TEM4D(i, j, k, tidx);
            dwdx = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i+1, j, k, tidx) + \
                            TEM4D(i, j+1, k, tidx) + TEM4D(i+1, j, k+1, tidx) );

            dum0 = data->tem2;
            dwdy = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i, j+1, k, tidx) + \
                            TEM4D(i, j, k+1, tidx) + TEM4D(i, j+1, k+1, tidx) );
            //dwdy = TEM4D(i, j, k, tidx);
            buf0 = data->xvort;
            float xvort = BUF4D(i, j, k, tidx);
            buf0 = data->yvort;
            float yvort = BUF4D(i, j, k, tidx);
            
            buf0 = data->zvtilt;
            BUF4D(i, j, k, tidx) = xvort * dwdx + yvort * dwdy; 
        }
    }
}

#endif
