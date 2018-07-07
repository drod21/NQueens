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

const int n = 6;

void outputSolution(int board[n][n]) {
    static int k = 1;

    printf("%d-\n",k++);

    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            printf(" %d ", board[i][j]);
        }
        printf("\n");
    }
    printf("\n");
}

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
__device__ int isAllowed(int board[n][n], int row, int col)
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

int solverUtil(int board[n][n], int col)
{
  int count = 0;
  int nextState = 0;

  for(int k = 0; k < n; k++)
  {
    for(int j = 0; j < n; j++) {
      if (col == n)
      {
        count++;
        outputSolution(board);
        printf("count: %d\n", count);
        nextState = 1;
      }

      if (isAllowed(board, k, col))
      {
        board[k][col] = 1;
      }
    }
  }
  return nextState;
}

//N-queen solver for CPU algorithm
int Solver(int board[n][n], int col)
{
  int count = 0;
  if (col == n)
  {
    count++;
      outputSolution(board);
      printf("count: %d\n", count);
    return 1;
  }

  int nextState = 0;

  for(int k = 0; k < n; k++)
  {
    if (isAllowed(board,k,col))
    {
      board[k][col] = 1;
      nextState = Solver(board, col + 1);
      board[k][col] = 0;
    }
  }
  return nextState;
}

int main(int argc, char **argv) {

  //  n = atoi(argv[1]);
  int board[n][n];
  memset(board,0,sizeof(board));

  if(Solver(board,0) == 0)
  {
    printf("No Solution\n");
    return 0;
  }

  return 0;
}
