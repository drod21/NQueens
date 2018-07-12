/* ==================================================================
  Programmers: Conner Wulf (connerwulf@mail.usf.edu),
               Derek Rodriguez (derek23@mail.usf.edu)
	       David Hoambrecker (david106@mail.usf.edu)
   ==================================================================
*/

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <sys/time.h>
#include <iostream>
#include <cuda_runtime.h>
#include <cuda.h>
#include <vector>

using namespace std;
static int total = 0;
struct timezone Idunno;	
struct timeval startTime, endTime;
//CPU helper function to test is a queen can be placed
int isAllowed(int **board, int row, int col, int n) // make this the kernel?????
{
  int x,y;

  //left check
  for (x = 0; x < col; x++)
  {
    if(board[row][x] == 1)
    {
      return 0;
    }
  }
  //check left diagonal up
  for(x = row, y = col; x >= 0 && y >= 0; x--, y--)
    {
      if (board[x][y] == 1)
      {
        return 0;
      }
    }
  for(x = row, y = col; x < n && y >= 0; x++, y--)
  {
    if  (board[x][y] == 1)
    {
      return 0;
    }
  }
 return 1;
}

// GPU helper problem

/*
__global__ void nqueen_kernel_3(*job_data, *results ... )
{
  __const__ tid; //The index of the thread within the block
  __register__ rowIndex, solution, index;
  __shared__ ROW[MAX_ROW][BLOCK_SIZE];
  __const__ upper_bound = the upper bound of the job-pool for this block;
  __shared__ seek;
  if(tid == 0) { set seek to point to the next new job in the job-pool for this block;}
  each thread fetches a task from job_data into its array ROW[MAX_ROW] [tid];
  for(; rowIndex >= 0; rowIndex--) {
  ĂĂ //the same code as in the low-divergence n-queens kernel is omitted
  if (rowIndex == 0) { //current job is done.
  index = atomicAdd(&seek,1); //get index of new job
  if (index exceeds pool upper bound)
  break;
  else{
  gets this job by index from the job-pool as the new job of this thread;
  rowIndex++;
  }
  }
  }
  reduction of the solutions of the threads within this block;
}
*/

/* use this one */
/*
__global__ void nqueen_kernel_0(*job_data, *results, *work_space... )
{
  __register__ rowIndex, solution;
  each thread fetches a task from job_data into its array ROW[ ] in work_space;
  while(rowIndex >= 0) {
    if (no position to place new queen in ROW[rowIndex]) { rowIndex--; }
    else{
      finds a valid position P in ROW[rowIndex];
      places a queen at P in ROW[rowIndex] and mark the position as occupied;
    if (reaches last row) { solution++; }
    else{
      generates ROW[rowIndex+1] based on Row[rowIndex] and the position P;
      rowIndex++;
    }
  }
}
reduction of the solutions of the threads within each bl*/
__global__ void isAllowedGpu(int *d_board, int row, int col, int n, int *allowed)
{
  int x = threadIdx.x + blockDim.x * blockIdx.x;
  int y = threadIdx.y + blockDim.y * blockIdx.y;
  int i, j;
  //left check
  for (i = x; i < col + x; i++)
  {
    if(d_board[i] == 1)
    {
      *allowed = 0;
      return;
    }
  }
  //check left diagonal up
  for(i = row + y, j = x + col; i >= y && j >= x; i--, j--)
    {
      if(d_board[i * n + j] == 1)
      {
        *allowed = 0;
        return;
      }
    }
  for(i = row, j = col + x; i < n && j >= x; i++, j--)
  {
    if(d_board[i * n + j] == 1)
    {
      *allowed = 0;
      return;
    }
  }
 *allowed = 1;
}
//N-queen solver for CPU algorithm
int Solver(int **board, int col, int n)
{
  int *allowed;
  int temp = 0;
  int *d_board;
  dim3 threadsPerBlock(n, n);
  dim3 numBlocks(n / threadsPerBlock.x, n / threadsPerBlock.y);
  cudaMalloc((void **) &d_board, sizeof(int) * n);
  cudaMalloc((void **) &allowed, n);
  cudaMemcpy(allowed, &temp, sizeof(int), cudaMemcpyHostToDevice);
  cudaMemcpy(d_board, board[0], sizeof(int) * n * n, cudaMemcpyHostToDevice);

  if (col >= n * n)
  {
    total++;
    return 1;
  }

  int nextState = 0;
  for(int k = 0; k < n; k++)
  {
    isAllowedGpu<<<numBlocks, threadsPerBlock>>>(d_board, k, col, n * n, allowed);
    cudaMemcpy(&temp, allowed, sizeof(int), cudaMemcpyDeviceToHost);
    if(temp == 1)
    {
      board[k][col] = 1;
      nextState = Solver(board, col + 1, n) || nextState;
      board[k][col] = 0;
    }
  }

  return nextState;
}

double report_running_time() {
	long sec_diff, usec_diff;
	gettimeofday(&endTime, &Idunno);
	sec_diff = endTime.tv_sec - startTime.tv_sec;
	usec_diff= endTime.tv_usec-startTime.tv_usec;
	if(usec_diff < 0) {
		sec_diff --;
		usec_diff += 1000000;
	}
	printf("Running time for CPU version: %ld.%06ld\n", sec_diff, usec_diff);
	return (double)(sec_diff*1.0 + usec_diff/1000000.0);
}

int main(int argc, char **argv) {
  //  CPU VERSION
  
  const int n = atoi(argv[1]);
  int **board;
  board = (int **) malloc(n * sizeof(int *));
  for (int i = 0; i < n; i++) {
    board[i] = (int *) malloc(n * sizeof(int));
  }
  for (int i = 0; i < n; i++) {
    for (int j = 0; j < n; j++) {
      board[i][j] = 0;
    }
  }
	// vector<vector<int> > board;
	// board.resize(n, std::vector<int>(n, 0));
	
	srand(1);
	gettimeofday(&startTime, &Idunno);

  if(Solver(board,0,n) == 0)
  {
    printf("No Solution\n");
  	report_running_time();
    return 0;
  }
  printf("\nTotal Solutions(CPU): %d boards\n\n",total);
	report_running_time();

  return 0;

}
