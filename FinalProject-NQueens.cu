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
unsigned long count = 0;
long *answer;
struct timezone Idunno;
struct timeval startTime, endTime;

 #ifndef NUM
 #define NUM 12
 #endif

//CPU helper function to test is a queen can be placed
int isAllowed(int **board, int row, int col, int n)
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
    if (board[x][y] == 1)
    {
      return 0;
    }
  }
 return 1;
}
// CPU Solver for N-queens problem
int Solver(int **board, int col, int n)
{
  if (col >= n)
  {
    total++;
    return 1;
  }

  int nextState = 0;

  for(int k = 0; k < n; k++)
  {
    if (isAllowed(board,k,col, n))
    {
      board[k][col] = 1;
      nextState = Solver(board, col + 1, n);
      board[k][col] = 0;
    }
  }
  return nextState;
}

// GPU parallel kernel for N-Queens
__global__ void kernel(long *answer, int SegSize, int nBX, int nBY, int genNum)
{
  __shared__ long sol[NUM][NUM];
  __shared__ char tup[NUM][NUM][NUM];

  int wrongCount = 0;
  sol[threadIdx.x][threadIdx.y] = 0;
  tup[threadIdx.x][threadIdx.y][0] = blockIdx.y % SegSize;
  int totalGenerated = powf(NUM, genNum);
  int blockYSeg = blockIdx.y / SegSize;
  int workLoad = totalGenerated / nBY;
  int runOff = totalGenerated - workLoad *nBY;




  int temp = blockIdx.x;
  for(int x = 1; x <=nBX; x++)
  {
    tup[threadIdx.x][threadIdx.y][x] = temp % NUM;
    temp = temp / NUM;

  }

  int tupCount = nBX;
  tup[threadIdx.x][threadIdx.y][++tupCount] = threadIdx.x;
  tup[threadIdx.x][threadIdx.y][++tupCount] = threadIdx.y;

  for(int k = tupCount; k > 0; k--)
  {
    for(int m = k - 1, counter = 1; m >= 0; counter++, m--)
    {
      //Checks diagonal left, down
      wrongCount += (tup[threadIdx.x][threadIdx.y][k] + counter) == tup[threadIdx.x][threadIdx.y][m];
      //Checks row its in
      wrongCount += tup[threadIdx.x][threadIdx.y][k] == tup[threadIdx.x][threadIdx.y][m];
      // Checks diagonal left, up
      wrongCount  += (tup[threadIdx.x][threadIdx.y][k] - counter) == tup[threadIdx.x][threadIdx.y][m];

    }
  }






  if (wrongCount == 0)
  {
    int begin = blockYSeg * workLoad;
    for(int c = begin; c < begin + workLoad + (blockYSeg == nBY - 1) * runOff; c++)
    {
      //last values is made in tuple, convert and store to tup array
      int temp = c;
      for(int q = 0, z =tupCount + 1; q < genNum; z++, q++)
      {
        tup[threadIdx.x][threadIdx.y][q] = temp % NUM;
        temp = temp / NUM;
      }

      //checks that the genNum tuple values are indeed unique (saves work overall)
      for(int a = 0; a < genNum && wrongCount == 0; a++){
				for(int b = 0; b < genNum && wrongCount == 0; b++){
					wrongCount += tup[threadIdx.x][threadIdx.y][tupCount + 1 + a] == tup[threadIdx.x][threadIdx.y][tupCount + 1 + b] && a != b;
				}
			}

      for(int k = NUM -1; k > wrongCount; k--)
      {
        for(int m = k - 1, counter = 1; m >= 0; counter++, m--)
        {
          //Checks diagonal left, down
          wrongCount += (tup[threadIdx.x][threadIdx.y][k] + counter) == tup[threadIdx.x][threadIdx.y][m];
          //Checks row its in
          wrongCount += tup[threadIdx.x][threadIdx.y][k] == tup[threadIdx.x][threadIdx.y][m];
          // Checks diagonal left, up
          wrongCount  += (tup[threadIdx.x][threadIdx.y][k] - counter) == tup[threadIdx.x][threadIdx.y][m];

        }
      }

      sol[threadIdx.x][threadIdx.y] += !(wrongCount);
      wrongCount = 0;

    }
  }

  __syncthreads();

    // sum all threads in block to get total
  	if(threadIdx.x == 0 && threadIdx.y == 0)
    {

  		long total = 0;

  		for(int i =0; i < NUM; i++){
  			for(int j = 0; j < NUM; j++){
  				total += sol[i][j];
  			}
  		}
  		answer[gridDim.x * blockIdx.y + blockIdx.x] = total;
  	}


  	__syncthreads();
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
	printf("CPU Time: %ld.%06ld\n", sec_diff, usec_diff);
	return (double)(sec_diff*1.0 + usec_diff/1000000.0);
}


