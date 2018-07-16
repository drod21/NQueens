#include <stdio.h>
#include <iostream>
#include <ctime>
#include <string.h>
#include <cuda_runtime.h>
#include <curand.h>
#include <curand_kernel.h>

#define NUM_BLOCKS 16
#define NUM_THREADS 16
#define Num_Queens 8
#define MAX_ITER 4000

using namespace std;

__device__ int checkDiagonals(int q,int i, int* S)
// Returns 1 if no queen in diagonal, else 0
{
	int I = blockIdx.x*NUM_THREADS*Num_Queens + threadIdx.x*Num_Queens;
	for (int j = 1; j<=i; j++){
		if (S[I+i-j] == q-j | S[I+i-j] == q+j){
			return 0;
		}
	}
	return 1;
}

__device__ int sum(int row[], int len)
// Returns sum of an array
{

	int s = 0;
	for (int i = 0; i<len; i++){
		s += row[i];
	}
	return s;
}

/*__global__ void setup_kernel (curandState * state, unsigned long seed)
// Create states to generate random numbers
{
	int id = blockIdx.x*NUM_BLOCKS + threadIdx.x;
	curand_init( seed, id, 0, &state[id] );
}
*/
__global__ void kernel(int* Sol, curandState* globalState,unsigned long seed)
// Kernel to solve puzzle
{
	int ind = blockIdx.x*NUM_BLOCKS + threadIdx.x;
	curand_init( seed, ind, 0, &globalState[ind] );

	// Index for thread to store solution
	int I = blockIdx.x*NUM_THREADS*Num_Queens + threadIdx.x*Num_Queens;
	//int ind = blockIdx.x*NUM_BLOCKS + threadIdx.x;
	int d_Placement[Num_Queens];				// Rows where queens is placed. 1 = row taken
	int tried[Num_Queens][Num_Queens];				// Positions tried at column i




	int queen;

	// Initialize variables
	for (int i = 0; i < Num_Queens; i++){
		Sol[I+i] = -1;
		 d_Placement[i] = 0;
		for (int j = 0; j < Num_Queens; j++){
			tried[i][j] = 0;
		}
	}

	// Set start column and iter counter
  int	i = 0;
	int iter = 0;

	// Get local state to generate numbers
	curandState localState = globalState[ind];

	while (iter < Num_Queens)
	{

		// Generate random number
		queen = curand_uniform( &localState ) * Num_Queens;

		if ( d_Placement[queen] == 0 & tried[i][queen] == 0){ 		// Row clear and not tried before
			tried[i][queen] = 1;				// Set position as tried
			if (checkDiagonals(queen,i,Sol)==1){	// If no attacking queens in diagonal
				Sol[I+i] = queen;			// Add queen to solution
			  d_Placement[queen] = 1;			// Set row as taken
				i++;				// Increment interation counter
				if (i == Num_Queens){			// Finished!
					break;
				}
			}
		}
		if (sum(tried[i],Num_Queens) + sum( d_Placement,Num_Queens) == Num_Queens){ 		// All positions tried
			 d_Placement[Sol[I+i-1]] = 0;					// Free domain
			Sol[I+i-1] = -1;						// Remove queen from solution

			for (int j = 0; j<Num_Queens; j++){		// Reset positions tried for column
				tried[i][j] = 0;
			}
			i--;				// Backtrack to prevoius column
		}
		iter++;
	}
}

int main()
{
	// Initialize states variable and allocate memory
	curandState* devStates;
	cudaMalloc ( &devStates, Num_Queens*sizeof( curandState ) );

	// Initialze seeds
	//setup_kernel <<< NUM_BLOCKS, NUM_THREADS>>> ( devStates,unsigned(time(NULL)) );
	//int id = blockIdx.x*NUM_BLOCKS + threadIdx.x;
	//curand_init( unsigned(time(NULL)), id, 0, &devStates[id] );

	// Initialize array to store solution
	int solution_host[Num_Queens*NUM_BLOCKS*NUM_THREADS];
	int* solution_dev;

	// Allocate memory on device
	cudaMalloc((void**) &solution_dev, (sizeof(Num_Queens*NUM_BLOCKS*NUM_THREADS)));

	// Start clock
	clock_t begin = clock();
	// Launch kernel on device
	kernel<<<NUM_BLOCKS,NUM_THREADS>>> (solution_dev, devStates, unsigned(time(NULL)));
	// Copy solution from device to host
	cudaMemcpy(solution_host, solution_dev, sizeof(int)*Num_Queens*NUM_BLOCKS*NUM_THREADS, cudaMemcpyDeviceToHost);
	// End clock
	clock_t end = clock();

	double elapsed_sec = double(end - begin)/(CLOCKS_PER_SEC/1000);

	// Print time used
	cout << elapsed_sec << endl;

	// Count solutions found (not -1 in last position)
	int solution_count = 0;
	for(int l = 0; l <= (sizeof(solution_host) / sizeof(int)); l++){
		if (solution_host[l] != -1){
			solution_count++;
		}
	}
	// Print solutions found
	cout << solution_count << endl;

	// Free memory on device
	cudaFree(devStates);
	cudaFree(solution_dev);

	return 0;
}
