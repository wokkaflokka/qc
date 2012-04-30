/*
Driver for count_nodal_domains.c using percolation model

Kyle Konrad
3/31/2011
*/


#include "count_nodal_domains.h"
#include "random_percolation.h"
#include "util/util.h"
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <unistd.h> // for command line parsing with getopt

// options specified by command line arguments
int showTime = 0; // flag: print time it takes for countNodalDomains to run
int gridSize = -1; // size of grid in x and y dimensions
int trials = 1; // number of grids to generate and count
int trial = 1; // current trial number
int outputGrid = 0; // flag: output grid(s) to file(s): grid_[n].dat
double k = -1; // effective k of grid: k = (gridSize*pi)/(2*sqrt(2))
FILE *sizefile = NULL; // file to write sizes to

/*
  print a usage statement
*/
void usage() {
  fprintf(stderr, "USAGE: count {-n gridSize | -k k} [-N trials] [-t] [-o] [-s]\n");
  fprintf(stderr, "-t: show timing info\n");
  fprintf(stderr, "-o: output grid to file\n");
  fprintf(stderr, "-s: output nodal domain sizes to file\n");
}

/*
  process command line arguments
*/
void processArgs(int argc, char **argv) {
  int i = 0;
  int c;
  opterr = 0;

  if (argc <= 1) {
    usage();
    exit(CMD_LINE_ARG_ERR);
  }

  while ((c = getopt(argc, argv, "n:N:k:tos")) != -1) {
    switch (c) {
    case 'n':
      gridSize = atoi(optarg);
      k = (gridSize * M_PI)/(2*sqrt(2));
      break;
    case 'N':
      trials = atoi(optarg);
      break;
    case 'k':
      k = atof(optarg);
      gridSize = (2*sqrt(2)*k)/(M_PI);
      break;
    case 't':
      showTime = 1;
      break;
    case 'o':
      outputGrid = 1;
      break;
    case 's':
      sizefile = fopen("perc_sizes.dat", "w");
      break;
    case '?':
      switch (optopt) {
      case 'n':
      case 'N':
      case 'k':
	fprintf(stderr, "Option -%c requires an argument.\n", optopt);
	break;
      default:
	fprintf(stderr, "Unknown option -%c.\n", optopt);
      }
    default:
      abort();
    }
  }

  if (gridSize < 0) {
    ERROR("invalid grid size %d", gridSize);
    exit(CMD_LINE_ARG_ERR);
  }
}


/*
output:
        return value: number of nodal domains
*/
int runTest(double **grid, int ny, int nx) {   
  clock_t start = clock();
  int nd = countNodalDomainsNoInterp(grid, NULL, ny, nx, sizefile);
  clock_t end = clock();

  if (showTime) {
    printf("countNodalDomains took %f seconds\n", ((double)(end - start)) / CLOCKS_PER_SEC);
  }
  return nd;
}


int main(int argc, char **argv) {
  processArgs(argc, argv);
  int ny, nx;
  double **grid;

  nx = gridSize;
  ny = gridSize;
  int counts[trials];

  double mean = 0.0, variance = 0.0;

  int i;
  grid = createGrid(ny, nx);
  if (!grid) {
    exit(OUT_OF_MEMORY_ERR);
  }
  srand(time(NULL));

  // run the trials and calculate mean count
  for (trial = 0 ; trial < trials ; trial++) {
    randomPercolation(grid, ny, nx);
    
    if (outputGrid) {
      char outfile[50];
      sprintf(outfile, "../data/grid_%d.dat", trial);
	array2file(grid, ny, nx, outfile);
    }
    
    counts[trial] = runTest(grid, ny, nx);
    fprintf(stderr, "%d\n", counts[trial]);
    mean += counts[i];
  }
  if (sizefile) {
    fclose(sizefile);
  }
  destroyGrid(grid);
  mean /= trials;

  // calculate variance of counts
  for (i = 0 ; i < trials ; i++) {
    variance += (counts[i] - mean) * (counts[i] - mean);
  }
  variance /= trials;
  
  // printf("mean: %f\n", mean);
  // printf("variance: %f\n", variance);
  printf("scaled mean: %f\n", mean / (ny * nx / 4) * 2 / M_PI);
  printf("scaled variance: %f\n", variance / (ny * nx / 4) * 2 / M_PI);
 
  exit(0);
}