int main(int argc, char **argv) {

  if(argc < 3) {

    printf("\nError, too few arguments. Usage: ./CHANGE THIS\n");
    return -1;
  }

  const int NUM_TUPLEX = atoi(argv[1]);
  const int NUM_TUPLEY = atoi(argv[2]);
  const int generatedNum = NUM - 3 - NUM_TUPLEX;
  cudaEvent_t start, stop;
  float elapsedTime;

  if(generatedNum < 0){
    printf("\nThe numbers generated iteratively cannot be less than 0.\n");
    exit(1);
  }

  //ensure N is in the correct range
  if(NUM < 4  || NUM > 22){
    printf("\nN(%d) must be between 4 and 22 inclusive\n", NUM);
    exit(1);
  }

  //ensure that at least one of the tuple values is generated by the block's X coordinate value
  if(NUM_TUPLEX < 1){
    printf("\nThe number of tuples generated by each block's X coordinate value must be >= 1\n");
    exit(1);
  }

  	//ensure that the number of Y segments that the numGen work is divided into
  	//is at least one per work segment
  	if(NUM_TUPLEY > pow(NUM, generatedNum)){
  		printf("\n number of groups of columns must be less than or equal to N^(N - 3 - (1st ARG))\n");
  		exit(1);
  	}

  //CPU setup
  int **board;
  board = (int **) malloc(NUM * sizeof(int *));

  for (int i = 0; i < NUM; i++) {
    board[i] = (int *) malloc(NUM * sizeof(int));

  }
  for (int i = 0; i < NUM; i++) {
    for (int j = 0; j < NUM; j++) {
      board[i][j] = 0;

    }
  }

  int WIDTH, HEIGHT, NUM_BLOCKS, YSegmentSize;
  WIDTH = pow(NUM, NUM_TUPLEX);
  YSegmentSize = (NUM / 2) + (NUM % 2);
  HEIGHT = YSegmentSize + NUM_TUPLEY;
  NUM_BLOCKS = WIDTH * HEIGHT;


  long *d_answer;
  answer = new long[NUM_BLOCKS];

  cudaMalloc((void **) &d_answer, sizeof(long) * NUM_BLOCKS);

  dim3 block(NUM, NUM); //threads w x h
  dim3 grid(WIDTH, HEIGHT); //blocks w x h

  cudaEventCreate(&start);
  cudaEventCreate(&stop);
  cudaEventRecord(start, 0);

  kernel<<<grid, block>>>(d_answer, YSegmentSize, NUM_TUPLEX, NUM_TUPLEY, generatedNum);
  cudaThreadSynchronize();

  cudaEventRecord(stop, 0);
  cudaEventSynchronize(stop);
  cudaEventElapsedTime(&elapsedTime, start, stop);

  cudaMemcpy(answer,d_answer, sizeof(long) * NUM_BLOCKS, cudaMemcpyDeviceToHost);





	srand(1);
  gettimeofday(&startTime, &Idunno);
  Solver(board, 0, NUM);


  printf("\nTotal Solutions: %d boards\n\n",total);
  report_running_time();
  printf("GPU Time: %f secs\n", (elapsedTime / 1000.00));
  return 0;

}
