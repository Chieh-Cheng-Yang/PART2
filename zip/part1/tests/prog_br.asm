# TEST BR: control hazards on BEQ (and j), resolved by flushing (Fig. 7.56/7.57)
# Every instruction right behind a taken branch/jump is a wrong-path
# instruction that would corrupt a result or write memory if not flushed.
addi $1, $0, 0        # i   = 0
addi $2, $0, 5        # n   = 5
addi $3, $0, 0        # sum = 0
loop:
beq  $1, $2, done     # not taken 5x, taken 1x
add  $3, $3, $1       # sum += i      (wrong path when the beq is taken)
addi $1, $1, 1        # i++
j    loop             # taken 5x
done:
sw   $3, 0($0)        # 0+1+2+3+4 = 10 (wrong path behind every j: an early store)
beq  $3, $3, t1       # taken
sw   $1, 4($0)        # wrong path: must NOT be written
t1:
beq  $1, $3, t2       # 5 != 10: not taken
sw   $1, 8($0)        # must be written (5)
t2:
add  $4, $1, $1       # 10
addi $9, $0, 0        # filler: add is in MEM while the next beq is in DECODE
beq  $4, $3, t3       # taken, $4 forwarded from ALUOutM to the comparator
sw   $1, 12($0)       # wrong path
t3:
addi $5, $0, 5
beq  $5, $1, t4       # taken, $5 still in EXECUTE -> 1 branch stall, then forward
sw   $1, 16($0)       # wrong path
t4:
lw   $6, 0($0)        # $6 = 10
beq  $6, $3, t5       # taken, depends on lw -> stalls until data is ready
sw   $1, 20($0)       # wrong path
t5:
sw   $6, 24($0)       # 10
