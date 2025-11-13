		 ____    _    ____  _   _ 
		| __ )  / \  / ___|| | | |
		|  _ \ / _ \ \___ \| |_| |
		| |_) / ___ \ ___) |  _  |
		|____/_/   \_\____/|_| |_|
          [Bourne-Again SHell]

## Bash Goodies...
*	http://mywiki.wooledge.org/BashGuide
*	https://www.shellcheck.net/

## Parallel
* https://www.gnu.org/software/parallel/

parallel : GNU Parallel is a general parallelizer to run multiple serial command line programs in parallel without changing them.

man parallel_examples [or] https://www.gnu.org/software/parallel/man.html

EXAMPLE: 

		seq 100 | parallel --bar seq {}0000 '>' file-{}

		parallel --color --tag  ls -lR {} ::: *.bash

## Rush (parallel jobs)
Rush : rush -- a cross-platform command-line tool for executing jobs in parallel
* https://github.com/shenwei356/rush?tab=readme-ov-file#examples
