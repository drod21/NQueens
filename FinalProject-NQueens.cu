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
int isAllowed(vector<vector<int> > board, int row, int col, int n)
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
__device__ int isAllowedGpu(, int row, int col)
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
*/

//N-queen solver for CPU algorithm
int Solver(vector<vector<int> > board, int col, int n)
{
  if (col >= n)
  {

    total++;
    return 1;
  }

  int nextState = 0;
  for(int k = 0; k < n; k++)
  {
    if(isAllowed(board,k,col,n))
    {
      board[k][col] = 1;
      nextState = Solver(board, col + 1,n) || nextState;
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
	vector<vector<int> > board;
	board.resize(n, std::vector<int>(n, 0));
	
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
