/* ==================================================================
  Programmers: Conner Wulf (connerwulf@mail.usf.edu),
               Derek Rodriguez (derek23@mail.usf.edu)
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

const int n = 8;
static int total = 0;



//CPU helper function to test is a queen can be placed
int isAllowed(int board[n][n], int row, int col)
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
__device__ int isAllowedGpu(int board[n][n], int row, int col)
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

//N-queen solver for CPU algorithm
int Solver(int board[n][n], int col)
{
  if (col >= n)
  {

    total++;
    return 1;
  }

  int nextState = 0;
  for(int k = 0; k < n; k++)
  {
    if(isAllowed(board,k,col))
    {
      board[k][col] = 1;
      nextState = Solver(board, col + 1) || nextState;
      board[k][col] = 0;
    }
  }

  return nextState;
}

int main(int argc, char **argv) {
  //  CPU VERSION
  int board[n][n];
  memset(board,0,sizeof(board));

  if(Solver(board,0) == 0)
  {
    printf("No Solution\n");
    return 0;
  }
  printf("\nTotal Solutions(CPU): %d boards\n\n",total);
  return 0;

}
