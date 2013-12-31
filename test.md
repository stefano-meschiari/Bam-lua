
This is a sample BAM template (test.md.bam). A BAM template is any 
type of plain-text file with special code fragments. See README.md 
for details.


The Collatz conjecture
======================
Also known as the 3n+1 conjecture [Wikipedia][1]. It is a sequence of numbers
with nontrivial features. 

The sequence is built as follows: take any integer n. If n is even, divide it
by two; if n is odd, multiply by 3 and add 1. Stop the sequence when n == 1.


You chose 7.

1. 7 is odd, so we multiply by three and add 1.
2. 22 is even, so we divide by two.
3. 11 is odd, so we multiply by three and add 1.
4. 34 is even, so we divide by two.
5. 17 is odd, so we multiply by three and add 1.
6. 52 is even, so we divide by two.
7. 26 is even, so we divide by two.
8. 13 is odd, so we multiply by three and add 1.
9. 40 is even, so we divide by two.
10. 20 is even, so we divide by two.
11. 10 is even, so we divide by two.
12. 5 is odd, so we multiply by three and add 1.
13. 16 is even, so we divide by two.
14. 8 is even, so we divide by two.
15. 4 is even, so we divide by two.
16. 2 is even, so we divide by two.

It took 16 iterations to get to 1.

Other examples
==============
Files in directory: bam.lua, test.md, test.md.aux and test.md.bam.

[1]: http://en.wikipedia.org/wiki/Collatz_conjecture
