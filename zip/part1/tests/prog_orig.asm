# Original program provided with the lab (Harris & Harris test program)
addi $2, $0, 5
addi $3, $0, 12
addi $7, $3, -9
or   $4, $7, $2
and  $5, $3, $4
add  $5, $5, $4
beq  $5, $7, end      # not taken
slt  $4, $3, $4
beq  $4, $0, around   # taken
addi $5, $0, 0        # skipped
around:
slt  $4, $7, $2
add  $7, $4, $5
sub  $7, $7, $2
sw   $7, 68($3)       # 7 @ 0x50
lw   $2, 80($0)
j    end
addi $2, $0, 1        # skipped
end:
sw   $2, 84($0)       # 7 @ 0x54
