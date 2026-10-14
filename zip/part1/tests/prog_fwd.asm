# TEST FWD: data hazards on ADD, resolved by forwarding (Fig. 7.50 / 7.53)
addi $1, $0, 3
addi $2, $0, 4
add  $3, $1, $2       # 7    $2 from MEM (ALUOutM), $1 from WB (ResultW)
add  $4, $3, $3       # 14   both operands from MEM
add  $5, $4, $3       # 21   $4 from MEM, $3 from WB
add  $5, $5, $5       # 42   both from MEM
add  $6, $5, $4       # 56   $5 from MEM, $4 from register file
add  $0, $1, $1       # writes $0: must NOT be forwarded
add  $7, $0, $6       # 56   $0 reads 0, $6 from WB
add  $10, $1, $1      # 6
add  $10, $2, $2      # 8    same destination twice in a row
add  $11, $10, $7     # 64   $10 must come from MEM (newest), not WB (6)
add  $12, $11, $11    # 128
sw   $1, 40($0)       # store 3 so the next lw has data
lw   $13, 40($0)      # $13 = 3
add  $14, $13, $12    # 131  load-use: 1-cycle stall, then $13 from WB
add  $15, $14, $14    # 262
sw   $3, 0($0)
sw   $4, 4($0)
sw   $5, 8($0)
sw   $6, 12($0)
sw   $7, 16($0)
sw   $11, 20($0)
sw   $12, 24($0)
sw   $14, 28($0)
sw   $15, 32($0)
lw   $16, 32($0)      # $16 = 262
add  $17, $16, $1     # 265  load-use again
sw   $17, 36($0)
